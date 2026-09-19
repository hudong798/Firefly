<script lang="ts">
	import { onMount } from "svelte";
	import { marked } from "marked";
	import { supabase } from "@/lib/supabase";

	interface EchoDetail {
		id: string;
		slug: string;
		title: string;
		content: string | null;
		mood: string | null;
		tags: string[] | null;
		status: string;
		created_at: string;
		is_locked: boolean;
		has_image: boolean;
	}

	let echo: EchoDetail | null = null;
	let loading = true;
	let error = "";

	// 上锁解锁
	let lockInput = "";
	let lockError = "";
	let unlockedContent = "";
	let verifying = false;
	let slug = "";

	function renderMarkdown(content: string): string {
		return marked.parse(content ?? "", { async: false, breaks: true, gfm: true }) as string;
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		if (isNaN(d.getTime())) return dateStr.split(" ")[0];
		const y = d.getFullYear();
		const m = String(d.getMonth() + 1).padStart(2, "0");
		const day = String(d.getDate()).padStart(2, "0");
		return `${y}.${m}.${day}`;
	}

	function formatTime(dateStr: string): string {
		const d = new Date(dateStr);
		return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
	}

	function isNight(dateStr: string): boolean {
		const d = new Date(dateStr);
		const hour = d.getHours();
		return hour < 6 || hour >= 18;
	}

	async function verifyLock() {
		if (!echo || !supabase || verifying) return;
		const pwd = lockInput.trim();
		if (!pwd) {
			lockError = "请输入解锁密码";
			return;
		}
		verifying = true;
		lockError = "";
		try {
			const { data, error: err } = await supabase.rpc("unlock_echo", {
				p_echo_id: echo.id,
				p_password: pwd
			});
			if (err) throw err;
			if (data) {
				unlockedContent = data as string;
			} else {
				lockError = "密码错误，请重试";
			}
		} catch (e: any) {
			lockError = "解锁失败：" + (e?.message || "");
		} finally {
			verifying = false;
		}
	}

	onMount(async () => {
		if (!supabase) {
			loading = false;
			error = "Supabase 未配置";
			return;
		}
		const params = new URLSearchParams(window.location.search);
		slug = params.get("slug") || "";
		if (!slug) {
			loading = false;
			error = "缺少说说标识";
			return;
		}
		try {
			const { data, error: err } = await supabase
				.rpc("get_echo_detail", { p_slug: slug });
			if (err) throw err;
			const rows = (data as EchoDetail[]) || [];
			if (rows.length === 0) {
				error = "这条说说不存在或已下架";
			} else {
				echo = rows[0];
			}
		} catch (e: any) {
			error = e?.message || "加载失败";
		} finally {
			loading = false;
		}
	});
</script>

