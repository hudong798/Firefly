<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	// ---------- 类型 ----------
	interface ArchiveRow {
		id: string;
		title: string;
		url: string;
		category: string;
		tags: string[] | null;
		description: string | null;
		rating: number | null;
		status: string;
		sort_order: number;
	}
	interface TvSite { name: string; url: string; type: string; rating?: number; }
	interface CommunitySite { name: string; url: string; desc?: string; }
	interface ToolSite { name: string; url: string; desc?: string; }
	interface ToolGroup { title: string; items: ToolSite[]; }

	// ---------- 状态 ----------
	const MAIN_TABS = [
		{ key: "tv", num: "01", name: "影视" },
		{ key: "community", num: "02", name: "社区" },
		{ key: "tool", num: "03", name: "工具" },
	];
	const TV_SUBTYPES = ["综合", "动漫", "短剧", "其他"];
	const typeLabel: Record<string, string> = {
		综合: "GENERAL", 动漫: "ANIME", 短剧: "DRAMA", 其他: "OTHER",
	};

	let activeMainTab = "tv";
	let activeTvSub = "综合";
	let tvSites: TvSite[] = [];
	let communities: CommunitySite[] = [];
	let toolGroups: ToolGroup[] = [];
	let loading = true;
	let error = "";

	onMount(async () => {
		try {
			if (!supabase) { error = "Supabase 未配置"; loading = false; return; }
			const { data, error: err } = await supabase
				.from("archives")
				.select("*")
				.eq("status", "published")
				.order("sort_order", { ascending: true });
			if (err) throw err;
			const rows: ArchiveRow[] = data || [];

			// 影视
			tvSites = rows
				.filter((r) => r.category === "影视")
				.map((r) => ({
					name: r.title,
					url: r.url || "",
					type: r.tags?.[0] || "综合",
					rating: r.rating ?? undefined,
				}));
			// 社区
			communities = rows
				.filter((r) => r.category === "社区")
				.map((r) => ({ name: r.title, url: r.url || "", desc: r.description || undefined }));
			// 工具：按 tags[0] 分组
			const toolRows = rows.filter((r) => r.category === "工具");
			const gmap = new Map<string, ToolSite[]>();
			for (const r of toolRows) {
				const gn = r.tags?.[0] || "其他工具";
				if (!gmap.has(gn)) gmap.set(gn, []);
				gmap.get(gn)!.push({ name: r.title, url: r.url || "", desc: r.description || undefined });
			}
			toolGroups = Array.from(gmap.entries()).map(([title, items]) => ({ title, items }));
		} catch (e: any) {
			error = e?.message || "加载失败";
		}
		loading = false;
	});

	// 影视子分类分组
	$: tvGroups = TV_SUBTYPES.map((t) => ({
		type: t,
		sites: tvSites.filter((s) => s.type === t),
	})).filter((g) => g.sites.length > 0);
</script>

