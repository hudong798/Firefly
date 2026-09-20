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

	const CATEGORIES = ["影视", "漫画", "社区", "工具"] as const;
	type Cat = typeof CATEGORIES[number];
	type Filter = "全部" | Cat;
	let activeCat: Filter = "全部";
	let subCat = "";
	function setCat(c: Filter) { activeCat = c; subCat = ""; }
	$: baseItems = activeCat === "全部" ? items : items.filter((i) => i.category === activeCat);
	$: subCats = [...new Set(baseItems.map((i) => (i.tags && i.tags[0]) || "").filter(Boolean))];
	$: shownItems = subCat ? baseItems.filter((i) => (i.tags && i.tags[0]) === subCat) : baseItems;

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
			const { data, error } = await supabase.rpc("admin_list_archives");
			if (error) throw error;
			items = (data || []) as ArchiveItem[];
		} catch (e: any) {
			actionMessage = "加载失败：" + (e?.message || "未知错误");
		} finally {
			loading = false;
		}
	}

	// 表单
	let showForm = false;
	let editingId: string | null = null;
	let fTitle = "";
	let fUrl = "";
	let fCategory: typeof CATEGORIES[number] = "影视";
	let fDesc = "";
	let fGroup = "";
	let submitting = false;

	function resetForm() {
		editingId = null;
		fTitle = ""; fUrl = ""; fCategory = activeCat === "全部" ? "影视" : activeCat; fDesc = ""; fGroup = subCat;
	}

	function startEdit(it: ArchiveItem) {
		showForm = true;
		editingId = it.id;
		fTitle = it.title;
		fUrl = it.url;
		fCategory = it.category;
		fDesc = it.description || "";
		fGroup = (it.tags && it.tags[0]) || "";
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
				p_username: creds?.username,
				p_password: creds?.password
			};
			if (editingId) payload.p_id = editingId;
			const { error } = await supabase.rpc(editingId ? "admin_update_archive" : "admin_create_archive", payload);
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
			const { error } = await supabase.rpc("admin_delete_archive", {
				p_id: it.id, p_username: creds?.username, p_password: creds?.password
			});
			if (error) throw error;
			actionMessage = "已删除";
			loadItems();
		} catch (e: any) {
			actionMessage = "删除失败：" + (e?.message || "未知错误");
		}
	}

	onMount(() => {
		checkAuth();
		if (loggedIn) loadItems();
	});
</script>

