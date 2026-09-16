<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	interface Schedule {
		id: string;
		title: string;
		description: string | null;
		schedule_date: string;
		schedule_time: string | null;
		location: string | null;
		status: "upcoming" | "completed" | "cancelled";
		created_at: string;
		updated_at: string;
	}

	let schedules: Schedule[] = [];
	let loading = true;
	let error = "";

	const STATUS_LABELS: Record<string, string> = {
		upcoming: "即将到来",
		completed: "已完成",
		cancelled: "已取消",
	};

	const STATUS_COLORS: Record<string, string> = {
		upcoming: "rgba(155, 140, 255, 0.8)",
		completed: "rgba(52, 211, 153, 0.8)",
		cancelled: "rgba(248, 113, 113, 0.6)",
	};

	function formatTime(timeStr: string | null): string {
		if (!timeStr) return "";
		return timeStr.slice(0, 5);
	}

	function getWeekday(dateStr: string): string {
		const d = new Date(dateStr + "T00:00:00");
		const weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
		return weekdays[d.getDay()];
	}

	function getMonthDay(dateStr: string): { month: string; day: string } {
		const d = new Date(dateStr + "T00:00:00");
		return {
			month: String(d.getMonth() + 1).padStart(2, "0"),
			day: String(d.getDate()).padStart(2, "0"),
		};
	}

	// 按日期分组
	$: groupedSchedules = (() => {
		const map = new Map<string, Schedule[]>();
		for (const s of schedules) {
			if (!map.has(s.schedule_date)) {
				map.set(s.schedule_date, []);
			}
			map.get(s.schedule_date)!.push(s);
		}
		return Array.from(map.entries()).map(([date, items]) => ({
			date,
			items: items.sort((a, b) => (a.schedule_time || "").localeCompare(b.schedule_time || "")),
		}));
	})();

	async function loadSchedules() {
		if (!supabase) {
			loading = false;
			error = "Supabase 未配置";
			return;
		}
		try {
			const { data, error: err } = await supabase
				.from("schedules")
				.select("*")
				.order("schedule_date", { ascending: true })
				.order("schedule_time", { ascending: true })
				.limit(100);
			if (err) throw err;
			schedules = (data as Schedule[]) || [];
		} catch (e: any) {
			error = e?.message || "加载失败";
		} finally {
			loading = false;
		}
	}

	onMount(async () => {
		await loadSchedules();
	});
</script>

