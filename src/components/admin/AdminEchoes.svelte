<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	interface Echo {
		id: string;
		slug: string;
		title: string;
		content: string;
		mood: string | null;
		tags: string[] | null;
		status: string;
		created_at: string;
	}

	// 默认管理密码（Supabase 读取失败时使用）
	const DEFAULT_ADMIN_PASSWORD = "52798";

	let loggedIn = false;
	let loading = false;
	let echoes: Echo[] = [];
	let echoesLoading = false;
	let password = "";
	let loginError = "";
	let actionMessage = "";

	// 从 Supabase 获取管理密码
	async function getAdminPassword(): Promise<string> {
		if (!supabase) return DEFAULT_ADMIN_PASSWORD;
		try {
			const { data, error } = await supabase
				.from("site_config")
				.select("value")
				.eq("key", "admin_password")
				.single();
			if (!error && data?.value) {
				return data.value;
			}
		} catch (e) {
			// 表不存在或读取失败，使用默认密码
		}
		return DEFAULT_ADMIN_PASSWORD;
	}

	// 新建回声表单
	let showForm = false;
	let newTitle = "";
	let newSlug = "";
	let newContent = "";
	let newMood = "";
	let newTags = "";
	let submitting = false;

	const moodOptions = ["🌙", "😆", "🌱", "😊", "🤔", "😴", "✨", "🔥", "💭", "☕"];

	async function handleLogin() {
		if (!password) {
			loginError = "请输入密码";
			return;
		}

		loading = true;
		loginError = "";

		try {
			const adminPassword = await getAdminPassword();
			if (password === adminPassword) {
				loggedIn = true;
				if (typeof window !== "undefined") {
					localStorage.setItem("echo_admin_logged_in", "true");
				}
				loadEchoes();
			} else {
				loginError = "密码错误";
			}
		} catch (e) {
			loginError = "登录失败，请重试";
		} finally {
			loading = false;
		}
	}

	function handleLogout() {
		loggedIn = false;
		echoes = [];
		password = "";
		showForm = false;
	}

	async function loadEchoes() {
		if (!supabase) return;
		echoesLoading = true;
		try {
			const { data, error } = await supabase
				.from("echoes")
				.select("*")
				.order("created_at", { ascending: false })
				.limit(100);

			if (error) throw error;
			echoes = (data as Echo[]) || [];
		} catch (e) {
			console.error("加载回声失败:", e);
			actionMessage = "加载失败";
		} finally {
			echoesLoading = false;
		}
	}

	function generateSlug() {
		if (newSlug) return;
		const base = newTitle
			.toLowerCase()
			.replace(/[^\w\u4e00-\u9fa5]+/g, "-")
			.replace(/^-+|-+$/g, "")
			.slice(0, 50);
		newSlug = base || `echo-${Date.now()}`;
	}

	async function submitEcho() {
		if (!supabase) return;
		if (!newTitle.trim() || !newContent.trim()) {
			actionMessage = "标题和内容不能为空";
			return;
		}

		submitting = true;
		actionMessage = "";

		try {
			generateSlug();
			const tagsArr = newTags
				? newTags.split(/[,，\s]+/).filter((t) => t.trim())
				: [];

			const { error } = await supabase.from("echoes").insert({
				slug: newSlug,
				title: newTitle.trim(),
				content: newContent.trim(),
				mood: newMood || null,
				tags: tagsArr.length > 0 ? tagsArr : null,
				status: "published",
			});

			if (error) throw error;

			actionMessage = "公告发布成功！";
			// 重置表单
			newTitle = "";
			newSlug = "";
			newContent = "";
			newMood = "";
			newTags = "";
			showForm = false;
			loadEchoes();
		} catch (e: any) {
			actionMessage = e?.message || "发布失败";
		} finally {
			submitting = false;
		}
	}

	async function deleteEcho(id: string) {
		if (!supabase) return;
		if (!confirm("确定删除这条公告吗？此操作不可撤销。")) return;
		try {
			const { error } = await supabase.from("echoes").delete().eq("id", id);
			if (error) throw error;
			actionMessage = "已删除";
			loadEchoes();
		} catch (e: any) {
			actionMessage = e?.message || "删除失败";
		}
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
	}

	onMount(() => {
		// 从 localStorage 读取登录状态
		if (typeof window !== "undefined" && localStorage.getItem("echo_admin_logged_in") === "true") {
			loggedIn = true;
			loadEchoes();
		}
	});
