<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	interface AiToolItem {
		name: string;
		url: string;
		logo?: string;
	}
	interface AiGroup {
		title: string;
		items: AiToolItem[];
	}

	const CATS = ["国内", "国外", "视频生成", "图片生成", "模型"];
	let activeCat = "国内";
	let groups: AiGroup[] = [];
	let loading = true;
	let error = "";

	onMount(async () => {
		try {
			if (!supabase) {
				error = "Supabase 未配置";
				loading = false;
				return;
			}
			const { data, error: err } = await supabase
				.from("ai_tools")
				.select("*")
				.eq("status", "published")
				.order("featured", { ascending: false })
				.order("sort_order", { ascending: true });
			if (err) throw err;
			const map = new Map<string, AiToolItem[]>();
			for (const t of data || []) {
				const cat = t.category || "其他";
				if (!map.has(cat)) map.set(cat, []);
				map.get(cat)!.push({ name: t.name, url: t.url || "", logo: t.logo || undefined });
			}
			groups = Array.from(map.entries()).map(([title, items]) => ({ title, items }));
		} catch (e: any) {
			error = e?.message || "加载失败";
		}
		loading = false;
	});

	function applyCat(cat: string) {
		activeCat = cat;
	}
</script>

<div class="ai-content">
	<p class="section-hint">点击直达官网，收藏你常用的 AI 助手吧。</p>

	<select class="ai-select" value={activeCat} onchange={(e) => applyCat((e.target as HTMLSelectElement).value)}>
		{#each CATS as cat}
			<option value={cat}>{cat}</option>
		{/each}
	</select>
	<div class="ai-tabs">
		{#each CATS as cat}
			<button
				class="ai-tab"
				class:active={activeCat === cat}
				onclick={() => applyCat(cat)}
			>{cat}</button>
		{/each}
	</div>

	{#if loading}
		<p class="section-tip">加载中…</p>
	{:else if error}
		<p class="section-tip" style="color:#f87171;">{error}</p>
	{:else}
		{#each groups as g}
			{#if g.title === activeCat}
				<section class="ai-group">
					<h2 class="ai-group-title">{g.title}</h2>
					<div class="link-grid" style="--per-row:6;">
						{#each g.items as it}
							<a class="link-cell" href={it.url} target="_blank" rel="noopener">
								{#if it.logo}
									<img
										class="link-cell-logo-img"
										src={it.logo}
										alt={it.name}
										loading="lazy"
										onerror={(e) => { e.currentTarget.style.display = 'none'; const n = e.currentTarget.nextElementSibling; if (n) n.style.display = 'flex'; }}
									/>
									<span class="link-cell-fallback" style="display:none;">
										{it.name.trim().charAt(0)}
									</span>
								{:else}
									<span class="link-cell-fallback">
										{it.name.trim().charAt(0)}
									</span>
								{/if}
								<span class="link-cell-name">{it.name}</span>
							</a>
						{/each}
					</div>
				</section>
			{/if}
		{/each}
	{/if}

	<p class="section-tip">💡 想推荐其他好用的 AI 工具？欢迎去<a href="/guestbook/">讨论区</a>留言！</p>
</div>

<style>
	.ai-tabs { display:flex; flex-wrap:wrap; gap:10px; margin: 6px 0 22px; }
	.ai-tab { padding: 0.45rem 1.15rem; border-radius: 999px; border: 1px solid rgba(255,255,255,0.12); background: rgba(255,255,255,0.06); backdrop-filter: blur(14px) saturate(160%); -webkit-backdrop-filter: blur(14px) saturate(160%); color: rgba(255,255,255,0.7); font-size: 0.88rem; cursor:pointer; transition: all .18s; box-shadow: 0 2px 10px rgba(0,0,0,0.15); }
	.ai-tab:hover { border-color: rgba(255,255,255,0.28); background: rgba(255,255,255,0.1); color:#fff; }
	.ai-tab.active { background: rgba(59,130,246,0.22); border-color: rgba(96,165,250,0.5); color:#93c5fd; box-shadow: 0 4px 16px rgba(59,130,246,0.25), inset 0 1px 0 rgba(147,197,253,0.2); }
	.ai-select { display:none; width:100%; margin:6px 0 16px; padding:0.6rem 0.9rem; border-radius:12px; border:1px solid rgba(155,140,255,0.25); background:rgba(20,24,44,0.9); color:#e6ebf5; font-size:0.92rem; }
	@media (max-width: 768px) { .ai-tabs { display:none; } .ai-select { display:block; } .ai-group-title { display:none; } }
	.section-hint { color: #4ade80; font-size: 0.88rem; margin: 0 0 1.1rem; }
	.ai-group { margin-top: 1.7rem; }
	.ai-group:first-of-type { margin-top: 0.2rem; }
	.ai-group-title { display:none; display:flex; align-items:center; gap:0.55rem; font-size:1.08rem; font-weight:700; margin:0 0 0.9rem; color:#4ade80; }
	.ai-group :global(.link-cell-name) { color: #60a5fa !important; }
	.ai-group-title::before { content:""; width:4px; height:1.05rem; border-radius:2px; background:var(--primary); }
	.section-tip { margin-top:1.6rem; font-size:0.85rem; color:#4ade80; }
	.section-tip a { color:var(--primary); text-decoration:none; }
	.section-tip a:hover { text-decoration:underline; }

	.link-grid { display:grid; grid-template-columns:repeat(var(--per-row,6),1fr); gap:0.9rem; }
	.link-cell { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:0.55rem; padding:1.15rem 0.5rem; border-radius:var(--radius-large,14px); background:var(--card-bg,rgba(255,255,255,0.04)); border:1px solid var(--line-divider,rgba(255,255,255,0.08)); text-decoration:none; color:inherit; transition:transform 0.18s ease, border-color 0.18s ease, background 0.18s ease; }
	.link-cell:hover { transform:translateY(-2px); border-color:rgba(155,140,255,0.3); background:rgba(255,255,255,0.06); }
	.link-cell-logo-img { width:40px; height:40px; border-radius:10px; object-fit:cover; }
	.link-cell-fallback { width:40px; height:40px; border-radius:10px; background:rgba(155,140,255,0.15); display:flex; align-items:center; justify-content:center; font-size:1.1rem; font-weight:700; color:#9B8CFF; }
	.link-cell-name { font-size:0.82rem; color:#60a5fa; text-align:center; line-height:1.3; word-break:break-all; }
</style>
