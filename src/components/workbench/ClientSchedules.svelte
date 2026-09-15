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
	let showForm = false;
	let editingId: string | null = null;

	// ===== 日程独立管理员登录（账号密码存 Supabase，与修仙界完全无关）=====
	const SCHEDULE_AUTH_KEY = "schedule_admin_auth";
	const SCHEDULE_AUTH_EXPIRE = 1000 * 60 * 60 * 8; // 8小时过期
	let scheduleAdminLoggedIn = false;
	let showScheduleLogin = false;
	let scheduleLoginUser = "";
	let scheduleLoginPass = "";
	let scheduleLoginError = "";
	let scheduleLoginLoading = false;

	function checkScheduleAdminAuth() {
		try {
			const raw = localStorage.getItem(SCHEDULE_AUTH_KEY);
			if (!raw) return;
			const data = JSON.parse(raw);
			if (data.authenticated && Date.now() - data.timestamp < SCHEDULE_AUTH_EXPIRE) {
				scheduleAdminLoggedIn = true;
			} else {
				localStorage.removeItem(SCHEDULE_AUTH_KEY);
			}
		} catch (e) {
			localStorage.removeItem(SCHEDULE_AUTH_KEY);
		}
	}

	async function scheduleAdminLogin() {
		if (scheduleLoginLoading) return;
		if (!scheduleLoginUser.trim() || !scheduleLoginPass) {
			scheduleLoginError = "请输入账号和密码";
			return;
		}
		scheduleLoginLoading = true;
		scheduleLoginError = "";
		try {
			const { data, error } = await supabase.rpc("verify_admin_credentials", {
				p_module: "schedule",
				p_username: scheduleLoginUser.trim(),
				p_password: scheduleLoginPass
			});
			if (error) throw error;
			if (data === true) {
				scheduleAdminLoggedIn = true;
				showScheduleLogin = false;
				scheduleLoginUser = "";
				scheduleLoginPass = "";
				localStorage.setItem(SCHEDULE_AUTH_KEY, JSON.stringify({
					authenticated: true,
					timestamp: Date.now()
				}));
				openAddForm();
			} else {
				scheduleLoginError = "账号或密码错误";
			}
		} catch (e: any) {
			scheduleLoginError = "登录验证失败：" + (e?.message || "未知错误");
		} finally {
			scheduleLoginLoading = false;
		}
	}

	function scheduleAdminLogout() {
		scheduleAdminLoggedIn = false;
		localStorage.removeItem(SCHEDULE_AUTH_KEY);
	}

	function closeScheduleLogin() {
		showScheduleLogin = false;
		scheduleLoginError = "";
		scheduleLoginUser = "";
		scheduleLoginPass = "";
	}

	// 表单字段
	let formTitle = "";
	let formDescription = "";
	let formDate = "";
	let formTime = "";
	let formLocation = "";
	let formStatus: "upcoming" | "completed" | "cancelled" = "upcoming";
	let submitting = false;
	let formError = "";

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

	function resetForm() {
		formTitle = "";
		formDescription = "";
		formDate = "";
		formTime = "";
		formLocation = "";
		formStatus = "upcoming";
		formError = "";
		editingId = null;
	}

	function openAddForm() {
		resetForm();
		showForm = true;
	}

	function openEditForm(s: Schedule) {
		editingId = s.id;
		formTitle = s.title;
		formDescription = s.description || "";
		formDate = s.schedule_date;
		formTime = s.schedule_time ? s.schedule_time.slice(0, 5) : "";
		formLocation = s.location || "";
		formStatus = s.status;
		formError = "";
		showForm = true;
	}

	function closeForm() {
		showForm = false;
		resetForm();
	}

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

	async function submitForm() {
		if (!supabase) return;
		if (!formTitle.trim()) {
			formError = "请填写日程标题";
			return;
		}
		if (!formDate) {
			formError = "请选择日程日期";
			return;
		}

		submitting = true;
		formError = "";

		const payload: Record<string, any> = {
			title: formTitle.trim(),
			description: formDescription.trim() || null,
			schedule_date: formDate,
			schedule_time: formTime || null,
			location: formLocation.trim() || null,
			status: formStatus,
		};

		try {
			if (editingId) {
				const { error: err } = await supabase
					.from("schedules")
					.update(payload)
					.eq("id", editingId);
				if (err) throw err;
			} else {
				const { error: err } = await supabase
					.from("schedules")
					.insert(payload);
				if (err) throw err;
			}
			closeForm();
			await loadSchedules();
		} catch (e: any) {
			formError = e?.message || "保存失败";
		} finally {
			submitting = false;
		}
	}

	async function deleteSchedule(id: string) {
		if (!supabase) return;
		if (!confirm("确定删除这条日程吗？此操作不可撤销。")) return;
		try {
			const { error: err } = await supabase
				.from("schedules")
				.delete()
				.eq("id", id);
			if (err) throw err;
			await loadSchedules();
		} catch (e: any) {
			alert("删除失败：" + (e?.message || "未知错误"));
		}
	}

	async function toggleStatus(s: Schedule) {
		if (!supabase) return;
		const next = s.status === "upcoming" ? "completed" : "upcoming";
		try {
			const { error: err } = await supabase
				.from("schedules")
				.update({ status: next })
				.eq("id", s.id);
			if (err) throw err;
			await loadSchedules();
		} catch (e: any) {
			alert("更新失败：" + (e?.message || "未知错误"));
		}
	}

	function handleOpenScheduleForm() {
		if (scheduleAdminLoggedIn) {
			openAddForm();
		} else {
			showScheduleLogin = true;
		}
	}

	onMount(async () => {
		checkScheduleAdminAuth();
		await loadSchedules();
	});
