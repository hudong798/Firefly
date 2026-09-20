<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	// 复用说说管理员登录态（同一套账号体系 idong / 519931819）
	const ECHO_AUTH_KEY = "echo_admin_auth";
	const ECHO_AUTH_EXPIRE = 1000 * 60 * 60 * 8;

	let loggedIn = false;
	let loginError = "";
	let loginUser = "";
	let loginPass = "";
	let loginLoading = false;

	// 表单
	let name = "";
	let tagline = "";
	let tagsText = "";
	let manifestoText = "";
	let aboutText = "";
	let avatarUrl = "";
	let freexIntro = "";
	let interests: { en: string; zh: string; desc: string }[] = [];
	let contacts: { name: string; icon: string; url: string; copy: string }[] = [];
	let submitting = false;
	let saveMessage = "";
	let loadError = "";

	function checkAuth() {
		try {
			const raw = localStorage.getItem(ECHO_AUTH_KEY);
			if (!raw) return;
			const data = JSON.parse(raw);
			if (data.authenticated && data.username && data.password && Date.now() - data.timestamp < ECHO_AUTH_EXPIRE) {
				loggedIn = true;
			} else {
				localStorage.removeItem(ECHO_AUTH_KEY);
			}
		} catch {
			localStorage.removeItem(ECHO_AUTH_KEY);
		}
	}

	function getCreds() {
		try {
			const raw = localStorage.getItem(ECHO_AUTH_KEY);
			if (!raw) return null;
			const data = JSON.parse(raw);
			if (data.username && data.password) return { username: data.username, password: data.password };
		} catch {}
		return null;
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
				p_module: "echo",
				p_username: loginUser.trim(),
				p_password: loginPass
			});
			if (error) throw error;
			if (data === true) {
				localStorage.setItem(ECHO_AUTH_KEY, JSON.stringify({
					authenticated: true,
					username: loginUser.trim(),
					password: loginPass,
					timestamp: Date.now()
				}));
				loggedIn = true;
				loadProfile();
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
		localStorage.removeItem(ECHO_AUTH_KEY);
	}

	onMount(() => {
		// 每次进入管理页都要求登录，不自动恢复本地登录态
		loggedIn = false;
	});

	async function loadProfile() {
		loadError = "";
		try {
			const { data, error } = await supabase.rpc("get_site_profile");
			if (error) throw error;
			if (data) {
				name = data.name || "";
				tagline = data.tagline || "";
				tagsText = Array.isArray(data.tags) ? data.tags.join("，") : "";
				manifestoText = Array.isArray(data.manifesto) ? data.manifesto.join("\n") : "";
				aboutText = data.about_text || "";
				avatarUrl = data.avatar_url || "";
				freexIntro = data.freex_intro || "";
				if (Array.isArray(data.interests) && data.interests.length) {
					interests = data.interests.map((it: any) => ({
						en: it.en || "",
						zh: it.zh || "",
						desc: it.desc || ""
					}));
				}
				if (Array.isArray(data.contacts) && data.contacts.length) {
					contacts = data.contacts.map((c: any) => ({
						name: c.name || "",
						icon: c.icon || "",
						url: c.url || "",
						copy: c.copy || ""
					}));
				}
			}
		} catch (e: any) {
			loadError = "加载失败：" + (e?.message || "未知错误");
		}
	}

	async function handleSave() {
		if (submitting) return;
		const creds = getCreds();
		if (!creds) {
			loginError = "请先登录";
			return;
		}
		if (!name.trim()) {
			saveMessage = "昵称不能为空";
			return;
		}
		submitting = true;
		saveMessage = "";
		try {
			const tags = tagsText.split(/[，,\n]/).map((t) => t.trim()).filter(Boolean);
			const manifesto = manifestoText.split(/\n/).map((t) => t.trim()).filter(Boolean);
			const { error } = await supabase.rpc("admin_save_site_profile", {
				p_uid: creds.username,
				p_pwd: creds.password,
				p_name: name.trim(),
				p_tagline: tagline.trim(),
				p_tags: tags,
				p_manifesto: manifesto,
				p_about_text: aboutText,
				p_avatar_url: null,
				p_interests: interests.filter((it) => it.en.trim() || it.zh.trim() || it.desc.trim()),
				p_freex_intro: freexIntro,
				p_contacts: contacts.filter((c) => c.name.trim() && c.url.trim())
			});
			if (error) throw error;
			saveMessage = "✅ 保存成功，刷新关于我页面即可看到更新";
		} catch (e: any) {
			saveMessage = "❌ 保存失败：" + (e?.message || "未知错误");
		} finally {
			submitting = false;
		}
	}