<div class="admin-wrap">
	{#if !loggedIn}
		<div class="login-card">
			<h2>收藏管理登录</h2>
			<p class="login-sub">使用管理员账号密码登录</p>
			{#if loginError}<p class="login-error">{loginError}</p>{/if}
			<input class="field" type="text" placeholder="账号" bind:value={loginUser} />
			<input class="field" type="password" placeholder="密码" bind:value={loginPass}
				on:keydown={(e) => e.key === "Enter" && handleLogin()} />
			<button class="btn-primary" on:click={handleLogin} disabled={loginLoading}>
				{loginLoading ? "登录中…" : "登录"}
			</button>
			<a class="back-link" href="/resources/">← 返回收藏页</a>
		</div>
	{:else}
		<div class="panel">
			<div class="panel-header">
				<div>
					<h2>收藏管理</h2>
					<p class="panel-sub">共 {items.length} 个收藏链接</p>
				</div>
				<div class="cat-tabs">
					<button class="cat-tab" class:on={activeCat==="全部"} on:click={() => setCat("全部")}>全部</button>
					{#each CATEGORIES as c}
						<button class="cat-tab" class:on={activeCat===c} on:click={() => setCat(c)}>{c}</button>
					{/each}
				</div>
				<div class="panel-actions">
					<button class="btn-primary" on:click={() => { showForm = !showForm; if (showForm) resetForm(); }}>
						{showForm ? "取消" : "+ 添加收藏"}
					</button>
					<button class="btn-secondary" on:click={loadItems}>刷新</button>
					<button class="btn-danger" on:click={handleLogout}>退出</button>
				</div>
			</div>

			{#if actionMessage}<div class="action-msg">{actionMessage}</div>{/if}

			{#if showForm}
				<div class="form-card">
					<h3>{editingId ? "编辑收藏" : `添加收藏 · ${fCategory}`}</h3>
					<div class="form-row">
						<label>名称 *
							<input class="field" type="text" bind:value={fTitle} placeholder="例如：GitHub" />
						</label>
						<label>网址 *
							<input class="field" type="text" bind:value={fUrl} placeholder="https://…" />
						</label>
					</div>
					<div class="form-row">
						<label>分类
							<select class="field" bind:value={fCategory}>
								{#each CATEGORIES as c}<option value={c}>{c}</option>{/each}
							</select>
						</label>
						<label>小分类（如 动漫/短剧/综合，可空）
							<input class="field" type="text" list="subgroup-list" bind:value={fGroup} placeholder="选择或输入小分类" />
							<datalist id="subgroup-list">
								{#each subCats as sc}
									<option value={sc}></option>
								{/each}
							</datalist>
						</label>
					</div>
					<label>描述
						<input class="field" type="text" bind:value={fDesc} placeholder="一句话介绍（可空）" />
					</label>
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
					{#each shownItems as it (it.id)}
						<div class="item">
							<div class="item-main">
								<div class="item-title">{it.title}
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
		padding: 100px 20px 60px;
		color: #e6ebf5;
	}
	.login-card, .panel {
		background: rgba(20, 26, 46, 0.6);
		border: 1px solid rgba(111, 195, 255, 0.18);
		border-radius: 14px;
		padding: 28px;
		backdrop-filter: blur(8px);
	}
	.login-card h2, .panel h2 { margin: 0 0 6px; font-size: 1.3rem; }
	.login-sub, .panel-sub { color: #8b96ad; font-size: 0.85rem; margin: 0 0 18px; }
	.login-error { color: #f87171; font-size: 0.85rem; }
	.field {
		width: 100%;
		box-sizing: border-box;
		padding: 0.6rem 0.8rem;
		margin: 0.3rem 0 0.9rem;
		background: rgba(8, 12, 26, 0.7);
		border: 1px solid rgba(111, 195, 255, 0.22);
		border-radius: 8px;
		color: #e6ebf5;
		font-size: 0.92rem;
	}
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
	.cat-tabs { display: flex; gap: 0.4rem; flex-wrap: wrap; }
	.cat-tab { padding: 0.35rem 0.85rem; font-size: 0.82rem; border-radius: 999px; border: 1px solid rgba(111,195,255,0.25); background: transparent; color: #9fb4d8; cursor: pointer; }
	.cat-tab.on { background: linear-gradient(135deg,#6366f1,#8b5cf6); color:#fff; border-color: transparent; }
	.sub-tabs { display:flex; gap:0.35rem; flex-wrap:wrap; margin-top:0.5rem; }
	.sub-tab { padding:0.25rem 0.7rem; font-size:0.76rem; border-radius:999px; border:1px solid rgba(111,195,255,0.18); background:transparent; color:#8aa0c8; cursor:pointer; }
	.sub-tab.on { background:rgba(99,102,241,0.35); color:#dbe4ff; }
	.action-msg { padding: 0.6rem 0.85rem; background: rgba(16,185,129,0.14); border: 1px solid rgba(16,185,129,0.3); color: #34d399; border-radius: 8px; font-size: 0.85rem; margin-bottom: 1rem; }
	.form-card { background: rgba(8,12,26,0.5); border: 1px solid rgba(111,195,255,0.18); border-radius: 12px; padding: 18px; margin-bottom: 1.2rem; }
	.form-card h3 { margin: 0 0 12px; font-size: 1rem; }
	.form-row { display: flex; gap: 14px; }
	.form-row label { flex: 1; }
	.form-actions { display: flex; gap: 0.6rem; margin-top: 0.4rem; }
	.empty { color: #8b96ad; text-align: center; padding: 30px 0; }
	.item-list { display: flex; flex-direction: column; gap: 0.7rem; }
	.item { display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding: 0.9rem 1rem; background: rgba(8,12,26,0.45); border: 1px solid rgba(111,195,255,0.14); border-radius: 10px; }
	.item-title { font-size: 0.98rem; font-weight: 600; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }
	.item-url { font-size: 0.8rem; color: #7fd0ff; word-break: break-all; margin-top: 3px; }
	.item-desc { font-size: 0.82rem; color: #9aa6c0; margin-top: 3px; }
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