</script>

<div class="admin-echoes">
	{#if !loggedIn}
		<!-- 登录表单 -->
		<div class="admin-login">
			<h2>公告管理登录</h2>
			<p class="admin-login-sub">登录后可以发布和管理公告</p>

			{#if loginError}
				<div class="admin-error">{loginError}</div>
			{/if}

			<div class="admin-form-group">
				<label for="echo-password">管理密码</label>
				<input
					id="echo-password"
					type="password"
					bind:value={password}
					placeholder="••••••••"
					on:keydown={(e) => e.key === "Enter" && handleLogin()}
				/>
			</div>

			<button class="admin-login-btn" on:click={handleLogin} disabled={loading}>
				{#if loading}登录中...{:else}登录{/if}
			</button>
		</div>
	{:else}
		<!-- 管理面板 -->
		<div class="admin-panel">
			<div class="admin-panel-header">
				<div>
					<h2>公告管理</h2>
					<p class="admin-panel-sub">共 {echoes.length} 条公告</p>
				</div>
				<div class="admin-panel-actions">
					<button class="admin-btn admin-btn-primary" on:click={() => (showForm = !showForm)}>
						{#if showForm}取消{:else}+ 写公告{/if}
					</button>
					<button class="admin-btn admin-btn-secondary" on:click={loadEchoes}>刷新</button>
					<button class="admin-btn admin-btn-danger" on:click={handleLogout}>退出</button>
				</div>
			</div>

			{#if actionMessage}
				<div class="admin-action-message">{actionMessage}</div>
			{/if}

			<!-- 新建回声表单 -->
			{#if showForm}
				<div class="echo-form">
					<h3>发布新公告</h3>

					<div class="form-row">
						<div class="form-group">
							<label>标题 *</label>
							<input type="text" bind:value={newTitle} placeholder="给这条公告起个标题" />
						</div>
						<div class="form-group">
							<label>Slug（URL，留空自动生成）</label>
							<input type="text" bind:value={newSlug} placeholder="my-echo" />
						</div>
					</div>

					<div class="form-group">
						<label>内容 *</label>
						<textarea bind:value={newContent} rows={6} placeholder="写下你此刻的想法..."></textarea>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label>心情</label>
							<div class="mood-picker">
								{#each moodOptions as mood}
									<button
										class="mood-btn"
										class:active={newMood === mood}
										on:click={() => (newMood = newMood === mood ? "" : mood)}
										type="button"
									>{mood}</button>
								{/each}
							</div>
						</div>
						<div class="form-group">
							<label>标签（逗号分隔）</label>
							<input type="text" bind:value={newTags} placeholder="随笔, 日常, 建站" />
						</div>
					</div>

					<button class="admin-submit-btn" on:click={submitEcho} disabled={submitting}>
						{#if submitting}发布中...{:else}发布公告{/if}
					</button>
				</div>
			{/if}

			<!-- 回声列表 -->
			{#if echoesLoading}
				<div class="admin-loading">加载中...</div>
			{:else if echoes.length === 0}
				<div class="admin-empty">还没有公告，点击「写公告」发布第一条</div>
			{:else}
				<div class="echo-list">
					{#each echoes as echo (echo.id)}
						<div class="echo-item">
							<div class="echo-item-header">
								<div class="echo-item-title">
									{#if echo.mood}<span class="echo-mood">{echo.mood}</span>{/if}
									<span>{echo.title}</span>
								</div>
								<div class="echo-item-meta">
									<span class="echo-date">{formatDate(echo.created_at)}</span>
									<span class="echo-slug">/{echo.slug}</span>
									{#if echo.tags && echo.tags.length > 0}
										<span class="echo-tags">{echo.tags.join(" · ")}</span>
									{/if}
								</div>
							</div>
							<div class="echo-item-content">{echo.content.length > 120 ? echo.content.slice(0, 120) + "..." : echo.content}</div>
							<div class="echo-item-actions">
								<a href={`/thoughts/?slug=${encodeURIComponent(echo.slug)}`} target="_blank" class="admin-btn admin-btn-secondary">查看</a>
								<button class="admin-btn admin-btn-danger" on:click={() => deleteEcho(echo.id)}>删除</button>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.admin-echoes {
		font-family: inherit;
		color: #f1f5f9;
		max-width: 900px;
		margin: 0 auto;
		padding: 2rem 1rem;
	}

	/* 登录表单 */
	.admin-login {
		max-width: 420px;
		margin: 4rem auto;
		padding: 2.5rem 2rem;
		background: rgba(15, 23, 42, 0.85);
		border: 1px solid rgba(99, 102, 241, 0.2);
		border-radius: 16px;
		backdrop-filter: blur(10px);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
	}

	.admin-login h2 {
		font-size: 1.4rem;
		font-weight: 600;
		margin: 0 0 0.5rem 0;
		color: #f1f5f9;
	}

	.admin-login-sub {
		font-size: 0.85rem;
		color: #94a3b8;
		margin: 0 0 1.5rem 0;
	}

	.admin-error {
		padding: 0.6rem 0.85rem;
		background: rgba(239, 68, 68, 0.15);
		color: #f87171;
		border: 1px solid rgba(239, 68, 68, 0.3);
		border-radius: 8px;
		font-size: 0.85rem;
		margin-bottom: 1rem;
	}

	.admin-form-group {
		margin-bottom: 1.25rem;
	}

	.admin-form-group label {
		display: block;
		font-size: 0.8rem;
		color: #cbd5e1;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}

	.admin-form-group input,
	.admin-form-group textarea {
		width: 100%;
		padding: 0.75rem 1rem;
		background: rgba(30, 41, 59, 0.8);
		border: 1px solid rgba(148, 163, 184, 0.25);
		border-radius: 10px;
		color: #f1f5f9;
		font-size: 0.95rem;
		box-sizing: border-box;
		transition: all 0.2s;
		font-family: inherit;
		resize: vertical;
	}

	.admin-form-group input::placeholder,
	.admin-form-group textarea::placeholder {
		color: #64748b;
	}

	.admin-form-group input:focus,
	.admin-form-group textarea:focus {
		outline: none;
		border-color: #6366f1;
		background: rgba(30, 41, 59, 0.95);
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
	}

	.admin-login-btn {
		width: 100%;
		padding: 0.85rem;
		background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.admin-login-btn:hover:not(:disabled) {
		opacity: 0.92;
		transform: translateY(-1px);
		box-shadow: 0 4px 16px rgba(99, 102, 241, 0.4);
	}

	.admin-login-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* 管理面板 */
	.admin-panel-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.admin-panel-header h2 {
		font-size: 1.4rem;
		font-weight: 600;
		margin: 0 0 0.3rem 0;
		color: #f1f5f9;
	}

	.admin-panel-sub {
		font-size: 0.85rem;
		color: #94a3b8;
		margin: 0;
	}

	.admin-panel-actions {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.admin-action-message {
		padding: 0.6rem 0.85rem;
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border: 1px solid rgba(16, 185, 129, 0.3);
		border-radius: 8px;
		font-size: 0.85rem;
		margin-bottom: 1rem;
	}

	/* 按钮 */
	.admin-btn {
		padding: 0.45rem 0.9rem;
		border: none;
		border-radius: 8px;
		font-size: 0.8rem;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
		text-decoration: none;
		display: inline-block;
	}

	.admin-btn:hover {
		opacity: 0.85;
		transform: translateY(-1px);
	}

	.admin-btn-primary {
		background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
		color: white;
	}

	.admin-btn-secondary {
		background: rgba(51, 65, 85, 0.8);
		color: #e2e8f0;
		border: 1px solid rgba(148, 163, 184, 0.2);
	}

	.admin-btn-danger {
		background: rgba(239, 68, 68, 0.15);
		color: #f87171;
		border: 1px solid rgba(239, 68, 68, 0.3);
	}

	/* 新建回声表单 */
	.echo-form {
		padding: 1.5rem;
		background: rgba(15, 23, 42, 0.6);
		border: 1px solid rgba(99, 102, 241, 0.2);
		border-radius: 12px;
		margin-bottom: 1.5rem;
	}

	.echo-form h3 {
		font-size: 1.1rem;
		font-weight: 600;
		margin: 0 0 1.25rem 0;
		color: #f1f5f9;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		font-size: 0.8rem;
		color: #cbd5e1;
		margin-bottom: 0.4rem;
		font-weight: 500;
	}

	.form-group input,
	.form-group textarea {
		width: 100%;
		padding: 0.65rem 0.85rem;
		background: rgba(30, 41, 59, 0.8);
		border: 1px solid rgba(148, 163, 184, 0.2);
		border-radius: 8px;
		color: #f1f5f9;
		font-size: 0.9rem;
		box-sizing: border-box;
		font-family: inherit;
		resize: vertical;
	}

	.form-group input:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #6366f1;
	}

	.mood-picker {
		display: flex;
		flex-wrap: wrap;
		gap: 0.4rem;
	}

	.mood-btn {
		width: 2.2rem;
		height: 2.2rem;
		border-radius: 8px;
		border: 1px solid rgba(148, 163, 184, 0.2);
		background: rgba(30, 41, 59, 0.6);
		cursor: pointer;
		font-size: 1rem;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.mood-btn:hover {
		border-color: rgba(99, 102, 241, 0.5);
	}

	.mood-btn.active {
		background: rgba(99, 102, 241, 0.2);
		border-color: #6366f1;
	}

	.admin-submit-btn {
		padding: 0.7rem 1.5rem;
		background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.admin-submit-btn:hover:not(:disabled) {
		opacity: 0.9;
	}

	.admin-submit-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* 回声列表 */
	.admin-loading,
	.admin-empty {
		text-align: center;
		padding: 3rem;
		color: #94a3b8;
	}

	.echo-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.echo-item {
		padding: 1.25rem;
		background: rgba(15, 23, 42, 0.6);
		border: 1px solid rgba(148, 163, 184, 0.12);
		border-radius: 12px;
		transition: border-color 0.2s;
	}

	.echo-item:hover {
		border-color: rgba(99, 102, 241, 0.3);
	}

	.echo-item-header {
		margin-bottom: 0.75rem;
	}

	.echo-item-title {
		font-size: 1rem;
		font-weight: 600;
		color: #f1f5f9;
		margin-bottom: 0.4rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.echo-mood {
		font-size: 1.1rem;
	}

	.echo-item-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75rem;
		font-size: 0.75rem;
		color: #64748b;
	}

	.echo-slug {
		font-family: monospace;
		color: #a5b4fc;
	}

	.echo-tags {
		color: #94a3b8;
	}

	.echo-item-content {
		font-size: 0.85rem;
		line-height: 1.7;
		color: #cbd5e1;
		margin-bottom: 0.75rem;
	}

	.echo-item-actions {
		display: flex;
		gap: 0.5rem;
	}

	@media (max-width: 640px) {
		.form-row {
			grid-template-columns: 1fr;
		}

		.admin-echoes {
			padding: 1rem;
		}
	}
</style>