</script>

<div class="profile-admin">
	{#if !loggedIn}
		<div class="login-card">
			<p class="login-title">个人资料管理</p>
			<p class="login-sub">请输入管理员账号密码登录</p>
			<input class="field" type="text" placeholder="账号" bind:value={loginUser} autocomplete="username" />
			<input class="field" type="password" placeholder="密码" bind:value={loginPass} autocomplete="current-password" on:keydown={(e) => e.key === "Enter" && handleLogin()} />
			{#if loginError}<p class="login-error">{loginError}</p>{/if}
			<button class="btn-primary" on:click={handleLogin} disabled={loginLoading}>
				{loginLoading ? "验证中…" : "登 录"}
			</button>
		</div>
	{:else}
		<div class="panel-head">
			<div>
				<p class="login-title">个人资料管理</p>
				<p class="login-sub">修改关于我页面显示的信息</p>
			</div>
			<button class="btn-ghost" on:click={handleLogout}>退出登录</button>
		</div>

		{#if loadError}<p class="login-error">{loadError}</p>{/if}

		<div class="form">
			<label class="row">
				<span class="label">昵称</span>
				<input class="field" type="text" bind:value={name} placeholder="Idong" />
			</label>

			<label class="row">
				<span class="label">副标题（签名行）</span>
				<input class="field" type="text" bind:value={tagline} placeholder="热爱 AI · 追求自由" />
			</label>

			<label class="row">
				<span class="label">身份标签</span>
				<input class="field" type="text" bind:value={tagsText} placeholder="AI 爱好者，足球迷，FreeX 站长" />
				<span class="hint">用逗号或顿号分隔</span>
			</label>

			<label class="row">
				<span class="label">个人宣言</span>
				<textarea class="field area" rows="4" bind:value={manifestoText} placeholder={"你好，我是 Idong。\n一个热爱 AI、追求自由，\n也喜欢记录生活的人。"}></textarea>
				<span class="hint">每行一句，逐行显示</span>
			</label>

			<label class="row">
				<span class="label">关于我正文</span>
				<textarea class="field area" rows="6" bind:value={aboutText} placeholder={"一个热爱 AI、追求自由…\n\n（空行分段）"}></textarea>
				<span class="hint">空行分隔段落；留空则使用默认文案</span>
			</label>

			<label class="row">
				<span class="label">兴趣信号（02 区块，可增删）</span>
				<div class="interests">
					{#each interests as it, i}
						<div class="interest-item">
							<input class="field" type="text" bind:value={it.en} placeholder="英文 AI" />
							<input class="field" type="text" bind:value={it.zh} placeholder="中文 人工智能" />
							<input class="field" type="text" bind:value={it.desc} placeholder="描述：研究模型与工具…" />
							<button class="btn-mini" type="button" on:click={() => interests = interests.filter((_, idx) => idx !== i)}>删除</button>
						</div>
					{/each}
					<button class="btn-ghost" type="button" on:click={() => interests = [...interests, { en: "", zh: "", desc: "" }]}>＋ 添加一条兴趣</button>
				</div>
				<span class="hint">留空的行会自动忽略；顺序即显示顺序</span>
			</label>

			<label class="row">
				<span class="label">关于这个小站正文（03 区块）</span>
				<textarea class="field area" rows="3" bind:value={freexIntro} placeholder="FreeX 不是一个单纯的网站名称…"></textarea>
				<span class="hint">留空则使用默认文案</span>
			</label>

			<label class="row">
				<span class="label">建立连接（SIGNAL 区块，可增删）</span>
				<div class="interests">
					{#each contacts as c, i}
						<div class="interest-item">
							<input class="field" type="text" bind:value={c.name} placeholder="名称：微信" />
							<input class="field" type="text" bind:value={c.icon} placeholder="图标：fa6-brands:weixin" />
							<input class="field" type="text" bind:value={c.url} placeholder="链接：https://… 或 /guestbook/" />
							<input class="field" type="text" bind:value={c.copy} placeholder="点击复制(可空)" />
							<button class="btn-mini" type="button" on:click={() => contacts = contacts.filter((_, idx) => idx !== i)}>删除</button>
						</div>
					{/each}
					<button class="btn-ghost" type="button" on:click={() => contacts = [...contacts, { name: "", icon: "", url: "", copy: "" }]}>＋ 添加一条连接</button>
				</div>
				<span class="hint">名称+链接非空才会显示；图标用图标名（如 fa6-brands:weixin / material-symbols:forum-outline）；留空的复制框则为普通链接</span>
			</label>

			<div class="actions">
				<button class="btn-primary" on:click={handleSave} disabled={submitting}>
					{submitting ? "保存中…" : "保存修改"}
				</button>
				{#if saveMessage}<p class="save-msg">{saveMessage}</p>{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.profile-admin {
		max-width: 640px;
		margin: 0 auto;
		padding: 2rem 1.25rem 4rem;
		color: #d8dce7;
	}
	.login-card {
		margin-top: 3rem;
		padding: 2rem 1.5rem;
		border: 1px solid rgba(155, 140, 255, 0.18);
		border-radius: 1rem;
		background: rgba(155, 140, 255, 0.04);
		display: flex;
		flex-direction: column;
		gap: 0.8rem;
	}
	.login-title {
		margin: 0;
		font-size: 1.3rem;
		font-weight: 600;
		color: #f4f5fa;
	}
	.login-sub {
		margin: 0;
		font-size: 0.82rem;
		color: rgba(255, 255, 255, 0.45);
	}
	.field {
		width: 100%;
		padding: 0.7rem 0.85rem;
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 0.6rem;
		background: rgba(255, 255, 255, 0.03);
		color: #e6edf3;
		font-size: 0.92rem;
		outline: none;
		box-sizing: border-box;
	}
	.field:focus {
		border-color: rgba(155, 140, 255, 0.5);
	}
	textarea.field {
		resize: vertical;
		line-height: 1.6;
	}
	.login-error {
		margin: 0;
		color: #ff8a8a;
		font-size: 0.82rem;
	}
	.btn-primary {
		padding: 0.7rem 1.2rem;
		border: none;
		border-radius: 0.6rem;
		background: linear-gradient(135deg, #9b8cff, #63d8ff);
		color: #0a0d18;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
	}
	.btn-primary:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.btn-ghost {
		padding: 0.5rem 0.9rem;
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 0.6rem;
		background: transparent;
		color: rgba(255, 255, 255, 0.7);
		cursor: pointer;
		font-size: 0.82rem;
	}
	.panel-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin: 1rem 0 1.5rem;
	}
	.form {
		display: flex;
		flex-direction: column;
		gap: 1.1rem;
	}
	.row {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}
	.label {
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.75);
	}
	.hint {
		font-size: 0.72rem;
		color: rgba(255, 255, 255, 0.35);
	}
	.actions {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-top: 0.5rem;
	}
	.save-msg {
		margin: 0;
		font-size: 0.82rem;
		color: #8ee6a8;
	}
	.interests {
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
	}
	.interest-item {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
	}
	.interest-item .field {
		font-size: 0.82rem;
		padding: 0.55rem 0.7rem;
	}
	.interest-item .btn-mini {
		grid-column: 1 / -1;
		justify-self: start;
		padding: 0.3rem 0.7rem;
		font-size: 0.75rem;
		color: #ff9b9b;
		background: transparent;
		border: 1px solid rgba(255, 155, 155, 0.25);
		border-radius: 0.5rem;
		cursor: pointer;
	}
</style>