</script>

<svelte:window on:open-schedule-form={handleOpenScheduleForm} />

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
	{:else if schedules.length === 0 && !showForm}
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
								{#if scheduleAdminLoggedIn}
									<div class="sch-actions">
										<button class="sch-action-btn" on:click={() => toggleStatus(s)}>
											{s.status === "upcoming" ? "标记完成" : "标记未完成"}
										</button>
										<button class="sch-action-btn" on:click={() => openEditForm(s)}>编辑</button>
										<button class="sch-action-btn sch-delete" on:click={() => deleteSchedule(s.id)}>删除</button>
									</div>
								{/if}
							</article>
						{/each}
					</div>
				</div>
			{/each}
		</div>
	{/if}

	<!-- 日程管理员登录弹窗（独立系统，与修仙界无关） -->
	{#if showScheduleLogin}
		<div class="sch-modal-overlay" on:click={closeScheduleLogin}>
			<div class="sch-modal sch-login-modal" on:click|stopPropagation>
				<div class="sch-modal-header">
					<h3>日程管理登录</h3>
					<button class="sch-modal-close" on:click={closeScheduleLogin}>×</button>
				</div>
				<div class="sch-modal-body">
					{#if scheduleLoginError}
						<div class="sch-form-error">{scheduleLoginError}</div>
					{/if}
					<div class="sch-form-group">
						<label>账号</label>
						<input type="text" bind:value={scheduleLoginUser} placeholder="请输入管理员账号" on:keydown={(e) => e.key === "Enter" && scheduleAdminLogin()} />
					</div>
					<div class="sch-form-group">
						<label>密码</label>
						<input type="password" bind:value={scheduleLoginPass} placeholder="请输入管理员密码" on:keydown={(e) => e.key === "Enter" && scheduleAdminLogin()} />
					</div>
				</div>
				<div class="sch-modal-footer">
					<button class="sch-btn-cancel" on:click={closeScheduleLogin}>取消</button>
					<button class="sch-btn-submit" on:click={scheduleAdminLogin} disabled={scheduleLoginLoading}>
						{scheduleLoginLoading ? "验证中..." : "登录"}
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- 添加/编辑表单弹窗 -->
	{#if showForm}
		<div class="sch-modal-overlay" on:click={closeForm}>
			<div class="sch-modal" on:click|stopPropagation>
				<div class="sch-modal-header">
					<h3>{editingId ? "编辑日程" : "添加日程"}</h3>
					<button class="sch-modal-close" on:click={closeForm}>×</button>
				</div>
				<div class="sch-modal-body">
					{#if formError}
						<div class="sch-form-error">{formError}</div>
					{/if}
					<div class="sch-form-group">
						<label>标题 *</label>
						<input type="text" bind:value={formTitle} placeholder="日程标题" />
					</div>
					<div class="sch-form-row">
						<div class="sch-form-group">
							<label>日期 *</label>
							<input type="date" bind:value={formDate} />
						</div>
						<div class="sch-form-group">
							<label>时间</label>
							<input type="time" bind:value={formTime} />
						</div>
					</div>
					<div class="sch-form-group">
						<label>地点</label>
						<input type="text" bind:value={formLocation} placeholder="日程地点（可选）" />
					</div>
					<div class="sch-form-group">
						<label>描述</label>
						<textarea bind:value={formDescription} placeholder="日程详细描述（可选）" rows="3"></textarea>
					</div>
					<div class="sch-form-group">
						<label>状态</label>
						<select bind:value={formStatus}>
							<option value="upcoming">即将到来</option>
							<option value="completed">已完成</option>
							<option value="cancelled">已取消</option>
						</select>
					</div>
				</div>
				<div class="sch-modal-footer">
					<button class="sch-btn-cancel" on:click={closeForm}>取消</button>
					<button class="sch-btn-submit" on:click={submitForm} disabled={submitting}>
						{submitting ? "保存中..." : (editingId ? "保存修改" : "添加日程")}
					</button>
				</div>
			</div>
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

	/* 操作栏 */
	.sch-toolbar {
		display: flex;
		justify-content: flex-end;
		margin-bottom: 1.5rem;
	}

	/* 添加按钮 */
	.sch-add-btn {
		padding: 0.5rem 1.25rem;
		background: linear-gradient(135deg, rgba(155, 140, 255, 0.25), rgba(99, 216, 255, 0.15));
		border: 1px solid rgba(155, 140, 255, 0.4);
		border-radius: 0.6rem;
		color: #F5F7FF;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		font-family: inherit;
	}
	.sch-add-btn:hover {
		background: linear-gradient(135deg, rgba(155, 140, 255, 0.35), rgba(99, 216, 255, 0.25));
		box-shadow: 0 0 16px rgba(155, 140, 255, 0.3);
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

	/* 操作按钮 */
	.sch-actions {
		display: flex;
		gap: 0.6rem;
		margin-top: 1rem;
		padding-top: 0.85rem;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}
	.sch-action-btn {
		padding: 0.4rem 0.9rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 0.4rem;
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.78rem;
		cursor: pointer;
		transition: all 0.2s;
		font-family: inherit;
	}
	.sch-action-btn:hover {
		background: rgba(155, 140, 255, 0.1);
		color: rgba(155, 140, 255, 0.9);
		border-color: rgba(155, 140, 255, 0.3);
	}
	.sch-action-btn.sch-delete:hover {
		background: rgba(248, 113, 113, 0.1);
		color: rgba(248, 113, 113, 0.9);
		border-color: rgba(248, 113, 113, 0.3);
	}

	/* 弹窗 */
	.sch-modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.6);
		backdrop-filter: blur(4px);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	.sch-modal {
		width: 100%;
		max-width: 480px;
		max-height: 90vh;
		overflow-y: auto;
		background: rgba(15, 18, 30, 0.95);
		border: 1px solid rgba(155, 140, 255, 0.2);
		border-radius: 1rem;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}
	.sch-modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1.25rem 1.5rem;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.sch-modal-header h3 {
		margin: 0;
		font-size: 1.1rem;
		color: #F5F7FF;
	}
	.sch-modal-close {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.4);
		font-size: 1.5rem;
		cursor: pointer;
		line-height: 1;
		padding: 0.25rem;
	}
	.sch-modal-close:hover { color: #F5F7FF; }
	.sch-modal-body { padding: 1.5rem; }
	.sch-modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
		padding: 1rem 1.5rem 1.5rem;
	}

	/* 表单 */
	.sch-form-group { margin-bottom: 1rem; }
	.sch-form-group label {
		display: block;
		font-size: 0.8rem;
		color: rgba(255, 255, 255, 0.6);
		margin-bottom: 0.4rem;
	}
	.sch-form-group input,
	.sch-form-group textarea,
	.sch-form-group select {
		width: 100%;
		padding: 0.6rem 0.75rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 0.5rem;
		color: #F5F7FF;
		font-size: 0.85rem;
		font-family: inherit;
		box-sizing: border-box;
	}
	.sch-form-group input:focus,
	.sch-form-group textarea:focus,
	.sch-form-group select:focus {
		outline: none;
		border-color: rgba(155, 140, 255, 0.5);
		box-shadow: 0 0 0 3px rgba(155, 140, 255, 0.1);
	}
	.sch-form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
	}
	.sch-form-error {
		padding: 0.6rem 0.75rem;
		background: rgba(248, 113, 113, 0.1);
		border: 1px solid rgba(248, 113, 113, 0.3);
		border-radius: 0.5rem;
		color: rgba(248, 113, 113, 0.9);
		font-size: 0.8rem;
		margin-bottom: 1rem;
	}

	/* 弹窗按钮 */
	.sch-btn-cancel {
		padding: 0.55rem 1.25rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 0.5rem;
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.85rem;
		cursor: pointer;
		font-family: inherit;
	}
	.sch-btn-cancel:hover { background: rgba(255, 255, 255, 0.08); }
	.sch-btn-submit {
		padding: 0.55rem 1.25rem;
		background: linear-gradient(135deg, rgba(155, 140, 255, 0.3), rgba(99, 216, 255, 0.2));
		border: 1px solid rgba(155, 140, 255, 0.4);
		border-radius: 0.5rem;
		color: #F5F7FF;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		font-family: inherit;
	}
	.sch-btn-submit:hover:not(:disabled) {
		box-shadow: 0 0 16px rgba(155, 140, 255, 0.3);
	}
	.sch-btn-submit:disabled { opacity: 0.5; cursor: not-allowed; }

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
		.sch-actions { gap: 0.5rem; margin-top: 0.85rem; padding-top: 0.7rem; flex-wrap: wrap; }
		.sch-action-btn { padding: 0.35rem 0.75rem; font-size: 0.75rem; }
		.sch-form-row { grid-template-columns: 1fr; }
	}
</style>
