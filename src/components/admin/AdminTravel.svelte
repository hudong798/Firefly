<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	interface Travel {
		id: string;
		slug: string;
		title: string;
		cover_image: string | null;
		description: string | null;
		content: string | null;
		tags: string[] | null;
		country: string | null;
		destination: string | null;
		year: number | null;
		start_date: string | null;
		end_date: string | null;
		status: string;
		sort_order: number | null;
		created_at: string;
	}

	// ===== 轨迹管理独立登录（账号密码存 Supabase，与修仙界无关）=====
	const TRAVEL_AUTH_KEY = "travel_admin_auth";
	const TRAVEL_AUTH_EXPIRE = 1000 * 60 * 60 * 8;
	let loggedIn = false;
	let loginUser = "";
	let loginPass = "";
	let loginError = "";
	let loginLoading = false;

	function checkTravelAuth() {
		try {
			const raw = localStorage.getItem(TRAVEL_AUTH_KEY);
			if (!raw) return;
			const data = JSON.parse(raw);
			if (data.authenticated && Date.now() - data.timestamp < TRAVEL_AUTH_EXPIRE) {
				loggedIn = true;
			} else {
				localStorage.removeItem(TRAVEL_AUTH_KEY);
			}
		} catch (e) {
			localStorage.removeItem(TRAVEL_AUTH_KEY);
		}
	}

	async function handleLogin() {
		if (loginLoading) return;
		if (!loginUser.trim() || !loginPass) {
			loginError = "请输入账号和密码";
			return;
		}
		loginLoading = true;
		loginError = "";
		try {
			const { data, error } = await supabase.rpc("verify_admin_credentials", {
				p_module: "travel",
				p_username: loginUser.trim(),
				p_password: loginPass
			});
			if (error) throw error;
			if (data === true) {
				loggedIn = true;
				loginUser = "";
				loginPass = "";
				localStorage.setItem(TRAVEL_AUTH_KEY, JSON.stringify({
					authenticated: true,
					timestamp: Date.now()
				}));
				loadTravels();
			} else {
				loginError = "账号或密码错误";
			}
		} catch (e: any) {
			loginError = "登录验证失败：" + (e?.message || "未知错误");
		} finally {
			loginLoading = false;
		}
	}

	function handleLogout() {
		loggedIn = false;
		localStorage.removeItem(TRAVEL_AUTH_KEY);
		travels = [];
	}

	// ===== 轨迹管理 =====
	let travels: Travel[] = [];
	let travelsLoading = false;
	let actionMessage = "";
	let showForm = false;
	let editingId: string | null = null;
	let submitting = false;

	// 表单字段
	let formTitle = "";
	let formSlug = "";
	let formCountry = "";
	let formDestination = "";
	let formYear = "";
	let formStartDate = "";
	let formEndDate = "";
	let formCover = "";
	let formDescription = "";
	let formContent = "";
	let formTags = "";
	let formStatus = "published";
	let formSortOrder = "";

	async function loadTravels() {
		if (!supabase) return;
		travelsLoading = true;
		try {
			const { data, error } = await supabase
				.from("travels")
				.select("*")
				.order("year", { ascending: false })
				.order("sort_order", { ascending: true })
				.limit(100);
			if (error) throw error;
			travels = (data as Travel[]) || [];
		} catch (e: any) {
			actionMessage = "加载失败：" + (e?.message || "未知错误");
		} finally {
			travelsLoading = false;
		}
	}

	function resetForm() {
		formTitle = "";
		formSlug = "";
		formCountry = "";
		formDestination = "";
		formYear = "";
		formStartDate = "";
		formEndDate = "";
		formCover = "";
		formDescription = "";
		formContent = "";
		formTags = "";
		formStatus = "published";
		formSortOrder = "";
		editingId = null;
	}

	function generateSlug() {
		if (formSlug.trim()) return;
		const base = formTitle
			.trim()
			.toLowerCase()
			.replace(/[^\w\u4e00-\u9fa5]+/g, "-")
			.replace(/^-+|-+$/g, "")
			.slice(0, 50);
		formSlug = base || `travel-${Date.now()}`;
	}

	// ===== 图片压缩工具 =====
	const MAX_IMAGE_SIZE = 500 * 1024; // 500KB
	const MAX_IMAGE_DIMENSION = 1920; // 最大边1920px

	function compressImage(file: File): Promise<Blob> {
		return new Promise((resolve, reject) => {
			// 如果已经小于500KB，直接返回
			if (file.size <= MAX_IMAGE_SIZE) {
				resolve(file);
				return;
			}

			const reader = new FileReader();
			reader.onload = (e) => {
				const img = new Image();
				img.onload = () => {
					// 计算缩放比例（限制最大边）
					let { width, height } = img;
					const scale = Math.min(1, MAX_IMAGE_DIMENSION / Math.max(width, height));
					width = Math.round(width * scale);
					height = Math.round(height * scale);

					const canvas = document.createElement("canvas");
					canvas.width = width;
					canvas.height = height;
					const ctx = canvas.getContext("2d");
					if (!ctx) {
						reject(new Error("无法创建Canvas"));
						return;
					}
					ctx.drawImage(img, 0, 0, width, height);

					// 逐步降低质量直到小于500KB
					let quality = 0.85;
					const tryCompress = () => {
						canvas.toBlob(
							(blob) => {
								if (!blob) {
									reject(new Error("压缩失败"));
									return;
								}
								if (blob.size <= MAX_IMAGE_SIZE || quality <= 0.15) {
									resolve(blob);
								} else {
									quality -= 0.1;
									tryCompress();
								}
							},
							"image/jpeg",
							quality
						);
					};
					tryCompress();
				};
				img.onerror = () => reject(new Error("图片加载失败"));
				img.src = e.target?.result as string;
			};
			reader.onerror = () => reject(new Error("文件读取失败"));
			reader.readAsDataURL(file);
		});
	}

	// ===== 封面图片上传 =====
	let coverUploading = false;
	let coverUploadError = "";

	async function handleCoverFileSelect(e: Event) {
		const input = e.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;

		// 验证文件类型
		if (!file.type.startsWith("image/")) {
			coverUploadError = "请选择图片文件";
			return;
		}

		coverUploading = true;
		coverUploadError = "";

		try {
			// 自动压缩到500KB以下
			const compressedBlob = await compressImage(file);
			const originalSizeKB = (file.size / 1024).toFixed(0);
			const compressedSizeKB = (compressedBlob.size / 1024).toFixed(0);

			const fileName = `travel-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.jpg`;

			const { data, error } = await supabase.storage
				.from("travel-covers")
				.upload(fileName, compressedBlob, {
					cacheControl: "3600",
					upsert: false,
					contentType: "image/jpeg",
				});

			if (error) throw error;

			// 获取公开URL
			const { data: urlData } = supabase.storage
				.from("travel-covers")
				.getPublicUrl(data.path);

			formCover = urlData.publicUrl;
			console.log(`封面图压缩: ${originalSizeKB}KB → ${compressedSizeKB}KB`);
		} catch (err: any) {
			coverUploadError = "上传失败：" + (err?.message || "未知错误");
		} finally {
			coverUploading = false;
			// 清空input，允许重复选择同一文件
			input.value = "";
		}
	}

	// ===== 正文插入图片 =====
	let contentImageUploading = false;
	let contentImageError = "";

	function insertTextAtCursor(textarea: HTMLTextAreaElement, text: string) {
		const start = textarea.selectionStart ?? textarea.value.length;
		const end = textarea.selectionEnd ?? textarea.value.length;
		const newValue = textarea.value.substring(0, start) + text + textarea.value.substring(end);

		// 用原生setter更新值，触发Svelte绑定
		const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value")?.set;
		if (setter) {
			setter.call(textarea, newValue);
		} else {
			textarea.value = newValue;
		}
		textarea.dispatchEvent(new Event("input", { bubbles: true }));

		// 光标移到插入文本之后
		const newPos = start + text.length;
		textarea.setSelectionRange(newPos, newPos);
		textarea.focus();
	}

	async function handleContentImageSelect(e: Event) {
		const input = e.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;

		if (!file.type.startsWith("image/")) {
			contentImageError = "请选择图片文件";
			return;
		}

		contentImageUploading = true;
		contentImageError = "";

		try {
			// 自动压缩到500KB以下
			const compressedBlob = await compressImage(file);
			const originalSizeKB = (file.size / 1024).toFixed(0);
			const compressedSizeKB = (compressedBlob.size / 1024).toFixed(0);

			const fileName = `content-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.jpg`;

			const { data, error } = await supabase.storage
				.from("travel-covers")
				.upload(fileName, compressedBlob, {
					cacheControl: "3600",
					upsert: false,
					contentType: "image/jpeg",
				});

			if (error) throw error;

			const { data: urlData } = supabase.storage
				.from("travel-covers")
				.getPublicUrl(data.path);

			// 在正文textarea光标位置插入Markdown图片语法
			const textarea = document.getElementById("travel-content-input") as HTMLTextAreaElement | null;
			const imgMarkdown = `\n\n![${file.name.replace(/\.[^.]+$/, "")}](${urlData.publicUrl})\n\n`;

			if (textarea) {
				insertTextAtCursor(textarea, imgMarkdown);
			} else {
				// fallback：直接追加到末尾
				formContent = (formContent || "") + imgMarkdown;
			}
		} catch (err: any) {
			contentImageError = "上传失败：" + (err?.message || "未知错误");
		} finally {
			contentImageUploading = false;
			input.value = "";
		}
	}

	function openAddForm() {
		resetForm();
		showForm = true;
	}

	function openEditForm(t: Travel) {
		editingId = t.id;
		formTitle = t.title;
		formSlug = t.slug;
		formCountry = t.country || "";
		formDestination = t.destination || "";
		formYear = t.year ? String(t.year) : "";
		formStartDate = t.start_date || "";
		formEndDate = t.end_date || "";
		formCover = t.cover_image || "";
		formDescription = t.description || "";
		formContent = t.content || "";
		formTags = t.tags ? t.tags.join(", ") : "";
		formStatus = t.status;
		formSortOrder = t.sort_order != null ? String(t.sort_order) : "";
		showForm = true;
	}

	async function submitTravel() {
		if (!supabase) return;
		if (!formTitle.trim()) {
			actionMessage = "标题不能为空";
			return;
		}
		submitting = true;
		actionMessage = "";
		try {
			generateSlug();
			const tagsArr = formTags
				? formTags.split(/[,，\s]+/).filter((t) => t.trim())
				: [];

			const payload: Record<string, any> = {
				slug: formSlug.trim(),
				title: formTitle.trim(),
				country: formCountry.trim() || null,
				destination: formDestination.trim() || null,
				year: formYear ? parseInt(formYear) : null,
				start_date: formStartDate || null,
				end_date: formEndDate || null,
				cover_image: formCover.trim() || null,
				description: formDescription.trim() || null,
				content: formContent.trim() || null,
				tags: tagsArr.length > 0 ? tagsArr : null,
				status: formStatus,
				sort_order: formSortOrder ? parseInt(formSortOrder) : null,
			};

			if (editingId) {
				const { error } = await supabase.from("travels").update(payload).eq("id", editingId);
				if (error) throw error;
				actionMessage = "轨迹更新成功！";
			} else {
				const { error } = await supabase.from("travels").insert(payload);
				if (error) throw error;
				actionMessage = "轨迹发布成功！";
			}

			resetForm();
			showForm = false;
			loadTravels();
		} catch (e: any) {
			actionMessage = e?.message || "保存失败";
		} finally {
			submitting = false;
		}
	}

	async function deleteTravel(id: string) {
		if (!supabase) return;
		if (!confirm("确定删除这条轨迹吗？此操作不可撤销。")) return;
		try {
			const { error } = await supabase.from("travels").delete().eq("id", id);
			if (error) throw error;
			actionMessage = "已删除";
			loadTravels();
		} catch (e: any) {
			actionMessage = e?.message || "删除失败";
		}
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")}`;
	}

	onMount(() => {
		checkTravelAuth();
		if (loggedIn) {
			loadTravels();
		}
	});