<div class="client-echo-detail">
	{#if loading}
		<div class="ed-loading">
			<div class="ed-spinner"></div>
			<span>正在接收回声信号...</span>
		</div>
	{:else if error}
		<div class="ed-error">
			<p>{error}</p>
			<a class="ed-back" href="/thoughts/">← 返回说说列表</a>
		</div>
	{:else if echo}
		<a class="ed-back" href="/thoughts/">← 返回说说</a>

		<article class="ed-card">
			<div class="ed-meta">
				<span class="ed-number">ECHO DETAIL</span>
				<span class="ed-date">{formatDate(echo.created_at)}</span>
				<span class="ed-time">
					{#if isNight(echo.created_at)}<span class="ed-night">☾</span>{/if}
					{formatTime(echo.created_at)}
				</span>
			</div>

			<div class="ed-body">
				{#if echo.mood}
					<div class="ed-mood">{echo.mood}</div>
				{/if}
				<h1 class="ed-title">{echo.title}</h1>

				<div class="ed-content">
					{#if echo.is_locked && !unlockedContent}
						<div class="ed-locked-box">
							<p class="ed-locked-tip">🔒 这条说说已上锁，输入密码查看正文</p>
							<div class="ed-lock-form">
								<input
									type="password"
									placeholder="解锁密码"
									bind:value={lockInput}
									on:keydown={(e) => e.key === "Enter" && verifyLock()}
								/>
								<button class="ed-unlock-btn" on:click={verifyLock} disabled={verifying}>
									{#if verifying}验证中...{:else}解锁{/if}
								</button>
							</div>
							{#if lockError}
								<p class="ed-lock-error">{lockError}</p>
							{/if}
						</div>
					{:else if echo.is_locked && unlockedContent}
						<div class="ed-md">{@html renderMarkdown(unlockedContent)}</div>
					{:else}
						<div class="ed-md">{@html renderMarkdown(echo.content || "")}</div>
					{/if}
				</div>

				{#if echo.tags && echo.tags.length > 0}
					<div class="ed-tags">
						{#each echo.tags as tag}
							<span class="ed-tag">#{tag}</span>
						{/each}
					</div>
				{/if}
			</div>
		</article>
	{/if}
</div>

<style>
	.client-echo-detail {
		position: relative;
		z-index: 2;
		max-width: 1000px;
		margin: 0 auto;
		padding: 0 1.5rem;
		padding-top: 1rem;
	}

	.ed-loading,
	.ed-error {
		padding: 4rem 0;
		text-align: center;
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.9rem;
	}

	.ed-spinner {
		width: 28px;
		height: 28px;
		margin: 0 auto 1rem;
		border: 2px solid rgba(155, 140, 255, 0.2);
		border-top-color: rgba(155, 140, 255, 0.8);
		border-radius: 50%;
		animation: ed-spin 0.8s linear infinite;
	}

	@keyframes ed-spin {
		to { transform: rotate(360deg); }
	}

	.ed-back {
		display: inline-block;
		margin-bottom: 1.5rem;
		font-size: 0.78rem;
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
		color: rgba(255, 255, 255, 0.4);
		text-decoration: none;
		transition: color 0.2s ease, transform 0.2s ease;
	}

	.ed-back:hover {
		color: rgba(155, 140, 255, 0.9);
		transform: translateX(-3px);
	}

	.ed-card {
		display: grid;
		grid-template-columns: 160px 1fr;
		gap: 3rem;
		padding: 3rem;
		background: linear-gradient(160deg, rgba(30, 32, 54, 0.72), rgba(16, 18, 32, 0.78));
		border: 1px solid rgba(155, 140, 255, 0.28);
		border-radius: 1.25rem;
		backdrop-filter: blur(18px) saturate(1.3);
		-webkit-backdrop-filter: blur(18px) saturate(1.3);
		box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45), 0 0 24px rgba(155, 140, 255, 0.08), inset 0 1px 0 rgba(255, 255, 255, 0.06);
		animation: ed-in 0.5s ease-out both;
	}

	@keyframes ed-in {
		from { opacity: 0; transform: translateY(10px); }
		to { opacity: 1; transform: translateY(0); }
	}

	.ed-meta {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
	}

	.ed-number {
		font-size: 0.65rem;
		letter-spacing: 0.12em;
		color: rgba(255, 255, 255, 0.35);
		text-transform: uppercase;
	}

	.ed-date {
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.5);
	}

	.ed-time {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.35);
	}

	.ed-night {
		opacity: 0.7;
		margin-right: 0.3rem;
	}

	.ed-body {
		min-width: 0;
		max-width: 720px;
	}

	.ed-mood {
		font-size: 1.3rem;
		margin-bottom: 0.75rem;
		line-height: 1;
	}

	.ed-title {
		margin: 0 0 1.5rem 0;
		font-size: 1.75rem;
		font-weight: 600;
		color: #F4F5FA;
		line-height: 1.3;
	}

	.ed-content {
		font-size: 1.05rem;
		line-height: 2;
		color: #D8DCE7;
		word-break: break-word;
	}

	.ed-md :global(p) {
		margin: 0 0 1rem 0;
	}

	.ed-md :global(img) {
		max-width: 100%;
		height: auto;
		border-radius: 0.75rem;
		margin: 1rem 0;
		display: block;
	}

	.ed-md :global(a) {
		color: rgba(155, 140, 255, 0.9);
	}

	.ed-md :global(blockquote) {
		border-left: 2px solid rgba(155, 140, 255, 0.4);
		padding-left: 1rem;
		color: rgba(255, 255, 255, 0.6);
	}

	.ed-md :global(code) {
		background: rgba(155, 140, 255, 0.1);
		padding: 0.1rem 0.35rem;
		border-radius: 4px;
		font-size: 0.9em;
	}

	.ed-locked-box {
		padding: 2rem;
		background: rgba(155, 140, 255, 0.05);
		border: 1px dashed rgba(155, 140, 255, 0.25);
		border-radius: 0.75rem;
		text-align: center;
	}

	.ed-locked-tip {
		margin: 0 0 1rem 0;
		color: rgba(255, 255, 255, 0.7);
		font-size: 0.95rem;
	}

	.ed-lock-form {
		display: flex;
		gap: 0.75rem;
		justify-content: center;
		flex-wrap: wrap;
	}

	.ed-lock-form input {
		padding: 0.5rem 0.9rem;
		background: rgba(0, 0, 0, 0.25);
		border: 1px solid rgba(155, 140, 255, 0.3);
		border-radius: 6px;
		color: #fff;
		font-size: 0.9rem;
		outline: none;
	}

	.ed-lock-form input:focus {
		border-color: rgba(155, 140, 255, 0.7);
	}

	.ed-unlock-btn {
		padding: 0.5rem 1.2rem;
		background: rgba(155, 140, 255, 0.2);
		border: 1px solid rgba(155, 140, 255, 0.4);
		border-radius: 6px;
		color: #fff;
		font-size: 0.9rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.ed-unlock-btn:hover {
		background: rgba(155, 140, 255, 0.35);
	}

	.ed-lock-error {
		margin: 0.75rem 0 0 0;
		color: rgba(255, 120, 120, 0.9);
		font-size: 0.85rem;
	}

	.ed-tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75rem;
		margin-top: 1.5rem;
	}

	.ed-tag {
		font-size: 0.8rem;
		color: rgba(155, 140, 255, 0.7);
		background: rgba(155, 140, 255, 0.08);
		padding: 0.25rem 0.6rem;
		border-radius: 4px;
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
	}

	@media (max-width: 768px) {
		.client-echo-detail {
			padding: 0 1.25rem;
		}
		.ed-card {
			grid-template-columns: 1fr;
			gap: 1rem;
			padding: 1.5rem;
		}
		.ed-meta {
			flex-direction: row;
			align-items: center;
			gap: 0.75rem;
			flex-wrap: wrap;
		}
		.ed-title {
			font-size: 1.35rem;
		}
		.ed-content {
			font-size: 0.95rem;
			line-height: 1.9;
		}
	}
</style>
