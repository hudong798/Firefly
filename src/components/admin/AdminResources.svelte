<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	interface ArchiveItem {
		id: string;
		title: string;
		url: string;
		description: string | null;
		category: "影视" | "漫画" | "社区" | "工具";
		tags: string[] | null;
		status: string;
		sort_order: number;
		created_at: string;
	}

	// 复用说说/个人资料同一套管理员登录态（idong / 519931819）
	const AUTH_KEY = "echo_admin_auth";
	const AUTH_EXPIRE = 1000 * 60 * 60 * 8;

	type Mode = "archive" | "ai";
	let mode: Mode = "archive";
	const CATEGORIES = ["影视", "漫画", "社区", "工具"] as const;
	const AI_CATEGORIES = ["国内", "国外", "视频生成", "图片生成", "模型"] as const;
	$: curCats = mode === "ai" ? AI_CATEGORIES : CATEGORIES;
	type Cat = typeof CATEGORIES[number];
	type Filter = "全部" | string;
	let activeCat: Filter = "";
	function subCatsFor(c: string) { return [...new Set(items.filter(i=>i.category===c).map(i=>(i.tags&&i.tags[0])||"").filter(Boolean))]; }
	let subCat = "";
	function setCat(c: Filter) { activeCat = c; subCat = ""; }
	let openMenu: string | null = null;
	let menuOpen = false;
	let closeTimer: any = null;
	let matchMediaDesktop = typeof window !== "undefined" ? window.matchMedia("(min-width: 769px)").matches : true;
	$: catList = mode === "ai"
		? [...AI_CATEGORIES]
		: ["影视","社区","工具"];
	$: baseItems = activeCat ? items.filter((i) => i.category === activeCat) : items;
	$: subCats = activeCat === "影视" ? ["综合","动漫","短剧","其他"] : [...new Set(baseItems.map((i) => (i.tags && i.tags[0]) || "").filter(Boolean))];
	let shownItems: ArchiveItem[] = [];
	$: shownItems = (subCat ? baseItems.filter((i) => (i.tags && i.tags[0]) === subCat) : baseItems).filter((i) => i.id !== editingId);

	let loggedIn = false;
	let items: ArchiveItem[] = [];
	let loading = false;
	let loginError = "";
	let actionMessage = "";
	let loginUser = "";
	let loginPass = "";
	let loginLoading = false;

	function checkAuth() {
		try {
			const raw = localStorage.getItem(AUTH_KEY);
			if (!raw) return;
			const data = JSON.parse(raw);
			if (data.authenticated && data.username && data.password && Date.now() - data.timestamp < AUTH_EXPIRE) {
				loggedIn = true;
			} else {
				localStorage.removeItem(AUTH_KEY);
			}
		} catch (e) {
			localStorage.removeItem(AUTH_KEY);
		}
	}

	function getCreds() {
		try {
			const raw = localStorage.getItem(AUTH_KEY);
			if (!raw) return null;
			const data = JSON.parse(raw);
			if (data.username && data.password) return { username: data.username, password: data.password };
		} catch (e) {}
		return null;
	}

	async function handleLogin() {
		if (loginLoading) return;
		if (!loginUser.trim() || !loginPass) { loginError = "请输入账号和密码"; return; }
		loginLoading = true;
		loginError = "";
		try {
			const { data, error } = await supabase.rpc("verify_admin_credentials", {
				p_module: "echo", p_username: loginUser.trim(), p_password: loginPass
			});
			if (error) throw error;
			if (data === true) {
				localStorage.setItem(AUTH_KEY, JSON.stringify({
					authenticated: true, username: loginUser.trim(), password: loginPass, timestamp: Date.now()
				}));
				loggedIn = true;
				loginUser = ""; loginPass = "";
				loadItems();
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
		localStorage.removeItem(AUTH_KEY);
	}

	async function loadItems() {
		if (!supabase) return;
		loading = true;
		try {
			const rpc = mode === "ai" ? "admin_list_ai_tools" : "admin_list_archives";
			const { data, error } = await supabase.rpc(rpc);
			if (error) throw error;
			items = (data || []) as ArchiveItem[];
			if (!activeCat) {
				const cats = mode === "ai" ? AI_CATEGORIES : [...new Set(items.map((i) => i.category).filter(Boolean))];
				activeCat = cats.includes("影视") ? "影视" : cats[0];
			}
		} catch (e: any) {
			actionMessage = "加载失败：" + (e?.message || "未知错误");
		} finally {
			loading = false;
		}
	}

	let dragIndex = -1;
	function onDragStart(e: Event, i: number) {
		dragIndex = i;
		(e as DragEvent).dataTransfer!.effectAllowed = "move";
	}
	async function onDrop(i: number) {
		if (dragIndex < 0 || dragIndex === i) { dragIndex = -1; return; }
		const arr = [...shownItems];
		const [moved] = arr.splice(dragIndex, 1);
		arr.splice(i, 0, moved);
		shownItems = arr;
		dragIndex = -1;
		try {
			const creds = getCreds();
			const rpc = mode === "ai" ? "admin_reorder_ai_tools" : "admin_reorder_archives";
			const { error } = await supabase.rpc(rpc, {
				p_ids: arr.map((x) => x.id), p_username: creds?.username, p_password: creds?.password
			});
			if (error) throw error;
			actionMessage = "顺序已保存";
			loadItems();
		} catch (e: any) {
			actionMessage = "保存顺序失败：" + (e?.message || "未知错误");
		}
	}

	function switchMode(m: Mode) {
		if (mode === m) return;
		mode = m; activeCat = ""; subCat = ""; showForm = false; actionMessage = "";
		loadItems();
	}

	// 表单
	let showForm = false;
	let editingId: string | null = null;
	let fTitle = "";
	let fUrl = "";
	let fCategory: typeof CATEGORIES[number] = "影视";
	let fDesc = "";
	let fGroup = "";
	let fLogo = "";
	let logoUploading = false;
	let submitting = false;

	function resetForm() {
		editingId = null;
		fTitle = ""; fUrl = ""; fCategory = (activeCat || curCats[0]) as any; fDesc = ""; fGroup = subCat; fLogo = "";
	}

	function startEdit(it: ArchiveItem) {
		showForm = true;
		editingId = it.id;
		fTitle = it.title || it.name;
		fUrl = it.url;
		fCategory = it.category;
		fDesc = it.description || "";
		fGroup = (it.tags && it.tags[0]) || "";
		fLogo = (it as any).logo || "";
	}

	async function handleSave() {
		if (submitting) return;
		if (!fTitle.trim() || !fUrl.trim()) { actionMessage = "请填写名称和网址"; return; }
		submitting = true;
		actionMessage = "";
		try {
			const creds = getCreds();
			const payload: Record<string, any> = {
				p_title: fTitle.trim(),
				p_url: fUrl.trim(),
				p_category: fCategory,
				p_description: fDesc.trim() || null,
				p_tags: fGroup.trim() ? [fGroup.trim()] : null,
				p_logo: fLogo.trim() || null,
				p_username: creds?.username,
				p_password: creds?.password
			};
			if (editingId) payload.p_id = editingId;
			const createRpc = mode === "ai" ? "admin_create_ai_tool" : "admin_create_archive";
			const updateRpc = mode === "ai" ? "admin_update_ai_tool" : "admin_update_archive";
			const { error } = await supabase.rpc(editingId ? updateRpc : createRpc, payload);
			if (error) throw error;
			actionMessage = editingId ? "已保存修改" : "已添加";
			showForm = false;
			resetForm();
			loadItems();
		} catch (e: any) {
			actionMessage = "保存失败：" + (e?.message || "未知错误");
		} finally {
			submitting = false;
		}
	}

	async function handleDelete(it: ArchiveItem) {
		if (!confirm(`确定删除「${it.title}」吗？`)) return;
		try {
			const creds = getCreds();
			const delRpc = mode === "ai" ? "admin_delete_ai_tool" : "admin_delete_archive";
			const { error } = await supabase.rpc(delRpc, {
				p_id: it.id, p_username: creds?.username, p_password: creds?.password
			});
			if (error) throw error;
			actionMessage = "已删除";
			loadItems();
		} catch (e: any) {
			actionMessage = "删除失败：" + (e?.message || "未知错误");
		}
	}

	const MAX_LOGO = 500 * 1024;
	async function handleLogoUpload(e: Event) {
		const input = e.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		if (!file.type.startsWith("image/")) { actionMessage = "请选择图片"; return; }
		logoUploading = true; actionMessage = "";
		try {
			let blob: Blob = file;
			if (file.size > MAX_LOGO) {
				blob = await new Promise<Blob>((resolve, reject) => {
					const img = new Image();
					img.onload = () => {
						const sc = Math.min(1, 512 / Math.max(img.width, img.height));
						const c = document.createElement("canvas");
						c.width = Math.round(img.width * sc); c.height = Math.round(img.height * sc);
						c.getContext("2d")!.drawImage(img, 0, 0, c.width, c.height);
						c.toBlob((b) => (b ? resolve(b) : reject(new Error("压缩失败"))), "image/jpeg", 0.85);
					};
					img.onerror = () => reject(new Error("图片读取失败"));
					img.src = URL.createObjectURL(file);
				});
			}
			const fileName = `ai-logo-${Date.now()}-${Math.random().toString(36).slice(2,8)}.jpg`;
			const { data, error } = await supabase.storage.from("travel-covers").upload(fileName, blob, { cacheControl:"3600", upsert:false, contentType:"image/jpeg" });
			if (error) throw error;
			fLogo = supabase.storage.from("travel-covers").getPublicUrl(data.path).data.publicUrl;
			actionMessage = "Logo 已上传";
		} catch (e: any) {
			actionMessage = "Logo 上传失败：" + (e?.message || "未知错误");
		} finally { logoUploading = false; input.value = ""; }
	}

	onMount(() => {
		checkAuth();
		if (loggedIn) loadItems();
	});
</script>

<div class="admin-wrap">
	{#if !loggedIn}
		<div class="login-card">
			<div class="login-mark">OBSERVING / ADMIN</div>
			<h2>管理登录</h2>
			<p class="login-sub">请输入管理员账号密码以继续</p>
			{#if loginError}<p class="login-error">{loginError}</p>{/if}
			<div class="field-wrap">
				<span class="field-ic">@</span>
				<input class="field" type="text" placeholder="账号" bind:value={loginUser} />
			</div>
			<div class="field-wrap">
				<span class="field-ic">•</span>
				<input class="field" type="password" placeholder="密码" bind:value={loginPass}
					on:keydown={(e) => e.key === "Enter" && handleLogin()} />
			</div>
			<button class="btn-primary login-btn" on:click={handleLogin} disabled={loginLoading}>
				{loginLoading ? "登录中…" : "进入管理"}
			</button>
			<a class="back-link" href="/resources/">← 返回收藏页</a>
		</div>
	{:else}
		<div class="panel">
			<div class="mode-tabs">
				<button class="mode-tab" class:on={mode==="ai"} on:click={() => switchMode("ai")}>AI 工具</button>
				<button class="mode-tab" class:on={mode==="archive"} on:click={() => switchMode("archive")}>收藏链接</button>
			</div>
			<div class="panel-header">
				<div>
					<h2>{mode === "ai" ? "AI 管理" : "收藏管理"}</h2>
					<p class="panel-sub">共 {items.length} 个{mode === "ai" ? "AI 工具" : "收藏链接"}</p>
				</div>
				<div class="cat-single" role="navigation">
					<div class="cat-single-wrap">
						<button class="cat-single-btn" on:click|preventDefault={() => menuOpen = !menuOpen}>
							{activeCat || "全部分类"}
							{#if activeCat && subCat} · {subCat}{/if}
							<span class="caret">▾</span>
						</button>
						{#if menuOpen}
							<div class="cat-pop">
								{#each catList as c}
									{@const subs = c === "影视" ? ["综合","动漫","短剧","其他"] : subCatsFor(c)}
									<div class="cat-pop-group">
										<button class="cat-pop-title"
											class:active={activeCat===c && subCat===""}
											on:click|preventDefault={() => { setCat(c); menuOpen = false; }}>{c}</button>
										<div class="cat-pop-subs">
											{#each subs as sc}
												<button class="cat-chip" class:active={activeCat===c && subCat===sc}
													on:click|preventDefault={() => { activeCat = c; subCat = sc; menuOpen = false; }}>{sc}</button>
											{/each}
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
				<div class="panel-actions">
					<button class="btn-primary" on:click={() => { showForm = !showForm; if (showForm) resetForm(); }}>
						{showForm ? "取消" : (mode === "ai" ? "+ 添加 AI" : "+ 添加收藏")}
					</button>
					<button class="btn-secondary" on:click={loadItems}>刷新</button>
					<button class="btn-danger" on:click={handleLogout}>退出</button>
				</div>
			</div>

			{#if actionMessage}<div class="action-msg">{actionMessage}</div>{/if}

			{#if showForm}
				<div class="form-card">
					<h3>{editingId ? (mode==="ai" ? `编辑 · ${fTitle || "AI"}` : `编辑 · ${fTitle || "收藏"}`) : (mode==="ai"?`添加 AI · ${fCategory}`:`添加收藏 · ${fCategory}`)}</h3>
					<div class="form-row">
						<label>名称 *
							<input class="field" type="text" bind:value={fTitle} placeholder="例如：GitHub" />
						</label>
						<label>网址 *
							<input class="field" type="text" bind:value={fUrl} placeholder="https://…" />
						</label>
					</div>
					<div class="form-row">
						{#if mode === "ai"}
							<label>Logo
								<div class="logo-row">
									<input type="file" accept="image/*" on:change={handleLogoUpload} disabled={logoUploading} />
									{#if fLogo}<img class="logo-preview" src={fLogo} alt="logo" />{/if}
									{#if fLogo}<button type="button" class="btn-mini" on:click={() => fLogo = ""}>清除</button>{/if}
								</div>
							</label>
						{/if}
					</div>
						{#if mode !== "ai" && fCategory === "影视"}
							<div class="form-row">
								<label>影视子分类
									<select class="field" bind:value={fGroup}>
										<option value="综合">综合</option>
										<option value="动漫">动漫</option>
										<option value="短剧">短剧</option>
										<option value="其他">其他</option>
									</select>
								</label>
							</div>
						{:else if mode !== "ai" && (fCategory === "工具" || fCategory === "社区")}
							<div class="form-row">
								<label>分组 / 分类名
									<input class="field" list="group-list" bind:value={fGroup} placeholder="选现有分组或输入新分组名" />
									<datalist id="group-list">
										{#each subCatsFor(fCategory) as g}
											<option value={g}></option>
										{/each}
									</datalist>
								</label>
							</div>
						{/if}
					<div class="form-actions">
						<button class="btn-primary" on:click={handleSave} disabled={submitting}>
							{submitting ? "保存中…" : "保存"}
						</button>
						<button class="btn-secondary" on:click={() => { showForm = false; resetForm(); }}>关闭</button>
					</div>
				</div>
			{/if}

			{#if loading}
				<p class="empty">加载中…</p>
			{:else if shownItems.length === 0}
				<p class="empty">该分类下暂无收藏，点击「+ 添加收藏」</p>
			{:else}
				<div class="item-list">
					{#each shownItems as it, i (it.id)}
						<div class="item" draggable="true"
							on:dragstart={(e) => onDragStart(e, i)}
							on:dragover={(e) => e.preventDefault()}
							on:drop|preventDefault={() => onDrop(i)}>
							<div class="item-main">
								<div class="item-title">{it.title || it.name}
									<span class="tag">{it.category}</span>
									{#if it.tags && it.tags[0]}<span class="tag tag-soft">{it.tags[0]}</span>{/if}
								</div>
								<div class="item-url">{it.url}</div>
								{#if it.description}<div class="item-desc">{it.description}</div>{/if}
							</div>
							<div class="item-actions">
								<button class="btn-mini" on:click={() => startEdit(it)}>编辑</button>
								<button class="btn-mini btn-mini-danger" on:click={() => handleDelete(it)}>删除</button>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.admin-wrap {
		max-width: 880px;
		margin: 0 auto;
		padding: 24px 20px 60px;
		color: #e6ebf5;
	}
	.login-card {
		background: rgba(20, 26, 46, 0.6);
		border: 1px solid rgba(111, 195, 255, 0.18);
		border-radius: 16px;
		padding: 38px 34px;
		backdrop-filter: blur(10px);
		box-shadow: 0 20px 60px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.04);
	}
	.panel { padding: 0; }
	.login-card {
		max-width: 400px;
		margin: 8vh auto 0;
		padding: 38px 34px;
		box-shadow: 0 20px 60px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.04);
	}
	.login-mark {
		font-size: 0.68rem;
		letter-spacing: 0.25em;
		color: #6ea8ff;
		margin-bottom: 10px;
	}
	.login-card h2, .panel h2 { margin: 0 0 6px; font-size: 1.3rem; }
	.login-sub, .panel-sub { color: #8b96ad; font-size: 0.85rem; margin: 0 0 18px; }
	.login-error { color: #f87171; font-size: 0.85rem; }
	.field {
		width: 100%;
		box-sizing: border-box;
		padding: 0.6rem 0.8rem;
		background: rgba(8, 12, 26, 0.7);
		border: 1px solid rgba(111, 195, 255, 0.22);
		border-radius: 8px;
		color: #e6ebf5;
		font-size: 0.92rem;
	}
	.field-wrap { position: relative; margin: 0 0 0.9rem; }
	.field-wrap .field { padding-left: 2.1rem; }
	.field-wrap .field:focus { outline: none; border-color: rgba(99,102,241,0.7); box-shadow: 0 0 0 3px rgba(99,102,241,0.18); }
	.field-ic { position: absolute; left: 0.8rem; top: 50%; transform: translateY(-50%); color: #6ea8ff; font-size: 0.9rem; }
	.login-btn { width: 100%; margin-top: 0.4rem; padding: 0.7rem; font-size: 0.95rem; letter-spacing: 0.05em; }
	label { display: block; font-size: 0.85rem; color: #aab4cc; }
	.btn-primary, .btn-secondary, .btn-danger {
		padding: 0.55rem 1.1rem;
		border-radius: 8px;
		border: 1px solid transparent;
		cursor: pointer;
		font-size: 0.9rem;
	}
	.btn-primary { background: linear-gradient(135deg, #6366f1, #8b5cf6); color: #fff; }
	.btn-secondary { background: transparent; border-color: rgba(111,195,255,0.3); color: #cfe6ff; }
	.btn-danger { background: transparent; border-color: rgba(248,113,113,0.4); color: #fca5a5; }
	.btn-primary:disabled { opacity: 0.6; }
	.back-link { display: inline-block; margin-top: 14px; color: #8b96ad; font-size: 0.85rem; text-decoration: none; }
	.panel-header { display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 0.8rem; margin-bottom: 1rem; }
	.panel-actions { display: flex; gap: 0.5rem; flex-wrap: wrap; }
	.mode-tabs { display:flex; gap:0.5rem; margin-bottom:1rem; }
	.mode-tab { padding:0.5rem 1.2rem; font-size:0.9rem; border-radius:10px; border:1px solid rgba(111,195,255,0.25); background:transparent; color:#9fb4d8; cursor:pointer; }
	.mode-tab.on { background:linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff; border-color:transparent; }
	.cat-tabs { display: flex; gap: 0.4rem; flex-wrap: wrap; }
	.cat-tab { padding: 0.35rem 0.85rem; font-size: 0.82rem; border-radius: 999px; border: 1px solid rgba(111,195,255,0.25); background: transparent; color: #9fb4d8; cursor: pointer; }
	.cat-tab.on { background: linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff; border-color: transparent; }
	.cat-single-wrap { position: relative; }
	.cat-single-btn {
		padding: 0.5rem 1rem; font-size: 0.85rem; border-radius: 999px;
		border: 1px solid rgba(111,195,255,0.22); background: rgba(20,28,48,0.55);
		color: #cfe3ff; cursor: pointer; white-space: nowrap; backdrop-filter: blur(14px);
		transition: all 0.2s ease;
	}
	.cat-single-btn:hover { border-color: rgba(106,179,255,0.5); color:#fff; }
	.caret { font-size:0.65rem; opacity:0.6; margin-left:0.2rem; }
	.cat-pop {
		position: absolute; top: 100%; left: 0; margin-top: 0.6rem; min-width: 300px;
		display:flex; flex-direction:column; gap:0.1rem; padding: 0.9rem; z-index: 60;
		border-radius: 18px; border: 1px solid rgba(255,255,255,0.09);
		background: linear-gradient(160deg, rgba(28,38,66,0.78), rgba(14,20,38,0.82));
		backdrop-filter: blur(24px) saturate(160%);
		box-shadow: 0 18px 50px rgba(0,0,0,0.55), inset 0 1px 0 rgba(255,255,255,0.06);
		animation: catPopIn 180ms ease-out;
	}
	@keyframes catPopIn {
		from { opacity: 0; transform: translateY(-8px); }
		to { opacity: 1; transform: translateY(0); }
	}
	.cat-pop-group { padding: 0.35rem 0.2rem; }
	.cat-pop-group + .cat-pop-group { border-top: 1px solid rgba(255,255,255,0.06); }
	.cat-pop-title {
		text-align:left; padding: 0.25rem 0.1rem; font-size: 0.72rem; font-weight:600;
		letter-spacing:0.12em; text-transform:uppercase;
		background: transparent; border: none; color: rgba(160,200,255,0.55); cursor: pointer;
		transition: color 0.2s ease, text-shadow 0.2s ease;
	}
	.cat-pop-title:hover, .cat-pop-title.active { color:#9fd0ff; text-shadow: 0 0 12px rgba(106,179,255,0.5); }
	.cat-pop-subs { display:flex; flex-wrap:wrap; gap:0.35rem; margin-top:0.45rem; }
	.cat-chip {
		padding: 0.32rem 0.8rem; font-size: 0.8rem; border-radius: 999px;
		background: rgba(255,255,255,0.045); border: 1px solid rgba(255,255,255,0.07);
		color: #d6e6ff; cursor: pointer; transition: all 0.18s ease;
	}
	.cat-chip:hover { background: rgba(106,179,255,0.16); border-color: rgba(106,179,255,0.35); transform: translateY(-1px); }
	.cat-chip.active { background: rgba(106,179,255,0.28); border-color: rgba(106,179,255,0.55); color:#fff; }
	.sub-tabs .cat-tab { padding: 0.28rem 0.75rem; font-size: 0.78rem; }
	.sub-tabs { display:flex; gap:0.35rem; flex-wrap:wrap; margin-top:0.5rem; }
	.sub-tab { padding:0.25rem 0.7rem; font-size:0.76rem; border-radius:999px; border:1px solid rgba(111,195,255,0.18); background:transparent; color:#8aa0c8; cursor:pointer; }
	.sub-tab.on { background:rgba(99,102,241,0.35); color:#dbe4ff; }
	.action-msg { padding: 0.6rem 0.85rem; background: rgba(16,185,129,0.14); border: 1px solid rgba(16,185,129,0.3); color: #34d399; border-radius: 8px; font-size: 0.85rem; margin-bottom: 1rem; }
	.form-card { background: rgba(8,12,26,0.55); border: 1px solid rgba(111,195,255,0.18); border-radius: 14px; padding: 22px; margin-bottom: 1.2rem; }
	.form-card h3 { margin: 0 0 16px; font-size: 1.02rem; color:#eef2ff; }
	.form-card label { margin-bottom: 12px; }
	.form-row { display: flex; gap: 14px; }
	.form-row label { flex: 1; }
	.logo-row { display:flex; align-items:center; gap:12px; margin-top:8px; }
	.logo-row input[type=file] { font-size:0.8rem; color:#9fb4d8; }
	.logo-row input[type=file]::file-selector-button { padding:0.4rem 0.9rem; border-radius:8px; border:1px solid rgba(111,195,255,0.3); background:rgba(99,102,241,0.15); color:#cfe6ff; cursor:pointer; margin-right:8px; }
	.logo-preview { width:40px; height:40px; border-radius:8px; object-fit:cover; border:1px solid rgba(111,195,255,0.3); }
	.form-actions { display: flex; gap: 0.6rem; margin-top: 0.4rem; }
	.empty { color: #8b96ad; text-align: center; padding: 30px 0; }
	.item-list { display: flex; flex-direction: column; gap: 0.6rem; }
	.item { display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding: 0.85rem 1.1rem; background: rgba(8,12,26,0.5); border: 1px solid rgba(111,195,255,0.14); border-radius: 12px; transition: border-color .2s, transform .2s, box-shadow .2s; }
	.item:hover { border-color: rgba(99,102,241,0.5); box-shadow: 0 8px 24px rgba(0,0,0,0.3); transform: translateY(-1px); }
	.item-title { font-size: 1rem; font-weight: 600; color:#eef2ff; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }
	.item-url { font-size: 0.8rem; color: #7fd0ff; word-break: break-all; margin-top: 4px; }
	.item-desc { font-size: 0.8rem; color: #9aa6c0; margin-top: 4px; }
	.tag { font-size: 0.7rem; padding: 1px 8px; border-radius: 999px; background: rgba(99,102,241,0.25); color: #c7d2fe; }
	.tag-soft { background: rgba(255,255,255,0.08); color: #aab4cc; }
	.item-actions { display: flex; gap: 0.4rem; flex-shrink: 0; }
	.btn-mini { padding: 0.35rem 0.7rem; font-size: 0.8rem; border-radius: 6px; border: 1px solid rgba(111,195,255,0.3); background: transparent; color: #cfe6ff; cursor: pointer; }
	.btn-mini-danger { border-color: rgba(248,113,113,0.4); color: #fca5a5; }
	@media (max-width: 600px) {
		.admin-wrap { padding: 90px 12px 50px; }
		.login-card, .panel { padding: 18px 16px; }
		.form-row { flex-direction: column; gap: 0; }
		.panel-header { flex-direction: column; align-items: stretch; gap: 0.8rem; }
		.panel-header h2 { white-space: nowrap; font-size: 1.15rem; }
		.panel-actions { display: flex; gap: 0.4rem; }
		.panel-actions button { flex: 1; }
		.cat-tabs { gap: 0.35rem; }
		.cat-tab { padding: 0.3rem 0.7rem; font-size: 0.78rem; }
		.btn-primary, .btn-secondary, .btn-danger { font-size: 0.78rem; padding: 0.45rem 0.5rem; white-space: nowrap; }
		.item { flex-direction: column; align-items: stretch; gap: 0.6rem; }
		.item-actions { justify-content: flex-end; }
	}
</style>