</script>

<div class="admin-travel">
	{#if !loggedIn}
		<!-- 轨迹管理独立登录 -->
		<div class="admin-login">
			<h2>轨迹管理登录</h2>
			<p class="admin-login-sub">使用轨迹管理员账号密码登录</p>

			{#if loginError}
				<div class="admin-error">{loginError}</div>
			{/if}

			<div class="admin-login-form">
				<div class="form-group">
					<label for="travel-login-user">账号</label>
					<input
						id="travel-login-user"
						type="text"
						bind:value={loginUser}
						placeholder="请输入管理员账号"
						on:keydown={(e) => e.key === "Enter" && handleLogin()}
					/>
				</div>
				<div class="form-group">
					<label for="travel-login-pass">密码</label>
					<input
						id="travel-login-pass"
						type="password"
						bind:value={loginPass}
						placeholder="请输入管理员密码"
						on:keydown={(e) => e.key === "Enter" && handleLogin()}
					/>
				</div>
			</div>

			<div class="admin-login-actions">
				<button class="admin-btn admin-btn-primary" on:click={handleLogin} disabled={loginLoading}>
					{#if loginLoading}验证中...{:else}登录{/if}
				</button>
			</div>
		</div>
	{:else}
		<!-- 管理面板 -->
		<div class="admin-panel">
			<div class="admin-panel-header">
				<div>
					<h2>轨迹管理</h2>
					<p class="admin-panel-sub">共 {travels.length} 条轨迹</p>
				</div>
				<div class="admin-panel-actions">
					<button class="admin-btn admin-btn-primary" on:click={() => (showForm = !showForm)}>
						{#if showForm}取消{:else}+ 发布轨迹{/if}
					</button>
					<button class="admin-btn admin-btn-secondary" on:click={loadTravels}>刷新</button>
					<button class="admin-btn admin-btn-danger" on:click={handleLogout}>退出</button>
				</div>
			</div>

			{#if actionMessage}
				<div class="admin-action-message">{actionMessage}</div>
			{/if}

			<!-- 发布/编辑表单 -->
			{#if showForm}
				<div class="travel-form">
					<h3>{editingId ? "编辑轨迹" : "发布新轨迹"}</h3>

					<div class="form-row">
						<div class="form-group">
							<label>标题 *</label>
							<input type="text" bind:value={formTitle} placeholder="轨迹标题" />
						</div>
						<div class="form-group">
							<label>Slug</label>
							<input type="text" bind:value={formSlug} placeholder="留空自动生成" />
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label>国家</label>
							<input type="text" bind:value={formCountry} placeholder="如：日本" />
						</div>
						<div class="form-group">
							<label>目的地</label>
							<input type="text" bind:value={formDestination} placeholder="如：大阪 / 京都" />
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label>年份</label>
							<input type="number" bind:value={formYear} placeholder="2024" />
						</div>
						<div class="form-group">
							<label>开始日期</label>
							<input type="date" bind:value={formStartDate} />
						</div>
						<div class="form-group">
							<label>结束日期</label>
							<input type="date" bind:value={formEndDate} />
						</div>
					</div>

					<div class="form-group cover-upload-group">
						<label>封面图片</label>
						<div class="cover-upload-area">
							<!-- 图片预览 -->
							{#if formCover}
								<div class="cover-preview">
									<img src={formCover} alt="封面预览" />
									<button class="cover-remove-btn" on:click={() => (formCover = "")} title="移除图片">×</button>
								</div>
							{/if}
							<!-- 上传按钮 -->
							<label class="cover-upload-btn {coverUploading ? 'uploading' : ''}">
								<input
									type="file"
									accept="image/*"
									on:change={handleCoverFileSelect}
									class="cover-file-input"
								/>
								<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="cover-upload-icon">
									<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
									<polyline points="17 8 12 3 7 8"/>
									<line x1="12" y1="3" x2="12" y2="15"/>
								</svg>
								<span>{coverUploading ? "上传中..." : "上传封面图"}</span>
							</label>
							<!-- 或手动输入URL -->
							<div class="cover-url-input">
								<span class="cover-url-label">或粘贴图片 URL：</span>
								<input type="text" bind:value={formCover} placeholder="https://..." />
							</div>
						</div>
						{#if coverUploadError}
							<div class="cover-upload-error">{coverUploadError}</div>
						{/if}
						<p class="cover-upload-hint">支持 JPG/PNG/WebP，超过 500KB 自动压缩</p>
					</div>

					<div class="form-group">
						<label>简介</label>
						<textarea bind:value={formDescription} placeholder="轨迹简介" rows="2"></textarea>
					</div>

					<div class="form-group content-editor-group">
						<div class="content-editor-header">
							<label>正文内容</label>
							<div class="content-editor-toolbar">
								<label class="toolbar-btn {contentImageUploading ? 'uploading' : ''}" title="在光标位置插入图片">
									<input
										type="file"
										accept="image/*"
										on:change={handleContentImageSelect}
										class="toolbar-file-input"
									/>
									<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="toolbar-icon">
										<rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
										<circle cx="8.5" cy="8.5" r="1.5"/>
										<polyline points="21 15 16 10 5 21"/>
									</svg>
									<span>{contentImageUploading ? "上传中..." : "插入图片"}</span>
								</label>
							</div>
						</div>
						{#if contentImageError}
							<div class="content-editor-error">{contentImageError}</div>
						{/if}
						<textarea
							id="travel-content-input"
							bind:value={formContent}
							placeholder="详细内容（支持 Markdown，点击上方「插入图片」可在光标处插入景点照片）"
							rows="8"
						></textarea>
						<p class="content-editor-hint">支持 Markdown 语法；插入的图片会自动上传并在光标位置生成图片链接</p>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label>标签（逗号分隔）</label>
							<input type="text" bind:value={formTags} placeholder="旅行, 摄影, 美食" />
						</div>
						<div class="form-group">
							<label>状态</label>
							<select bind:value={formStatus}>
								<option value="published">已发布</option>
								<option value="draft">草稿</option>
							</select>
						</div>
						<div class="form-group">
							<label>排序</label>
							<input type="number" bind:value={formSortOrder} placeholder="0" />
						</div>
					</div>

					<div class="form-actions">
						<button class="admin-btn admin-btn-secondary" on:click={() => { showForm = false; resetForm(); }}>取消</button>
						<button class="admin-btn admin-btn-primary" on:click={submitTravel} disabled={submitting}>
							{submitting ? "保存中..." : (editingId ? "保存修改" : "发布轨迹")}
						</button>
					</div>
				</div>
			{/if}

			<!-- 轨迹列表 -->
			<div class="travel-list">
				{#if travelsLoading}
					<div class="admin-loading">加载中...</div>
				{:else if travels.length === 0}
					<div class="admin-empty">还没有轨迹，点击「发布轨迹」创建第一条</div>
				{:else}
					{#each travels as t (t.id)}
						<div class="travel-item">
							<div class="travel-item-cover">
								{#if t.cover_image}
									<img src={t.cover_image} alt={t.title} />
								{:else}
									<div class="travel-item-no-cover">无封面</div>
								{/if}
							</div>
							<div class="travel-item-info">
								<h4>{t.title}</h4>
								<div class="travel-item-meta">
									<span>{t.country || ""}{t.destination ? " · " + t.destination : ""}</span>
									<span>{t.year || ""}</span>
									<span class={`status-badge status-${t.status}`}>{t.status === "published" ? "已发布" : "草稿"}</span>
								</div>
								{#if t.description}
									<p class="travel-item-desc">{t.description}</p>
								{/if}
							</div>
							<div class="travel-item-actions">
								<a href={`/travel/${t.slug}/`} target="_blank" class="admin-btn admin-btn-secondary">查看</a>
								<button class="admin-btn admin-btn-secondary" on:click={() => openEditForm(t)}>编辑</button>
								<button class="admin-btn admin-btn-danger" on:click={() => deleteTravel(t.id)}>删除</button>
							</div>
						</div>
					{/each}
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.admin-travel {
		font-family: inherit;
		color: #F1F3F8;
	}

	/* 登录 */
	.admin-login {
		max-width: 420px;
		margin: 4rem auto;
		padding: 2.5rem;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 16px;
		backdrop-filter: blur(12px);
	}
	.admin-login h2 {
		margin: 0 0 0.5rem;
		font-size: 1.4rem;
		font-weight: 600;
	}
	.admin-login-sub {
		margin: 0 0 1.5rem;
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.45);
	}
	.admin-error {
		padding: 0.6rem 0.9rem;
		margin-bottom: 1rem;
		background: rgba(255, 80, 80, 0.1);
		border: 1px solid rgba(255, 80, 80, 0.25);
		border-radius: 8px;
		color: #ff8a8a;
		font-size: 0.82rem;
	}
	.admin-login-form {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}
	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}
	.form-group label {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.5);
		letter-spacing: 0.02em;
	}
	.form-group input,
	.form-group textarea,
	.form-group select {
		padding: 0.6rem 0.8rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		color: #F1F3F8;
		font-size: 0.88rem;
		font-family: inherit;
		outline: none;
		transition: border-color 0.2s;
	}
	.form-group input:focus,
	.form-group textarea:focus,
	.form-group select:focus {
		border-color: rgba(155, 140, 255, 0.5);
	}
	.form-group input::placeholder,
	.form-group textarea::placeholder {
		color: rgba(255, 255, 255, 0.25);
	}
	.admin-login-actions {
		display: flex;
		justify-content: flex-end;
	}

	/* 按钮 */
	.admin-btn {
		padding: 0.5rem 1.1rem;
		border: none;
		border-radius: 8px;
		font-size: 0.82rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		font-family: inherit;
		text-decoration: none;
		display: inline-flex;
		align-items: center;
	}
	.admin-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.admin-btn-primary {
		background: linear-gradient(135deg, #7c6fff, #5b4fd4);
		color: #fff;
	}
	.admin-btn-primary:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 16px rgba(124, 111, 255, 0.3);
	}
	.admin-btn-secondary {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.75);
		border: 1px solid rgba(255, 255, 255, 0.1);
	}
	.admin-btn-secondary:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.1);
	}
	.admin-btn-danger {
		background: rgba(255, 80, 80, 0.12);
		color: #ff8a8a;
		border: 1px solid rgba(255, 80, 80, 0.2);
	}
	.admin-btn-danger:hover:not(:disabled) {
		background: rgba(255, 80, 80, 0.2);
	}

	/* 管理面板 */
	.admin-panel {
		padding: 2rem 1.5rem;
		max-width: 1100px;
		margin: 0 auto;
	}
	.admin-panel-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
		gap: 1rem;
	}
	.admin-panel-header h2 {
		margin: 0 0 0.25rem;
		font-size: 1.5rem;
		font-weight: 600;
	}
	.admin-panel-sub {
		margin: 0;
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.4);
	}
	.admin-panel-actions {
		display: flex;
		gap: 0.6rem;
		flex-wrap: wrap;
	}
	.admin-action-message {
		padding: 0.7rem 1rem;
		margin-bottom: 1.25rem;
		background: rgba(124, 111, 255, 0.1);
		border: 1px solid rgba(124, 111, 255, 0.25);
		border-radius: 8px;
		color: #b8adff;
		font-size: 0.85rem;
	}

	/* 表单 */
	.travel-form {
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		background: rgba(255, 255, 255, 0.025);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 12px;
	}
	.travel-form h3 {
		margin: 0 0 1.25rem;
		font-size: 1.1rem;
		font-weight: 600;
	}
	.form-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: 1rem;
		margin-bottom: 1rem;
	}
	.travel-form .form-group {
		margin-bottom: 1rem;
	}

	/* 封面图片上传 */
	.cover-upload-group {
		margin-bottom: 1.25rem;
	}
	.cover-upload-area {
		display: flex;
		flex-direction: column;
		gap: 0.85rem;
	}
	.cover-preview {
		position: relative;
		width: 100%;
		max-width: 400px;
		aspect-ratio: 3 / 2;
		border-radius: 10px;
		overflow: hidden;
		border: 1px solid rgba(255, 255, 255, 0.1);
	}
	.cover-preview img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.cover-remove-btn {
		position: absolute;
		top: 8px;
		right: 8px;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		border: none;
		background: rgba(0, 0, 0, 0.6);
		color: #fff;
		font-size: 1.1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;
	}
	.cover-remove-btn:hover {
		background: rgba(255, 60, 60, 0.8);
	}
	.cover-upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.65rem 1.2rem;
		background: rgba(124, 111, 255, 0.1);
		border: 1px dashed rgba(124, 111, 255, 0.4);
		border-radius: 10px;
		color: #b8adff;
		font-size: 0.85rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		width: fit-content;
	}
	.cover-upload-btn:hover:not(.uploading) {
		background: rgba(124, 111, 255, 0.18);
		border-color: rgba(124, 111, 255, 0.6);
	}
	.cover-upload-btn.uploading {
		opacity: 0.6;
		cursor: wait;
	}
	.cover-file-input {
		display: none;
	}
	.cover-upload-icon {
		width: 1rem;
		height: 1rem;
	}
	.cover-url-input {
		display: flex;
		align-items: center;
		gap: 0.6rem;
	}
	.cover-url-label {
		font-size: 0.78rem;
		color: rgba(255, 255, 255, 0.35);
		white-space: nowrap;
	}
	.cover-url-input input {
		flex: 1;
		padding: 0.5rem 0.7rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		color: #F1F3F8;
		font-size: 0.82rem;
		font-family: inherit;
		outline: none;
	}
	.cover-url-input input:focus {
		border-color: rgba(155, 140, 255, 0.5);
	}
	.cover-upload-error {
		padding: 0.5rem 0.8rem;
		background: rgba(255, 80, 80, 0.1);
		border: 1px solid rgba(255, 80, 80, 0.25);
		border-radius: 8px;
		color: #ff8a8a;
		font-size: 0.8rem;
	}
	.cover-upload-hint {
		margin: 0;
		font-size: 0.72rem;
		color: rgba(255, 255, 255, 0.3);
	}

	/* 正文编辑器 */
	.content-editor-group {
		margin-bottom: 1.25rem;
	}
	.content-editor-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
	}
	.content-editor-header label {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.5);
		letter-spacing: 0.02em;
	}
	.content-editor-toolbar {
		display: flex;
		gap: 0.5rem;
	}
	.toolbar-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.35rem 0.8rem;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.65);
		font-size: 0.78rem;
		cursor: pointer;
		transition: all 0.2s;
	}
	.toolbar-btn:hover:not(.uploading) {
		background: rgba(124, 111, 255, 0.12);
		border-color: rgba(124, 111, 255, 0.35);
		color: #b8adff;
	}
	.toolbar-btn.uploading {
		opacity: 0.55;
		cursor: wait;
	}
	.toolbar-file-input {
		display: none;
	}
	.toolbar-icon {
		width: 0.85rem;
		height: 0.85rem;
	}
	.content-editor-error {
		padding: 0.45rem 0.7rem;
		margin-bottom: 0.5rem;
		background: rgba(255, 80, 80, 0.1);
		border: 1px solid rgba(255, 80, 80, 0.25);
		border-radius: 6px;
		color: #ff8a8a;
		font-size: 0.78rem;
	}
	.content-editor-group textarea {
		width: 100%;
		padding: 0.75rem 0.9rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 10px;
		color: #F1F3F8;
		font-size: 0.88rem;
		font-family: "SF Mono", "Menlo", "Consolas", monospace;
		line-height: 1.7;
		outline: none;
		resize: vertical;
		min-height: 200px;
		transition: border-color 0.2s;
		box-sizing: border-box;
	}
	.content-editor-group textarea:focus {
		border-color: rgba(155, 140, 255, 0.5);
	}
	.content-editor-group textarea::placeholder {
		color: rgba(255, 255, 255, 0.25);
	}
	.content-editor-hint {
		margin: 0.4rem 0 0;
		font-size: 0.72rem;
		color: rgba(255, 255, 255, 0.3);
	}

	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
		margin-top: 1.25rem;
	}

	/* 列表 */
	.travel-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.admin-loading,
	.admin-empty {
		text-align: center;
		padding: 3rem 1rem;
		color: rgba(255, 255, 255, 0.35);
		font-size: 0.9rem;
	}
	.travel-item {
		display: flex;
		gap: 1.25rem;
		padding: 1.1rem;
		background: rgba(255, 255, 255, 0.025);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 12px;
		align-items: center;
		transition: border-color 0.2s;
	}
	.travel-item:hover {
		border-color: rgba(155, 140, 255, 0.25);
	}
	.travel-item-cover {
		width: 120px;
		height: 80px;
		flex-shrink: 0;
		border-radius: 8px;
		overflow: hidden;
		background: rgba(255, 255, 255, 0.04);
	}
	.travel-item-cover img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.travel-item-no-cover {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.7rem;
		color: rgba(255, 255, 255, 0.25);
	}
	.travel-item-info {
		flex: 1;
		min-width: 0;
	}
	.travel-item-info h4 {
		margin: 0 0 0.35rem;
		font-size: 1rem;
		font-weight: 600;
	}
	.travel-item-meta {
		display: flex;
		gap: 0.85rem;
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.4);
		margin-bottom: 0.35rem;
		flex-wrap: wrap;
	}
	.status-badge {
		padding: 0.1rem 0.5rem;
		border-radius: 4px;
		font-size: 0.7rem;
	}
	.status-published {
		background: rgba(80, 220, 140, 0.12);
		color: #6ee7a8;
	}
	.status-draft {
		background: rgba(255, 200, 80, 0.12);
		color: #ffd479;
	}
	.travel-item-desc {
		margin: 0;
		font-size: 0.8rem;
		color: rgba(255, 255, 255, 0.45);
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
	.travel-item-actions {
		display: flex;
		gap: 0.5rem;
		flex-shrink: 0;
	}

	@media (max-width: 768px) {
		.admin-panel {
			padding: 1.25rem 1rem;
		}
		.travel-item {
			flex-direction: column;
			align-items: stretch;
		}
		.travel-item-cover {
			width: 100%;
			height: 160px;
		}
		.travel-item-actions {
			justify-content: flex-end;
		}
		.admin-login {
			margin: 2rem 1rem;
			padding: 1.5rem;
		}
	}
</style>