<div class="client-schedules">
	{#if loading}
		<div class="sch-loading">
			<div class="sch-spinner"></div>
			<span>正在加载日程...</span>
		</div>
	{:else if error && schedules.length === 0}
		<div class="sch-error">
			<p>日程加载失败：{error}</p>
		</div>
	{:else if schedules.length === 0}
		<div class="sch-empty">
			<div class="sch-empty-icon">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
					<line x1="16" y1="2" x2="16" y2="6"/>
					<line x1="8" y1="2" x2="8" y2="6"/>
					<line x1="3" y1="10" x2="21" y2="10"/>
				</svg>
			</div>
			<p class="sch-empty-title">暂无日程</p>
			<p class="sch-empty-sub">点击右上角「写日程」添加第一条日程。</p>
		</div>
	{:else}
		<!-- 时间线：左侧日期栏 + 轨道线，右侧卡片列 -->
		<div class="sch-timeline">
			{#each groupedSchedules as group, gIndex (group.date)}
				<div class="sch-timeline-group">
					<!-- 日期栏（桌面端纵向吸附，移动端横排） -->
					<div class="sch-timeline-date">
						<span class="sch-timeline-month">{getMonthDay(group.date).month}月</span>
						<span class="sch-timeline-day">{getMonthDay(group.date).day}</span>
						<span class="sch-timeline-weekday">{getWeekday(group.date)}</span>
					</div>
					<!-- 日程卡片列 -->
					<div class="sch-timeline-items">
						{#each group.items as s, index (s.id)}
							<article class="sch-card" style={`--sch-index: ${gIndex * 10 + index};`}>
								<div class="sch-card-top">
									<h3 class="sch-title">{s.title}</h3>
									<span class="sch-status" style={`color: ${STATUS_COLORS[s.status]}; border-color: ${STATUS_COLORS[s.status]}40; background: ${STATUS_COLORS[s.status]}12;`}>
										{STATUS_LABELS[s.status]}
									</span>
								</div>
								<div class="sch-meta">
									{#if s.schedule_time}
										<span class="sch-meta-item">
											<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
											{formatTime(s.schedule_time)}
										</span>
									{/if}
									{#if s.location}
										<span class="sch-meta-item">
											<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
											{s.location}
										</span>
									{/if}
								</div>
								{#if s.description}
									<p class="sch-description">{s.description}</p>
								{/if}
							</article>
						{/each}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.client-schedules {
		font-family: inherit;
	}

	/* 加载 */
	.sch-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		padding: 4rem 2rem;
		color: rgba(255, 255, 255, 0.4);
	}
	.sch-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(155, 140, 255, 0.2);
		border-top-color: rgba(155, 140, 255, 0.8);
		border-radius: 50%;
		animation: sch-spin 0.8s linear infinite;
	}
	@keyframes sch-spin { to { transform: rotate(360deg); } }

	/* 错误 */
	.sch-error {
		text-align: center;
		padding: 3rem 2rem;
		color: rgba(248, 113, 113, 0.8);
	}

	/* 空状态 */
	.sch-empty {
		text-align: center;
		padding: 4rem 2rem;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 1rem;
		background: rgba(255, 255, 255, 0.02);
	}
	.sch-empty-icon {
		width: 48px;
		height: 48px;
		margin: 0 auto 1rem;
		color: rgba(155, 140, 255, 0.5);
	}
	.sch-empty-icon svg { width: 100%; height: 100%; }
	.sch-empty-title {
		font-size: 1.1rem;
		font-weight: 600;
		color: rgba(245, 247, 255, 0.8);
		margin: 0 0 0.5rem;
	}
	.sch-empty-sub {
		font-size: 0.85rem;
		color: rgba(141, 150, 170, 0.6);
		margin: 0 0 1.5rem;
	}

	/* 时间线：左日期栏 + 竖向轨道 + 右卡片列，与页面容器共用同一轴线 */
	.sch-timeline {
		display: flex;
		flex-direction: column;
		gap: 2.25rem;
	}

	.sch-timeline-group {
		display: grid;
		grid-template-columns: 76px 1fr;
		gap: 1.5rem;
		align-items: start;
	}

	/* 日期栏：纵向堆叠，滚动时吸附 */
	.sch-timeline-date {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: 0.1rem;
		position: sticky;
		top: 6rem;
		padding-top: 0.35rem;
	}

	.sch-timeline-month {
		font-size: 0.75rem;
		color: rgba(155, 140, 255, 0.75);
		letter-spacing: 0.12em;
		font-weight: 500;
	}

	.sch-timeline-day {
		font-size: 2rem;
		font-weight: 700;
		color: #F5F7FF;
		line-height: 1.1;
		text-shadow: 0 0 20px rgba(155, 140, 255, 0.3);
	}

	.sch-timeline-weekday {
		font-size: 0.75rem;
		color: rgba(141, 150, 170, 0.6);
		letter-spacing: 0.05em;
	}

	/* 卡片列：左侧竖向轨道线 */
	.sch-timeline-items {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		min-width: 0;
		border-left: 1px solid rgba(155, 140, 255, 0.14);
		padding-left: 1.5rem;
	}

	/* 日程卡片 */
	.sch-card {
		display: block;
		width: 100%;
		box-sizing: border-box;
		padding: 1.4rem 1.6rem;
		background: rgba(155, 140, 255, 0.04);
		border: 1px solid rgba(155, 140, 255, 0.12);
		border-radius: 0.75rem;
		backdrop-filter: blur(8px);
		transition: background 0.25s ease, border-color 0.25s ease, transform 0.25s ease;
	}
	.sch-card:hover {
		background: rgba(155, 140, 255, 0.07);
		border-color: rgba(155, 140, 255, 0.22);
		transform: translateY(-2px);
	}

	/* 卡片顶部：标题 + 状态 */
	.sch-card-top {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 0.7rem;
	}
	.sch-title {
		font-size: 1.15rem;
		font-weight: 600;
		color: #F4F5FA;
		margin: 0;
		flex: 1;
	}
	.sch-status {
		font-size: 0.72rem;
		padding: 0.25rem 0.65rem;
		border-radius: 4px;
		border: 1px solid;
		white-space: nowrap;
		letter-spacing: 0.05em;
		flex-shrink: 0;
	}

	/* 元信息 */
	.sch-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
	}
	.sch-meta-item {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 0.82rem;
		color: rgba(255, 255, 255, 0.5);
	}
	.sch-meta-item svg {
		width: 14px;
		height: 14px;
		flex-shrink: 0;
	}

	/* 描述 */
	.sch-description {
		font-size: 0.92rem;
		line-height: 1.75;
		color: rgba(255, 255, 255, 0.65);
		margin: 0.7rem 0 0;
		white-space: pre-wrap;
		word-break: break-word;
	}

	/* 响应式：移动端——日期回到卡片上方横排，去掉轨道线 */
	@media (max-width: 768px) {
		.sch-timeline { gap: 1.75rem; }
		.sch-timeline-group {
			display: flex;
			flex-direction: column;
			gap: 0.7rem;
		}
		.sch-timeline-date {
			flex-direction: row;
			align-items: baseline;
			gap: 0.5rem;
			position: static;
			padding-top: 0;
		}
		.sch-timeline-month { font-size: 0.8rem; }
		.sch-timeline-day { font-size: 1.4rem; }
		.sch-timeline-weekday { font-size: 0.75rem; }
		.sch-timeline-items {
			border-left: none;
			padding-left: 0;
			gap: 0.75rem;
		}
		.sch-card { padding: 1.1rem 1.2rem; }
		.sch-title { font-size: 1.05rem; }
		.sch-status { font-size: 0.65rem; padding: 0.2rem 0.5rem; }
		.sch-meta { gap: 0.75rem; }
		.sch-meta-item { font-size: 0.75rem; }
		.sch-meta-item svg { width: 12px; height: 12px; }
		.sch-description { font-size: 0.85rem; line-height: 1.6; }
	}
</style>
