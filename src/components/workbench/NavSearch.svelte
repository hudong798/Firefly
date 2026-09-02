<script lang="ts">
	// 导航栏实时搜索：点击放大镜展开输入框，输入即弹出匹配结果，点击跳转（不跳搜索页）
	import { navigateToPage } from "@utils/navigation-utils";

	interface IndexItem {
		id: string;
		section: string;
		sectionLabel: string;
		title: string;
		snippet: string;
		tags: string[];
		url: string;
		external: boolean;
		search: string;
	}

	let open = $state(false);
	let keyword = $state("");
	let activeIdx = $state(-1);
	let loading = $state(false);

	let allItems: IndexItem[] = [];
	let loaded = false;

	let inputEl = $state<HTMLInputElement>();

	// 本地实时过滤（索引已全量加载，无需防抖）
	const results = $derived.by(() => {
		const q = keyword.trim().toLowerCase();
		if (!q) return [];
		const matched = allItems.filter(
			(it) => it.search.includes(q) || it.title.toLowerCase().includes(q),
		);
		// 标题命中优先
		matched.sort((a, b) => {
			const at = a.title.toLowerCase().includes(q) ? 0 : 1;
			const bt = b.title.toLowerCase().includes(q) ? 0 : 1;
			return at - bt;
		});
		return matched.slice(0, 8);
	});

	async function loadIndex() {
		if (loaded || loading) return;
		loading = true;
		try {
			const res = await fetch("/api/search-index.json");
			if (res.ok) {
				allItems = (await res.json()) as IndexItem[];
				loaded = true;
			}
		} catch (err) {
			console.error("加载搜索索引失败:", err);
		} finally {
			loading = false;
		}
	}

	async function togglePanel() {
		open = !open;
		if (open) {
			await loadIndex();
			requestAnimationFrame(() => inputEl?.focus());
		} else {
			closePanel();
		}
	}

	function closePanel() {
		open = false;
		keyword = "";
		activeIdx = -1;
	}

	function go(item: IndexItem) {
		navigateToPage(item.url);
		closePanel();
	}

	function onKeydown(e: KeyboardEvent) {
		if (e.key === "Escape") {
			e.preventDefault();
			closePanel();
			return;
		}
		if (results.length === 0) return;
		if (e.key === "ArrowDown") {
			e.preventDefault();
			activeIdx = (activeIdx + 1) % results.length;
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			activeIdx = (activeIdx - 1 + results.length) % results.length;
		} else if (e.key === "Enter") {
			e.preventDefault();
			const target = results[activeIdx >= 0 ? activeIdx : 0];
			if (target) go(target);
		}
	}

	// 关键词高亮（先转义再替换，避免 XSS）
	function escapeHtml(s: string): string {
		return s
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}
	function highlight(text: string): string {
		const q = keyword.trim();
		const safe = escapeHtml(text || "");
		if (!q) return safe;
		const qSafe = escapeHtml(q).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
		return safe.replace(new RegExp(`(${qSafe})`, "gi"), "<mark>$1</mark>");
	}
</script>

