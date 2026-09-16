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

	// ===== 日程管理独立登录（账号密码存 Supabase，与修仙界无关）=====
	const SCHEDULE_AUTH_KEY = "schedule_admin_auth";
	const SCHEDULE_AUTH_EXPIRE = 1000 * 60 * 60 * 8; // 8小时过期
	let loggedIn = false;
	let loginUser = "";
	let loginPass = "";
	let loginError = "";
	let loginLoading = false;

	function checkScheduleAuth() {
		try {
			const raw = localStorage.getItem(SCHEDULE_AUTH_KEY);
			if (!raw) return;
			const data = JSON.parse(raw);
			if (data.authenticated && data.username && data.password && Date.now() - data.timestamp < SCHEDULE_AUTH_EXPIRE) {
				loggedIn = true;
			} else {
				localStorage.removeItem(SCHEDULE_AUTH_KEY);
			}
		} catch (e) {
			localStorage.removeItem(SCHEDULE_AUTH_KEY);
		}
	}

	function getScheduleCredentials() {
		try {
			const raw = localStorage.getItem(SCHEDULE_AUTH_KEY);
			if (!raw) return null;
			const data = JSON.parse(raw);
			if (data.username && data.password) {
				return { username: data.username, password: data.password };
			}
		} catch (e) {}
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
				p_module: "schedule",
				p_username: loginUser.trim(),
				p_password: loginPass
			});
			if (error) throw error;
			if (data === true) {
				const savedUser = loginUser.trim();
				const savedPass = loginPass;
				loggedIn = true;
				loginUser = "";
				loginPass = "";
				localStorage.setItem(SCHEDULE_AUTH_KEY, JSON.stringify({
					authenticated: true,
					username: savedUser,
					password: savedPass,
					timestamp: Date.now()
				}));
				loadSchedules();
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
		localStorage.removeItem(SCHEDULE_AUTH_KEY);
		schedules = [];
	}

	// ===== 日程管理 =====
	let schedules: Schedule[] = [];
	let schedulesLoading = false;
	let actionMessage = "";
	let showForm = false;
	let editingId: string | null = null;
	let submitting = false;

	// 表单字段
	let formTitle = "";
	let formDescription = "";
	let formDate = "";
	let formTime = "";
	let formLocation = "";
	let formStatus: "upcoming" | "completed" | "cancelled" = "upcoming";

	const STATUS_LABELS: Record<string, string> = {
		upcoming: "即将到来",
		completed: "已完成",
		cancelled: "已取消",
	};

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr + "T00:00:00");
		const weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
		return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, "0")}.${String(d.getDate()).padStart(2, "0")} ${weekdays[d.getDay()]}`;
	}

	function formatTime(timeStr: string | null): string {
		if (!timeStr) return "";
		return timeStr.slice(0, 5);
	}

	async function loadSchedules() {
		if (!supabase) return;
		schedulesLoading = true;
		try {
			const { data, error } = await supabase
				.from("schedules")
				.select("*")
				.order("schedule_date", { ascending: true })
				.order("schedule_time", { ascending: true })
				.limit(200);
			if (error) throw error;
			schedules = (data as Schedule[]) || [];
		} catch (e: any) {
			actionMessage = "加载失败：" + (e?.message || "未知错误");
		} finally {
			schedulesLoading = false;
		}
	}

	function resetForm() {
		formTitle = "";
		formDescription = "";
		formDate = "";
		formTime = "";
		formLocation = "";
		formStatus = "upcoming";
		editingId = null;
	}

	function openEditForm(s: Schedule) {
		editingId = s.id;
		formTitle = s.title;
		formDescription = s.description || "";
		formDate = s.schedule_date;
		formTime = s.schedule_time ? s.schedule_time.slice(0, 5) : "";
		formLocation = s.location || "";
		formStatus = s.status;
		showForm = true;
	}

	async function submitSchedule() {
		if (!supabase) return;
		if (!formTitle.trim()) {
			actionMessage = "请填写日程标题";
			return;
		}
		if (!formDate) {
			actionMessage = "请选择日程日期";
			return;
		}
		submitting = true;
		actionMessage = "";
		const wasEditing = !!editingId;
		try {
			const creds = getScheduleCredentials();
			if (!creds) {
				loggedIn = false;
				localStorage.removeItem(SCHEDULE_AUTH_KEY);
				actionMessage = "登录已过期，请重新登录";
				return;
			}

			if (editingId) {
				const { error } = await supabase.rpc("admin_update_schedule", {
					p_username: creds.username,
					p_password: creds.password,
					p_id: editingId,
					p_title: formTitle.trim(),
					p_description: formDescription.trim() || null,
					p_schedule_date: formDate,
					p_schedule_time: formTime || null,
					p_location: formLocation.trim() || null,
					p_status: formStatus,
					p_sort_order: null
				});
				if (error) throw error;
				actionMessage = "日程更新成功！";
			} else {
				const { error } = await supabase.rpc("admin_insert_schedule", {
					p_username: creds.username,
					p_password: creds.password,
					p_title: formTitle.trim(),
					p_description: formDescription.trim() || null,
					p_schedule_date: formDate,
					p_schedule_time: formTime || null,
					p_location: formLocation.trim() || null,
					p_status: formStatus,
					p_sort_order: 0
				});
				if (error) throw error;
				actionMessage = "日程发布成功！";
			}

			resetForm();
			showForm = false;
			loadSchedules();
		} catch (e: any) {
			actionMessage = e?.message || "保存失败";
		} finally {
			submitting = false;
		}
	}

	async function deleteSchedule(id: string) {
		if (!supabase) return;
		if (!confirm("确定删除这条日程吗？此操作不可撤销。")) return;
		try {
			const creds = getScheduleCredentials();
			if (!creds) {
				loggedIn = false;
				localStorage.removeItem(SCHEDULE_AUTH_KEY);
				actionMessage = "登录已过期，请重新登录";
				return;
			}
			const { error } = await supabase.rpc("admin_delete_schedule", {
				p_username: creds.username,
				p_password: creds.password,
				p_id: id
			});
			if (error) throw error;
			actionMessage = "已删除";
			schedules = schedules.filter(s => s.id !== id);
		} catch (e: any) {
			actionMessage = e?.message || "删除失败";
		}
	}

	async function toggleStatus(s: Schedule) {
		if (!supabase) return;
		const next = s.status === "upcoming" ? "completed" : "upcoming";
		try {
			const creds = getScheduleCredentials();
			if (!creds) {
				loggedIn = false;
				localStorage.removeItem(SCHEDULE_AUTH_KEY);
				actionMessage = "登录已过期，请重新登录";
				return;
			}
			const { error } = await supabase.rpc("admin_update_schedule_status", {
				p_username: creds.username,
				p_password: creds.password,
				p_id: s.id,
				p_status: next
			});
			if (error) throw error;
			const idx = schedules.findIndex(item => item.id === s.id);
			if (idx !== -1) {
				schedules[idx] = { ...schedules[idx], status: next };
				schedules = [...schedules];
			}
		} catch (e: any) {
			actionMessage = e?.message || "更新失败";
		}
	}

	onMount(() => {
		checkScheduleAuth();
		if (loggedIn) {
			loadSchedules();
		}
	});
</script>

<div class="admin-schedules">
	{#if !loggedIn}
		<!-- 日程管理独立登录 -->
		<div class="admin-login">
			<h2>日程管理登录</h2>
			<p class="admin-login-sub">使用日程管理员账号密码登录</p>

			{#if loginError}
				<div class="admin-error">{loginError}</div>
			{/if}

			<div class="admin-login-form">
				<div class="form-group">
					<label for="schedule-login-user">账号</label>
					<input
						id="schedule-login-user"
						type="text"
						bind:value={loginUser}
						placeholder="请输入管理员账号"
						on:keydown={(e) => e.key === "Enter" && handleLogin()}
					/>
				</div>
				<div class="form-group">
					<label for="schedule-login-pass">密码</label>
					<input
						id="schedule-login-pass"
						type="password"
						bind:value={loginPass}
						placeholder="请输入管理员密码"
						on:keydown={(e) => e.key === "Enter" && handleLogin()}
					/>
				</div>
			</div>

			<div class="admin-login-actions">
				<button class="admin-btn admin-btn-primary" on:click={handleLogin} disabled={loginLoading}>
					{#if loginLoading}验证中...{:else}登录{/if}
				</button>
			</div>
		</div>
	{:else}
		<!-- 管理面板 -->
		<div class="admin-panel">
			<div class="admin-panel-header">
				<div>
					<h2>日程管理</h2>
					<p class="admin-panel-sub">共 {schedules.length} 条日程</p>
				</div>
				<div class="admin-panel-actions">
					<button class="admin-btn admin-btn-primary" on:click={() => { if (showForm) { showForm = false; resetForm(); } else { showForm = true; } }}>
						{#if showForm}取消{:else}+ 写日程{/if}
					</button>
					<button class="admin-btn admin-btn-secondary" on:click={loadSchedules}>刷新</button>
					<button class="admin-btn admin-btn-danger" on:click={handleLogout}>退出</button>
				</div>
			</div>

			{#if actionMessage}
				<div class="admin-action-message">{actionMessage}</div>
			{/if}

			<!-- 添加/编辑表单 -->
			{#if showForm}
				<div class="schedule-form">
					<h3>{editingId ? "编辑日程" : "添加新日程"}</h3>

					<div class="form-row">
						<div class="form-group">
							<label>标题 *</label>
							<input type="text" bind:value={formTitle} placeholder="日程标题" />
						</div>
						<div class="form-group">
							<label>日期 *</label>
							<input type="date" bind:value={formDate} />
						</div>
						<div class="form-group">
							<label>时间</label>
							<input type="time" bind:value={formTime} />
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label>地点</label>
							<input type="text" bind:value={formLocation} placeholder="日程地点（可选）" />
						</div>
						<div class="form-group">
							<label>状态</label>
							<select bind:value={formStatus}>
								<option value="upcoming">即将到来</option>
								<option value="completed">已完成</option>
								<option value="cancelled">已取消</option>
							</select>
						</div>
					</div>

					<div class="form-group">
						<label>描述</label>
						<textarea bind:value={formDescription} placeholder="日程详细描述（可选）" rows="3"></textarea>
					</div>

					<div class="form-actions">
						<button class="admin-btn admin-btn-secondary" on:click={() => { showForm = false; resetForm(); }}>取消</button>
						<button class="admin-btn admin-btn-primary" on:click={submitSchedule} disabled={submitting}>
							{submitting ? "保存中..." : (editingId ? "保存修改" : "添加日程")}
						</button>
					</div>
				</div>
			{/if}

			<!-- 日程列表 -->
			<div class="schedule-list">
				{#if schedulesLoading}
					<div class="admin-loading">加载中...</div>
				{:else if schedules.length === 0}
					<div class="admin-empty">还没有日程，点击「写日程」创建第一条</div>
				{:else}
					{#each schedules as s (s.id)}
						<div class="schedule-item">
							<div class="schedule-item-date">
								<span class="schedule-item-day">{s.schedule_date.slice(8, 10)}</span>
								<span class="schedule-item-month">{s.schedule_date.slice(0, 7)}</span>
							</div>
							<div class="schedule-item-info">
								<h4>{s.title}</h4>
								<div class="schedule-item-meta">
									<span>{formatDate(s.schedule_date)}{s.schedule_time ? " " + formatTime(s.schedule_time) : ""}</span>
									{#if s.location}
										<span>{s.location}</span>
									{/if}
									<span class={`status-badge status-${s.status}`}>{STATUS_LABELS[s.status]}</span>
								</div>
								{#if s.description}
									<p class="schedule-item-desc">{s.description}</p>
								{/if}
							</div>
							<div class="schedule-item-actions">
								<button class="admin-btn admin-btn-secondary" on:click={() => toggleStatus(s)}>
									{s.status === "upcoming" ? "标记完成" : "标记未完成"}
								</button>
								<button class="admin-btn admin-btn-secondary" on:click={() => openEditForm(s)}>编辑</button>
								<button class="admin-btn admin-btn-danger" on:click={() => deleteSchedule(s.id)}>删除</button>
							</div>
						</div>
					{/each}
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.admin-schedules {
		font-family: inherit;
		color: #F1F3F8;
	}

	/* 登录 */
	.admin-login {
		max-width: 420px;
		margin: 4rem auto;
		padding: 2.5rem;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 16px;
		backdrop-filter: blur(12px);
	}
	.admin-login h2 {
		margin: 0 0 0.5rem;
		font-size: 1.4rem;
		font-weight: 600;
	}
	.admin-login-sub {
		margin: 0 0 1.5rem;
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.45);
	}
	.admin-error {
		padding: 0.6rem 0.9rem;
		margin-bottom: 1rem;
		background: rgba(255, 80, 80, 0.1);
		border: 1px solid rgba(255, 80, 80, 0.25);
		border-radius: 8px;
		color: #ff8a8a;
		font-size: 0.82rem;
	}
	.admin-login-form {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}
	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}
	.form-group label {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.5);
		letter-spacing: 0.02em;
	}
	.form-group input,
	.form-group textarea,
	.form-group select {
		padding: 0.6rem 0.8rem;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		color: #F1F3F8;
		font-size: 0.88rem;
		font-family: inherit;
		outline: none;
		transition: border-color 0.2s;
	}
	.form-group input:focus,
	.form-group textarea:focus,
	.form-group select:focus {
		border-color: rgba(155, 140, 255, 0.5);
	}
	.form-group input::placeholder,
	.form-group textarea::placeholder {
		color: rgba(255, 255, 255, 0.25);
	}
	.admin-login-actions {
		display: flex;
		justify-content: flex-end;
	}

	/* 按钮 */
	.admin-btn {
		padding: 0.5rem 1.1rem;
		border: none;
		border-radius: 8px;
		font-size: 0.82rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		font-family: inherit;
		text-decoration: none;
		display: inline-flex;
		align-items: center;
	}
	.admin-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.admin-btn-primary {
		background: linear-gradient(135deg, #7c6fff, #5b4fd4);
		color: #fff;
	}
	.admin-btn-primary:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 16px rgba(124, 111, 255, 0.3);
	}
	.admin-btn-secondary {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.75);
		border: 1px solid rgba(255, 255, 255, 0.1);
	}
	.admin-btn-secondary:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.1);
	}
	.admin-btn-danger {
		background: rgba(255, 80, 80, 0.12);
		color: #ff8a8a;
		border: 1px solid rgba(255, 80, 80, 0.2);
	}
	.admin-btn-danger:hover:not(:disabled) {
		background: rgba(255, 80, 80, 0.2);
	}

	/* 管理面板 */
	.admin-panel {
		padding: 2rem 1.5rem;
		max-width: 1100px;
		margin: 0 auto;
	}
	.admin-panel-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
		gap: 1rem;
	}
	.admin-panel-header h2 {
		margin: 0 0 0.25rem;
		font-size: 1.5rem;
		font-weight: 600;
	}
	.admin-panel-sub {
		margin: 0;
		font-size: 0.85rem;
		color: rgba(255, 255, 255, 0.4);
	}
	.admin-panel-actions {
		display: flex;
		gap: 0.6rem;
		flex-wrap: wrap;
	}
	.admin-action-message {
		padding: 0.7rem 1rem;
		margin-bottom: 1.25rem;
		background: rgba(124, 111, 255, 0.1);
		border: 1px solid rgba(124, 111, 255, 0.25);
		border-radius: 8px;
		color: #b8adff;
		font-size: 0.85rem;
	}

	/* 表单 */
	.schedule-form {
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		background: rgba(255, 255, 255, 0.025);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 12px;
	}
	.schedule-form h3 {
		margin: 0 0 1.25rem;
		font-size: 1.1rem;
		font-weight: 600;
	}
	.form-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: 1rem;
		margin-bottom: 1rem;
	}
	.schedule-form .form-group {
		margin-bottom: 1rem;
	}
	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
		margin-top: 1.25rem;
	}

	/* 列表 */
	.schedule-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.admin-loading,
	.admin-empty {
		text-align: center;
		padding: 3rem 1rem;
		color: rgba(255, 255, 255, 0.35);
		font-size: 0.9rem;
	}
	.schedule-item {
		display: flex;
		gap: 1.25rem;
		padding: 1.1rem;
		background: rgba(255, 255, 255, 0.025);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 12px;
		align-items: center;
		transition: border-color 0.2s;
	}
	.schedule-item:hover {
		border-color: rgba(155, 140, 255, 0.25);
	}
	.schedule-item-date {
		width: 72px;
		flex-shrink: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.1rem;
		padding: 0.6rem 0;
		background: rgba(155, 140, 255, 0.06);
		border: 1px solid rgba(155, 140, 255, 0.15);
		border-radius: 10px;
	}
	.schedule-item-day {
		font-size: 1.35rem;
		font-weight: 700;
		color: #F5F7FF;
		line-height: 1.1;
	}
	.schedule-item-month {
		font-size: 0.68rem;
		color: rgba(155, 140, 255, 0.7);
		letter-spacing: 0.05em;
	}
	.schedule-item-info {
		flex: 1;
		min-width: 0;
	}
	.schedule-item-info h4 {
		margin: 0 0 0.35rem;
		font-size: 1rem;
		font-weight: 600;
	}
	.schedule-item-meta {
		display: flex;
		gap: 0.85rem;
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.4);
		margin-bottom: 0.35rem;
		flex-wrap: wrap;
	}
	.status-badge {
		padding: 0.1rem 0.5rem;
		border-radius: 4px;
		font-size: 0.7rem;
	}
	.status-upcoming {
		background: rgba(155, 140, 255, 0.12);
		color: #b8adff;
	}
	.status-completed {
		background: rgba(80, 220, 140, 0.12);
		color: #6ee7a8;
	}
	.status-cancelled {
		background: rgba(255, 120, 120, 0.1);
		color: rgba(255, 138, 138, 0.75);
	}
	.schedule-item-desc {
		margin: 0;
		font-size: 0.8rem;
		color: rgba(255, 255, 255, 0.45);
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
	.schedule-item-actions {
		display: flex;
		gap: 0.5rem;
		flex-shrink: 0;
		flex-wrap: wrap;
		justify-content: flex-end;
	}

	@media (max-width: 768px) {
		.admin-panel {
			padding: 1.25rem 1rem;
		}
		.schedule-item {
			flex-direction: column;
			align-items: stretch;
		}
		.schedule-item-date {
			width: fit-content;
			flex-direction: row;
			gap: 0.5rem;
			padding: 0.4rem 0.9rem;
		}
		.schedule-item-actions {
			justify-content: flex-start;
		}
		.admin-login {
			margin: 2rem 1rem;
			padding: 1.5rem;
		}
	}
</style>
