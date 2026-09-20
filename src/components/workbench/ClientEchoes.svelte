<script lang="ts">
	import { onMount } from "svelte";
	import { marked } from "marked";
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
		is_locked: boolean;
		has_image: boolean;
	}

	let echoes: Echo[] = [];
	let loading = true;
	let error = "";
	let expandedSlug: string | null = null;

	// 上锁说说：解锁后从 RPC 取回的正文；解锁输入与错误提示
	let unlockedContent: Record<string, string> = {};
	let lockInput: Record<string, string> = {};
	let lockError: Record<string, string> = {};
	let verifyingLock: Record<string, boolean> = {};

	const MOMENT_PREVIEW_LIMIT = 50;

	// 去除 Markdown 语法，提取纯文本用于预览
	function plainTextOf(markdown: string): string {
		const md = markdown || "";
		return md
			.replace(/!\[[^\]]*\]\([^)]*\)/g, "") // 图片
			.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1") // 链接保留文字
			.replace(/^#{1,6}\s+/gm, "") // 标题符号
			.replace(/\*\*?([^*]+)\*\*?/g, "$1") // 加粗/斜体
			.replace(/`([^`]+)`/g, "$1") // 行内代码
			.replace(/^>\s?/gm, "") // 引用
			.replace(/^[-*+]\s+/gm, "") // 无序列表
			.replace(/^\d+\.\s+/gm, "") // 有序列表
			.replace(/\|/g, " ") // 表格
			.replace(/^={3,}|-{3,}|_{3,}$/gm, "") // 分隔线
			.replace(/\n{2,}/g, "\n")
			.trim();
	}

	function previewOf(content: string) {
		const plain = plainTextOf(content);
		const isLong = plain.length > MOMENT_PREVIEW_LIMIT;
		return {
			isLong,
			text: isLong ? plain.slice(0, MOMENT_PREVIEW_LIMIT) + "…" : plain,
		};
	}

	// 渲染 Markdown 为 HTML（breaks 保留单换行，兼容纯文本说说）
	function renderMarkdown(content: string): string {
		return marked.parse(content ?? "", { async: false, breaks: true, gfm: true }) as string;
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
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

	function toggleExpand(slug: string) {
		expandedSlug = expandedSlug === slug ? null : slug;
	}

	// 解锁上锁说说：调用数据库端 RPC 校验密码，通过才拿回正文
	async function verifyLock(echo: Echo) {
		if (!supabase || verifyingLock[echo.slug]) return;
		const pwd = (lockInput[echo.slug] || "").trim();
		if (!pwd) {
			lockError = { ...lockError, [echo.slug]: "请输入解锁密码" };
			return;
		}
		verifyingLock = { ...verifyingLock, [echo.slug]: true };
		lockError = { ...lockError, [echo.slug]: "" };
		try {
			const { data, error: err } = await supabase.rpc("unlock_echo", {
				p_echo_id: echo.id,
				p_password: pwd
			});
			if (err) throw err;
			if (data) {
				unlockedContent = { ...unlockedContent, [echo.slug]: data as string };
				expandedSlug = echo.slug;
			} else {
				lockError = { ...lockError, [echo.slug]: "密码错误，请重试" };
			}
		} catch (e: any) {
			lockError = { ...lockError, [echo.slug]: "解锁失败：" + (e?.message || "") };
		} finally {
			verifyingLock = { ...verifyingLock, [echo.slug]: false };
		}
	}

	onMount(async () => {
		if (!supabase) {
			loading = false;
			error = "Supabase 未配置";
			return;
		}

		try {
			const { data, error: err } = await supabase
				.rpc("list_public_echoes");

			if (err) throw err;
			echoes = (data as Echo[]) || [];

			// 检查 URL 参数中是否有 slug，有则自动展开
			if (typeof window !== "undefined") {
				const params = new URLSearchParams(window.location.search);
				const slugParam = params.get("slug");
				if (slugParam && echoes.some((e) => e.slug === slugParam)) {
					expandedSlug = slugParam;
					// 滚动到对应位置
					setTimeout(() => {
						const el = document.querySelector(`[data-slug="${CSS.escape(slugParam)}"]`);
						if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
					}, 100);
				}
			}
		} catch (e: any) {
			error = e?.message || "加载失败";
		} finally {
			loading = false;
		}
	});
</script>

<div class="client-echoes">
	{#if loading}
		<div class="echo-loading">
			<div class="echo-spinner"></div>
			<span>正在接收说说信号...</span>
		</div>
	{:else if error && echoes.length === 0}
		<div class="echo-error">
			<p>信号接收失败：{error}</p>
			<p class="echo-error-hint">请检查 Supabase 配置或网络连接</p>
		</div>
	{:else if echoes.length === 0}
		<div class="echo-empty">
			<div class="echo-empty-icon">✦</div>
			<p>宇宙中还没有说说</p>
			<p class="echo-empty-hint">点击右上角「写说说」发布第一条</p>
		</div>
	{:else}
		<div class="echoes">
			{#each echoes as echo, index (echo.id)}
				{@const p = previewOf(echo.content)}
				{@const echoNum = String(echoes.length - index).padStart(3, "0")}
				{@const night = isNight(echo.created_at)}
				{@const isExpanded = expandedSlug === echo.slug}

				<article
					class="echo"
					class:echo-expanded={isExpanded}
					data-slug={echo.slug}
					style={`--echo-index: ${index};`}
				>
					<!-- 左侧：Echo 编号 + 时间坐标 -->
					<div class="echo-meta">
						<span class="echo-number">ECHO / {echoNum}</span>
						<span class="echo-date">{formatDate(echo.created_at)}</span>
						<span class="echo-time">{formatTime(echo.created_at)}</span>
						{#if night}
							<span class="echo-night-badge">深夜</span>
						{/if}
					</div>

					<!-- 右侧：内容主体 -->
					<div class="echo-body">
						<h3 class="echo-title">{echo.title}{#if echo.mood}<span class="echo-mood">{echo.mood}</span>{/if}</h3>

						<div class="echo-content">
							{#if echo.is_locked}
								<p class="echo-hasimage-tip">🔒 这条说说已上锁，点击查看详情解锁</p>
							{:else if echo.has_image}
								<p class="echo-hasimage-tip">📷 这条说说包含图片，点击查看详情</p>
							{:else if p.isLong}
								<p>{p.text}</p>
							{:else}
								<div class="echo-md">{@html renderMarkdown(echo.content)}</div>
							{/if}
						</div>

						{#if echo.is_locked || echo.has_image || p.isLong}
							<a class="echo-expand-btn" href={"/thoughts/view/?slug=" + encodeURIComponent(echo.slug)}>查看详情 ↓</a>
						{/if}

						{#if echo.tags && echo.tags.length > 0}
							<div class="echo-tags">
								{#each echo.tags as tag}
									<span class="echo-tag">#{tag}</span>
								{/each}
							</div>
						{/if}
					</div>

					<!-- 底部装饰线 -->
					<div class="echo-divider" aria-hidden="true"></div>
				</article>
			{/each}
		</div>
	{/if}
</div>

<style>
	.client-echoes {
		font-family: inherit;
	}

	/* 加载状态 */
	.echo-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		padding: 4rem 2rem;
		color: rgba(255, 255, 255, 0.4);
		font-size: 0.85rem;
		letter-spacing: 0.05em;
	}

	.echo-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(155, 140, 255, 0.2);
		border-top-color: rgba(155, 140, 255, 0.8);
		border-radius: 50%;
		animation: echo-spin 0.8s linear infinite;
	}

	@keyframes echo-spin {
		to { transform: rotate(360deg); }
	}

	/* 错误状态 */
	.echo-error {
		text-align: center;
		padding: 3rem 2rem;
		color: rgba(248, 113, 113, 0.8);
		font-size: 0.9rem;
	}

	.echo-error-hint {
		color: rgba(255, 255, 255, 0.3);
		font-size: 0.8rem;
		margin-top: 0.5rem;
	}

	/* 空状态 */
	.echo-empty {
		text-align: center;
		padding: 4rem 2rem;
		color: rgba(255, 255, 255, 0.35);
	}

	.echo-empty-icon {
		font-size: 2rem;
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.echo-empty p {
		margin: 0.25rem 0;
		font-size: 0.9rem;
	}

	.echo-empty-hint {
		font-size: 0.8rem !important;
		opacity: 0.6;
	}

	/* 回声列表 */
	.echoes {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.echo {
		position: relative;
		display: grid;
		grid-template-columns: 140px 1fr;
		gap: 2rem;
		padding: 1.5rem;
		background: rgba(155, 140, 255, 0.06);
		border: 1px solid rgba(155, 140, 255, 0.12);
		border-radius: 0.75rem;
		backdrop-filter: blur(8px);
		animation: echo-fade-in 0.6s ease-out both;
		animation-delay: calc(var(--echo-index, 0) * 0.08s);
		transition: all 0.25s ease;
	}

	.echo:hover {
		background: rgba(155, 140, 255, 0.09);
		border-color: rgba(155, 140, 255, 0.2);
		transform: translateY(-2px);
	}

	@keyframes echo-fade-in {
		from {
			opacity: 0;
			transform: translateY(12px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.echo-expanded {
		background: rgba(155, 140, 255, 0.1);
		border-color: rgba(155, 140, 255, 0.25);
	}

	/* 左侧元信息 */
	.echo-meta {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
		padding-top: 0.25rem;
	}

	.echo-number {
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
		font-size: 0.6rem;
		letter-spacing: 0.15em;
		color: rgba(155, 140, 255, 0.5);
		text-transform: uppercase;
	}

	.echo-date {
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.45);
		letter-spacing: 0.02em;
	}

	.echo-time {
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
		font-size: 0.7rem;
		color: rgba(255, 255, 255, 0.3);
	}

	.echo-night-badge {
		display: inline-block;
		width: fit-content;
		font-size: 0.6rem;
		padding: 0.15rem 0.4rem;
		border-radius: 4px;
		background: rgba(99, 102, 241, 0.1);
		color: rgba(155, 140, 255, 0.7);
		letter-spacing: 0.1em;
		margin-top: 0.25rem;
	}

	/* 右侧内容 */
	.echo-body {
		min-width: 0;
	}

	.echo-mood {
		display: inline-block;
		margin-left: 0.5rem;
		font-size: 1.15rem;
		line-height: 1;
		vertical-align: middle;
	}

	.echo-title {
		font-size: 1.1rem;
		font-weight: 600;
		color: #6FC3FF;
		margin: 0 0 0.75rem 0;
		line-height: 1.4;
	}

	.echo-content {
		font-size: 0.95rem;
		line-height: 1.9;
		color: rgba(255, 255, 255, 0.75);
		white-space: pre-wrap;
		word-break: break-word;
	}

	/* Markdown 渲染内容 */
	.echo-md {
		font-size: 0.95rem;
		line-height: 1.9;
		color: rgba(255, 255, 255, 0.78);
		word-break: break-word;
	}

	.echo-md :global(p) {
		margin: 0.6em 0;
	}

	.echo-md :global(p:first-child) {
		margin-top: 0;
	}

	.echo-md :global(p:last-child) {
		margin-bottom: 0;
	}

	.echo-md :global(h1),
	.echo-md :global(h2),
	.echo-md :global(h3),
	.echo-md :global(h4) {
		color: #f4f5fa;
		font-weight: 600;
		line-height: 1.4;
		margin: 1em 0 0.5em;
	}

	.echo-md :global(h1) { font-size: 1.25rem; }
	.echo-md :global(h2) { font-size: 1.15rem; }
	.echo-md :global(h3) { font-size: 1.05rem; }
	.echo-md :global(h4) { font-size: 1rem; }

	.echo-md :global(ul),
	.echo-md :global(ol) {
		margin: 0.6em 0;
		padding-left: 1.4em;
	}

	.echo-md :global(li) {
		margin: 0.25em 0;
	}

	.echo-md :global(li::marker) {
		color: rgba(155, 140, 255, 0.7);
	}

	.echo-md :global(blockquote) {
		margin: 0.8em 0;
		padding: 0.4em 1em;
		border-left: 3px solid rgba(155, 140, 255, 0.4);
		background: rgba(155, 140, 255, 0.06);
		border-radius: 0 6px 6px 0;
		color: rgba(255, 255, 255, 0.65);
	}

	.echo-md :global(blockquote p) {
		margin: 0.3em 0;
	}

	.echo-md :global(code) {
		font-size: 0.85em;
		background: rgba(155, 140, 255, 0.1);
		color: #b8adff;
		padding: 0.12em 0.4em;
		border-radius: 4px;
		font-family: "JetBrains Mono", "Fira Code", ui-monospace, monospace;
	}

	.echo-md :global(pre) {
		background: rgba(15, 23, 42, 0.7);
		border: 1px solid rgba(155, 140, 255, 0.15);
		border-radius: 8px;
		padding: 0.9em 1em;
		overflow-x: auto;
		margin: 0.8em 0;
	}

	.echo-md :global(pre code) {
		background: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
	}

	.echo-md :global(a) {
		color: rgba(155, 140, 255, 0.9);
		text-decoration: underline;
		text-underline-offset: 3px;
		text-decoration-thickness: 1px;
	}

	.echo-md :global(a:hover) {
		color: #b8adff;
	}

	.echo-md :global(hr) {
		border: none;
		border-top: 1px solid rgba(155, 140, 255, 0.2);
		margin: 1.2em 0;
	}

	.echo-md :global(strong) {
		color: #f4f5fa;
		font-weight: 600;
	}

	/* 正文图片：桌面端 */
	.echo-md :global(img) {
		max-width: 100%;
		max-height: 320px;
		width: auto;
		height: auto;
		object-fit: contain;
		border-radius: 10px;
		margin: 1em auto;
		display: block;
		border: 1px solid rgba(155, 140, 255, 0.15);
	}

	.echo-expand-btn {
		margin-top: 0.75rem;
		padding: 0.3rem 0.75rem;
		background: rgba(155, 140, 255, 0.08);
		border: 1px solid rgba(155, 140, 255, 0.15);
		border-radius: 6px;
		color: rgba(155, 140, 255, 0.8);
		font-size: 0.75rem;
		cursor: pointer;
		transition: all 0.2s;
		font-family: inherit;
	}

	.echo-expand-btn:hover {
		background: rgba(155, 140, 255, 0.15);
		color: rgba(155, 140, 255, 1);
	}

	/* 上锁说说 */
	.echo-locked-box {
		padding: 0.9rem 1rem;
		background: rgba(15, 23, 42, 0.5);
		border: 1px solid rgba(155, 140, 255, 0.18);
		border-radius: 10px;
	}

	.echo-locked-tip {
		margin: 0 0 0.6rem 0;
		font-size: 0.85rem;
		color: rgba(155, 140, 255, 0.85);
	}

	.echo-lock-form {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		align-items: center;
	}

	.echo-lock-form input {
		flex: 1;
		min-width: 140px;
		padding: 0.45rem 0.7rem;
		background: rgba(30, 41, 59, 0.8);
		border: 1px solid rgba(148, 163, 184, 0.25);
		border-radius: 6px;
		color: #f1f5f9;
		font-size: 0.85rem;
		font-family: inherit;
	}

	.echo-lock-form input:focus {
		outline: none;
		border-color: #6366f1;
	}

	.echo-lock-error {
		margin: 0.5rem 0 0;
		font-size: 0.78rem;
		color: #f87171;
	}

	.echo-hasimage-tip {
		margin: 0;
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.5);
	}

	.echo-tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-top: 1rem;
	}

	.echo-tag {
		font-size: 0.7rem;
		color: rgba(155, 140, 255, 0.6);
		background: rgba(155, 140, 255, 0.05);
		padding: 0.2rem 0.5rem;
		border-radius: 4px;
		letter-spacing: 0.02em;
	}

	/* 底部分隔线（卡片模式下隐藏） */
	.echo-divider {
		display: none;
	}

	/* 响应式 */
	@media (max-width: 768px) {
		.echo {
			grid-template-columns: 1fr;
			gap: 1rem;
			padding: 1.25rem;
		}

		.echo-meta {
			flex-direction: row;
			align-items: center;
			gap: 0.75rem;
			flex-wrap: wrap;
		}

		.echo-night-badge {
			margin-top: 0;
		}

		.echo-content {
			font-size: 0.9rem;
		}

		.echo-md {
			font-size: 0.9rem;
		}

		/* 正文图片：移动端，避免过大 */
		.echo-md :global(img) {
			max-height: 220px;
			margin: 0.8em auto;
			border-radius: 8px;
		}
	}
</style>