<div class="nav-search">
	<button
		type="button"
		class="nav-search__btn"
		aria-label="搜索"
		aria-expanded={open}
		onclick={togglePanel}
	>
		<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
			<circle cx="11" cy="11" r="8"></circle>
			<line x1="21" y1="21" x2="16.65" y2="16.65"></line>
		</svg>
	</button>

	{#if open}
		<button
			type="button"
			class="nav-search__overlay"
			aria-label="关闭搜索"
			tabindex="-1"
			onclick={closePanel}
		></button>
		<div class="nav-search__panel" role="dialog" aria-label="站内搜索">
			<div class="nav-search__input-wrap">
				<svg class="nav-search__input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="11" cy="11" r="8"></circle>
					<line x1="21" y1="21" x2="16.65" y2="16.65"></line>
				</svg>
				<input
					bind:this={inputEl}
					bind:value={keyword}
					type="text"
					class="nav-search__input"
					placeholder="搜索文章、工具、资源…"
					onkeydown={onKeydown}
					autocomplete="off"
				/>
				{#if keyword}
					<button type="button" class="nav-search__clear" aria-label="清空" onclick={() => (keyword = "")}>
						✕
					</button>
				{/if}
			</div>

			<div class="nav-search__results">
				{#if loading}
					<div class="nav-search__hint">正在加载索引…</div>
				{:else if !keyword.trim()}
					<div class="nav-search__hint">输入关键词，实时搜索全站内容</div>
				{:else if results.length === 0}
					<div class="nav-search__hint">没有找到「{keyword}」相关内容</div>
				{:else}
					{#each results as item, i (item.id)}
						<button
							type="button"
							class="nav-search__item"
							class:active={i === activeIdx}
							onclick={() => go(item)}
							onmouseenter={() => (activeIdx = i)}
						>
							<span class="nav-search__tag">{item.sectionLabel}</span>
							<span class="nav-search__body">
								<span class="nav-search__title">{@html highlight(item.title)}</span>
								{#if item.snippet}
									<span class="nav-search__snippet">{@html highlight(item.snippet.slice(0, 60))}</span>
								{/if}
							</span>
							{#if item.external}
								<span class="nav-search__ext">↗</span>
							{/if}
						</button>
					{/each}
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.nav-search {
		position: relative;
		flex-shrink: 0;
	}

	.nav-search__btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 38px;
		height: 38px;
		border-radius: 50%;
		color: rgb(255 200 170 / 0.8);
		background: rgb(255 140 100 / 0.08);
		border: 1px solid rgb(255 160 120 / 0.2);
		cursor: pointer;
		transition: all 0.2s ease;
	}
	.nav-search__btn:hover,
	.nav-search__btn[aria-expanded="true"] {
		color: rgb(255 220 190 / 1);
		background: rgb(255 140 100 / 0.18);
		border-color: rgb(255 160 120 / 0.45);
		transform: scale(1.05);
	}
	.nav-search__btn svg {
		width: 18px;
		height: 18px;
	}

	.nav-search__overlay {
		position: fixed;
		inset: 0;
		z-index: 999;
		width: 100%;
		height: 100%;
		border: none;
		padding: 0;
		background: transparent;
		cursor: default;
	}

	.nav-search__panel {
		position: absolute;
		top: calc(100% + 0.6rem);
		right: 0;
		width: min(26rem, 90vw);
		z-index: 1000;
		border-radius: 1rem;
		overflow: hidden;
		background: rgb(28 17 12 / 0.92);
		backdrop-filter: blur(24px) saturate(150%);
		-webkit-backdrop-filter: blur(24px) saturate(150%);
		border: 1px solid rgb(255 160 120 / 0.25);
		box-shadow: 0 18px 50px rgb(0 0 0 / 0.5), inset 0 1px 0 rgb(255 200 170 / 0.12);
		animation: nav-search-pop 0.16s ease;
	}
	@keyframes nav-search-pop {
		from {
			opacity: 0;
			transform: translateY(-6px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.nav-search__input-wrap {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.7rem 0.9rem;
		border-bottom: 1px solid rgb(255 160 120 / 0.15);
	}
	.nav-search__input-icon {
		width: 18px;
		height: 18px;
		flex-shrink: 0;
		color: rgb(255 180 140 / 0.7);
	}
	.nav-search__input {
		flex: 1;
		min-width: 0;
		background: transparent;
		border: none;
		outline: none;
		color: rgb(255 230 210 / 0.95);
		font-size: 0.92rem;
	}
	.nav-search__input::placeholder {
		color: rgb(255 200 170 / 0.4);
	}
	.nav-search__clear {
		flex-shrink: 0;
		width: 20px;
		height: 20px;
		border: none;
		border-radius: 50%;
		background: rgb(255 140 100 / 0.15);
		color: rgb(255 200 170 / 0.8);
		font-size: 0.65rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.nav-search__clear:hover {
		background: rgb(255 140 100 / 0.3);
	}

	.nav-search__results {
		max-height: 24rem;
		overflow-y: auto;
		padding: 0.35rem;
	}
	.nav-search__results::-webkit-scrollbar {
		width: 6px;
	}
	.nav-search__results::-webkit-scrollbar-thumb {
		background: rgb(255 140 100 / 0.25);
		border-radius: 3px;
	}

	.nav-search__hint {
		padding: 1.2rem 1rem;
		text-align: center;
		font-size: 0.85rem;
		color: rgb(255 200 170 / 0.5);
	}

	.nav-search__item {
		width: 100%;
		display: flex;
		align-items: flex-start;
		gap: 0.65rem;
		padding: 0.6rem 0.7rem;
		border: none;
		border-radius: 0.7rem;
		background: transparent;
		text-align: left;
		cursor: pointer;
		transition: background 0.12s ease;
	}
	.nav-search__item:hover,
	.nav-search__item.active {
		background: rgb(255 140 100 / 0.14);
	}

	.nav-search__tag {
		flex-shrink: 0;
		margin-top: 0.1rem;
		padding: 0.1rem 0.5rem;
		border-radius: 999px;
		font-size: 0.68rem;
		font-weight: 600;
		color: #ffb088;
		background: rgb(255 140 100 / 0.12);
		white-space: nowrap;
	}
	.nav-search__body {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
	}
	.nav-search__title {
		font-size: 0.9rem;
		font-weight: 600;
		color: rgb(255 230 210 / 0.95);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.nav-search__snippet {
		font-size: 0.76rem;
		color: rgb(255 200 170 / 0.5);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.nav-search__item :global(mark) {
		background: transparent;
		color: #ff9966;
		font-weight: 700;
	}
	.nav-search__ext {
		flex-shrink: 0;
		color: rgb(255 180 140 / 0.6);
		font-size: 0.85rem;
	}
</style>
