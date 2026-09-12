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

	let echoes: Echo[] = [];
	let loading = true;
	let error = "";
	let expandedSlug: string | null = null;

	const MOMENT_PREVIEW_LIMIT = 200;

	function previewOf(content: string) {
		const isLong = content.length > MOMENT_PREVIEW_LIMIT;
		return {
			isLong,
			text: isLong ? content.slice(0, MOMENT_PREVIEW_LIMIT) + "…" : content,
		};
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

	onMount(async () => {
		if (!supabase) {
			loading = false;
			error = "Supabase 未配置";
			return;
		}

		try {
			const { data, error: err } = await supabase
				.from("echoes")
				.select("*")
				.eq("status", "published")
				.order("created_at", { ascending: false })
				.limit(100);

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
			<span>正在接收回声信号...</span>
		</div>
	{:else if error && echoes.length === 0}
		<div class="echo-error">
			<p>信号接收失败：{error}</p>
			<p class="echo-error-hint">请检查 Supabase 配置或网络连接</p>
		</div>
	{:else if echoes.length === 0}
		<div class="echo-empty">
			<div class="echo-empty-icon">✦</div>
			<p>宇宙中还没有回声</p>
			<p class="echo-empty-hint">点击右上角「写回声」发布第一条</p>
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
						{#if echo.mood}
							<div class="echo-mood">{echo.mood}</div>
						{/if}

						{#if echo.title && echo.title !== echo.content.slice(0, echo.title.length)}
							<h3 class="echo-title">{echo.title}</h3>
						{/if}

						<div class="echo-content">
							{#if isExpanded || !p.isLong}
								{echo.content}
							{:else}
								{p.text}
							{/if}
						</div>

						{#if p.isLong}
							<button class="echo-expand-btn" on:click={() => toggleExpand(echo.slug)}>
								{#if isExpanded}收起 ↑{:else}展开全文 ↓{/if}
							</button>
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
		font-size: 1.3rem;
		margin-bottom: 0.75rem;
		line-height: 1;
	}

	.echo-title {
		font-size: 1.1rem;
		font-weight: 600;
		color: #F4F5FA;
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
	}
</style>