<div class="arch-container">
	<!-- 主分类导航 -->
	<nav class="arch-index" role="tablist" aria-label="档案分类">
		{#each MAIN_TABS as tab}
			<button
				class="arch-index-item"
				class:is-active={activeMainTab === tab.key}
				role="tab"
				aria-selected={activeMainTab === tab.key}
				onclick={() => activeMainTab = tab.key}
			>
				<span class="arch-index-num">{tab.num}</span>
				<span class="arch-index-name">{tab.name}</span>
			</button>
		{/each}
	</nav>

	{#if loading}
		<p class="section-tip">加载中…</p>
	{:else if error}
		<p class="section-tip" style="color:#f87171;">{error}</p>
	{:else}

		<!-- 影视面板 -->
		{#if activeMainTab === "tv"}
			<nav class="tv-tabs">
				{#each TV_SUBTYPES as st}
					<button
						class="tv-tab"
						class:active={activeTvSub === st}
						onclick={() => activeTvSub = st}
					>{st}</button>
				{/each}
			</nav>
			{#each tvGroups as g, gi}
				{#if g.type === activeTvSub}
					<div class="tv-group">
						<div class="tv-group-header">
							<div class="tv-group-title">
								<span class="tv-group-label">{typeLabel[g.type]}</span>
								<span class="tv-group-name">{g.type}</span>
							</div>
							<span class="tv-group-count">{g.sites.length} ENTRIES</span>
						</div>
						<div class="tv-grid">
							{#each g.sites as s, idx}
								{@const archiveNum = String(gi * 100 + idx + 1).padStart(3, "0")}
								<a class="tv-card" href={s.url} target="_blank" rel="noopener" style={`--tv-index:${idx + 1};`}>
									<div class="tv-card-top">
										<span class="tv-card-id">ARCHIVE / {archiveNum}</span>
										<span class="tv-card-type">{typeLabel[s.type]}</span>
									</div>
									<h4 class="tv-card-name">{s.name}</h4>
									<div class="tv-card-spacer"></div>
									<div class="tv-card-bottom">
										<span class="tv-card-rating">RATING {s.rating != null ? s.rating.toFixed(1) : '--'}</span>
										<span class="tv-card-arrow">↗</span>
									</div>
								</a>
							{/each}
						</div>
					</div>
				{/if}
			{/each}
		{/if}

		<!-- 社区面板 -->
		{#if activeMainTab === "community"}
			<div class="arch-section-header">
				<span class="arch-section-label">ARCHIVE INDEX</span>
				<span class="arch-section-count">{communities.length} ENTRIES</span>
			</div>
			<div class="arch-grid">
				{#each communities as c, index}
					<a class="arch-card arch-card-mini" href={c.url} target="_blank" rel="noopener" style={`--arch-index:${index + 1};`}>
						<h3 class="arch-card-name">{c.name}</h3>
						{#if c.desc}<p class="arch-card-mini-desc">{c.desc}</p>{/if}
					</a>
				{/each}
			</div>
		{/if}

		<!-- 工具面板 -->
		{#if activeMainTab === "tool"}
			<p class="arch-tool-hint">好用的工具让人事半功倍，点击直达官网。</p>
			{#each toolGroups as g, gi}
				<section class="arch-tool-group" style={`--arch-index:${gi + 1};`}>
					<h2 class="arch-tool-group-title">
						<span class="arch-tool-group-num">{String(gi + 1).padStart(2, "0")}</span>
						{g.title}
					</h2>
					<div class="tv-grid">
						{#each g.items as item, idx}
							<a class="tv-card" href={item.url} target="_blank" rel="noopener" style={`--tv-index:${idx + 1};`}>
								<div class="tv-card-top">
									<span class="tv-card-id">LINK / {String(idx + 1).padStart(2, "0")}</span>
									<span class="tv-card-type">{g.title}</span>
								</div>
								<h4 class="tv-card-name">{item.name}</h4>
								<div class="tv-card-spacer"></div>
								<div class="tv-card-bottom">
									{#if item.desc}<span class="tv-card-rating">{item.desc}</span>{/if}
									<span class="tv-card-arrow">↗</span>
								</div>
							</a>
						{/each}
					</div>
				</section>
			{/each}
		{/if}
	{/if}
</div>

<style>
	/* 主分类导航 */
	.arch-index { display:flex; flex-wrap:wrap; gap:1.5rem; margin:0 0 2rem; padding-bottom:1.25rem; border-bottom:1px solid rgba(255,255,255,0.06); }
	.arch-index-item { display:flex; flex-direction:column; gap:0.3rem; background:none; border:none; cursor:pointer; padding:0; color:rgba(255,255,255,0.45); transition:color .2s; }
	.arch-index-item:hover { color:rgba(255,255,255,0.8); }
	.arch-index-item.is-active { color:#93c5fd; }
	.arch-index-num { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.65rem; letter-spacing:0.1em; opacity:0.5; }
	.arch-index-name { font-size:1.15rem; font-weight:600; }

	/* 影视子分类 tabs */
	.tv-tabs { display:flex; flex-wrap:wrap; gap:0.5rem; margin:0 0 1.5rem; }
	.tv-tab { padding:0.45rem 1rem; border-radius:999px; border:1px solid rgba(155,140,255,0.25); background:rgba(20,24,44,0.6); color:#C7CCDB; font-size:0.85rem; cursor:pointer; transition:all .2s; }
	.tv-tab:hover { border-color:rgba(155,140,255,0.6); color:#fff; }
	.tv-tab.active { background:linear-gradient(135deg,#7c5cff,#5b8cff); border-color:transparent; color:#fff; }

	.tv-group { margin-bottom:3rem; }
	.tv-group-header { display:flex; align-items:center; justify-content:space-between; gap:1rem; margin-bottom:1.25rem; padding-bottom:0.85rem; border-bottom:1px solid rgba(255,255,255,0.05); }
	.tv-group-title { display:flex; align-items:baseline; gap:0.85rem; }
	.tv-group-label { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.6rem; letter-spacing:0.14em; color:rgba(155,140,255,0.55); text-transform:uppercase; }
	.tv-group-name { font-size:1rem; font-weight:600; color:#D8DCE7; }
	.tv-group-count { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.6rem; letter-spacing:0.1em; color:rgba(255,255,255,0.3); text-transform:uppercase; white-space:nowrap; }

	.tv-grid { display:grid; grid-template-columns:repeat(10,minmax(0,1fr)); gap:0.6rem; }
	.tv-card { display:flex; flex-direction:column; min-height:115px; padding:0.7rem 0.8rem; border-radius:12px; background:rgba(255,255,255,0.015); border:1px solid rgba(255,255,255,0.07); text-decoration:none; color:inherit; cursor:pointer; position:relative; overflow:hidden; animation:card-in 0.4s ease-out both; animation-delay:calc(min(var(--tv-index),10)*30ms); transition:transform .25s, border-color .25s, background .25s; }
	@keyframes card-in { from { opacity:0; transform:translateY(12px); } to { opacity:1; transform:translateY(0); } }
	.tv-card::before { content:""; position:absolute; left:0; top:0; bottom:0; width:2px; background:linear-gradient(to bottom,rgba(155,140,255,0.5),rgba(155,140,255,0.05)); opacity:0; transition:opacity .25s; }
	.tv-card:hover { transform:translateY(-3px); border-color:rgba(155,140,255,0.22); background:rgba(255,255,255,0.025); }
	.tv-card:hover::before { opacity:1; }
	.tv-card-top { display:flex; align-items:center; justify-content:space-between; gap:0.5rem; margin-bottom:0.5rem; }
	.tv-card-id { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.48rem; letter-spacing:0.08em; color:rgba(255,255,255,0.24); text-transform:uppercase; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
	.tv-card-type { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.48rem; letter-spacing:0.08em; color:rgba(255,255,255,0.3); text-transform:uppercase; padding:0.06rem 0.35rem; border:1px solid rgba(255,255,255,0.06); border-radius:3px; line-height:1.5; }
	.tv-card-name { margin:0; font-size:0.92rem; font-weight:600; color:#4ade80; line-height:1.25; transition:color .2s; word-break:break-all; }
	.tv-card:hover .tv-card-name { color:#fff; }
	.tv-card-spacer { flex:1; }
	.tv-card-bottom { display:flex; align-items:center; justify-content:space-between; margin-top:0.4rem; padding-top:0.35rem; border-top:1px solid rgba(255,255,255,0.04); }
	.tv-card-rating { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.48rem; letter-spacing:0.04em; color:rgba(255,255,255,0.26); text-transform:uppercase; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
	.tv-card-arrow { color:rgba(255,255,255,0.2); font-size:0.65rem; transition:color .2s, transform .2s; flex-shrink:0; }
	.tv-card:hover .tv-card-arrow { color:rgba(155,140,255,0.75); transform:translate(2px,-2px); }

	/* 社区卡片 */
	.arch-section-header { display:flex; align-items:center; justify-content:space-between; gap:1rem; margin-bottom:1.25rem; padding-bottom:0.85rem; border-bottom:1px solid rgba(255,255,255,0.05); }
	.arch-section-label { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.6rem; letter-spacing:0.14em; color:rgba(155,140,255,0.55); text-transform:uppercase; }
	.arch-section-count { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.6rem; letter-spacing:0.1em; color:rgba(255,255,255,0.3); text-transform:uppercase; white-space:nowrap; }
	.arch-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:0.7rem; }
	.arch-card { display:flex; flex-direction:column; padding:1rem; border-radius:12px; background:rgba(255,255,255,0.02); border:1px solid rgba(255,255,255,0.07); text-decoration:none; color:inherit; transition:all .2s; }
	.arch-card:hover { border-color:rgba(155,140,255,0.25); background:rgba(255,255,255,0.04); }
	.arch-card-mini { align-items:center; text-align:center; min-height:70px; justify-content:center; }
	.arch-card-name { margin:0; font-size:0.92rem; font-weight:600; color:#4ade80; }
	.arch-card-mini-desc { margin:0.3rem 0 0; font-size:0.72rem; color:rgba(255,255,255,0.4); line-height:1.4; }

	/* 工具 */
	.arch-tool-hint { color:#7F8799; font-size:0.85rem; margin:0 0 1.5rem; }
	.arch-tool-group { margin-bottom:2rem; animation:card-in .4s ease-out both; animation-delay:calc(var(--arch-index)*50ms); }
	.arch-tool-group-title { display:flex; align-items:center; gap:0.55rem; font-size:1.05rem; font-weight:700; margin:0 0 0.9rem; color:#4ade80; }
	.arch-tool-group-num { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:0.65rem; color:rgba(155,140,255,0.5); }

	.section-tip { margin-top:1.6rem; font-size:0.85rem; color:#4ade80; }

	/* 响应式 */
	@media (max-width:1440px) { .tv-grid { grid-template-columns:repeat(8,minmax(0,1fr)); } }
	@media (max-width:1100px) { .tv-grid { grid-template-columns:repeat(6,minmax(0,1fr)); } .arch-grid { grid-template-columns:repeat(3,1fr); } }
	@media (max-width:900px) { .tv-grid { grid-template-columns:repeat(5,minmax(0,1fr)); } }
	@media (max-width:700px) { .tv-grid { grid-template-columns:repeat(4,minmax(0,1fr)); gap:0.5rem; } .tv-card { min-height:100px; padding:0.6rem 0.7rem; } .tv-card-name { font-size:0.85rem; } .arch-grid { grid-template-columns:repeat(2,1fr); } }
	@media (max-width:560px) { .tv-grid { grid-template-columns:repeat(2,minmax(0,1fr)); } .tv-group-header { flex-direction:column; align-items:flex-start; gap:0.3rem; } .tv-card { min-height:95px; padding:0.55rem 0.65rem; } .tv-card-name { font-size:0.82rem; } }
</style>
