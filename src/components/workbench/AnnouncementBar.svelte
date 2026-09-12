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

	let announcements: Echo[] = [];
	let loading = true;

	onMount(async () => {
		if (!supabase) {
			loading = false;
			return;
		}
		try {
			const { data, error } = await supabase
				.from("echoes")
				.select("*")
				.eq("status", "published")
				.order("created_at", { ascending: false })
				.limit(2);
			if (!error && data) {
				announcements = data;
			}
		} catch (e) {
			// 静默失败
		}
		loading = false;
	});

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		const m = String(d.getMonth() + 1).padStart(2, "0");
		const day = String(d.getDate()).padStart(2, "0");
		return `${m}.${day}`;
	}
</script>

<div class="announcement-bar">
	<div class="announcement-icon">
		<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
			<path d="M3 11l18-5v12L3 14v-3z"/>
			<path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/>
		</svg>
	</div>
	<div class="announcement-list">
		{#if loading}
			<div class="announcement-item">
				<span class="announcement-text">加载中...</span>
			</div>
		{:else if announcements.length === 0}
			<div class="announcement-item">
				<span class="announcement-text">暂无公告</span>
			</div>
		{:else}
			{#each announcements as item}
				<a href="/thoughts/{item.slug}/" class="announcement-item">
					<span class="announcement-date">{formatDate(item.created_at)}</span>
					<span class="announcement-text">{item.title || item.content.slice(0, 50)}</span>
				</a>
			{/each}
		{/if}
	</div>
</div>

<style>
	.announcement-bar {
		display: flex;
		align-items: center;
		gap: 0.85rem;
		padding: 0.75rem 1.4rem;
		background: rgba(155, 140, 255, 0.06);
		border: 1px solid rgba(155, 140, 255, 0.12);
		border-radius: 0.75rem;
		backdrop-filter: blur(8px);
		margin-bottom: 1.5rem;
	}

	.announcement-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		color: rgba(155, 140, 255, 0.7);
		flex-shrink: 0;
	}

	.announcement-list {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		min-width: 0;
	}

	.announcement-item {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		text-decoration: none;
		color: inherit;
	}

	.announcement-date {
		font-family: "JetBrains Mono", ui-monospace, monospace;
		font-size: 0.8rem;
		color: rgba(155, 140, 255, 0.6);
		flex-shrink: 0;
	}

	.announcement-text {
		font-size: 0.95rem;
		color: rgba(245, 247, 255, 0.85);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		transition: color 0.2s;
	}

	.announcement-item:hover .announcement-text {
		color: rgba(245, 247, 255, 0.95);
	}

	@media (max-width: 768px) {
		.announcement-bar {
			padding: 0.5rem 0.9rem;
			margin-bottom: 1rem;
		}
		.announcement-text {
			font-size: 0.78rem;
		}
	}
</style>
