<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	interface Comment {
		id: string;
		nickname: string;
		email: string | null;
		website: string | null;
		content: string;
		avatar: string | null;
		parent_id: string | null;
		post_path: string | null;
		status: string;
		created_at: string;
	}

	let loggedIn = false;
	let loading = false;
	let comments: Comment[] = [];
	let commentsLoading = false;
	let email = "";
	let password = "";
	let loginError = "";
	let actionMessage = "";
	let filterStatus = "all";

	async function handleLogin() {
		if (!supabase) {
			loginError = "Supabase 未配置";
			return;
		}
		if (!email || !password) {
			loginError = "请输入邮箱和密码";
			return;
		}

		loading = true;
		loginError = "";

		try {
			const { data, error } = await supabase.auth.signInWithPassword({
				email: email.trim(),
				password: password,
			});

			if (error) throw error;
			if (data.user) {
				loggedIn = true;
				loadComments();
			}
		} catch (e: any) {
			loginError = e?.message || "登录失败";
		} finally {
			loading = false;
		}
	}

	async function handleLogout() {
		if (!supabase) return;
		await supabase.auth.signOut();
		loggedIn = false;
		comments = [];
		email = "";
		password = "";
	}

	async function loadComments() {
		if (!supabase) return;
		commentsLoading = true;
		try {
			let query = supabase
				.from("comments")
				.select("*")
				.order("created_at", { ascending: false })
				.limit(200);

			if (filterStatus !== "all") {
				query = query.eq("status", filterStatus);
			}

			const { data, error } = await query;
			if (error) throw error;
			comments = (data as Comment[]) || [];
		} catch (e) {
			console.error("加载评论失败:", e);
			actionMessage = "加载评论失败";
		} finally {
			commentsLoading = false;
		}
	}

	async function approveComment(id: string) {
		if (!supabase) return;
		try {
			const { error } = await supabase
				.from("comments")
				.update({ status: "approved" })
				.eq("id", id);
			if (error) throw error;
			actionMessage = "评论已通过审核";
			loadComments();
		} catch (e: any) {
			actionMessage = e?.message || "操作失败";
		}
	}

	async function deleteComment(id: string) {
		if (!supabase) return;
		if (!confirm("确定删除这条评论吗？此操作不可撤销。")) return;
		try {
			const { error } = await supabase.from("comments").delete().eq("id", id);
			if (error) throw error;
			actionMessage = "评论已删除";
			loadComments();
		} catch (e: any) {
			actionMessage = e?.message || "删除失败";
		}
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
	}

	function getStatusBadge(status: string): { text: string; class: string } {
		switch (status) {
			case "approved":
				return { text: "已通过", class: "status-approved" };
			case "pending":
				return { text: "待审核", class: "status-pending" };
			case "hidden":
				return { text: "已隐藏", class: "status-hidden" };
			default:
				return { text: status, class: "status-pending" };
		}
	}

	$: filteredComments = filterStatus === "all" ? comments : comments.filter((c) => c.status === filterStatus);
	$: pendingCount = comments.filter((c) => c.status === "pending").length;
	$: approvedCount = comments.filter((c) => c.status === "approved").length;

	onMount(async () => {
		if (!supabase) return;
		// 检查是否已登录
		const { data } = await supabase.auth.getSession();
		if (data.session) {
			loggedIn = true;
			loadComments();
		}
	});
</script>

<div class="admin-comments">
	{#if !loggedIn}
		<!-- 登录表单 -->
		<div class="admin-login">
			<h2>评论管理登录</h2>
			<p class="admin-login-sub">使用管理员账号登录以管理评论</p>

			{#if loginError}
				<div class="admin-error">{loginError}</div>
			{/if}

			<div class="admin-form-group">
				<label for="admin-email">邮箱</label>
				<input
					id="admin-email"
					type="email"
					bind:value={email}
					placeholder="admin@example.com"
					on:keydown={(e) => e.key === "Enter" && handleLogin()}
				/>
			</div>

			<div class="admin-form-group">
				<label for="admin-password">密码</label>
				<input
					id="admin-password"
					type="password"
					bind:value={password}
					placeholder="••••••••"
					on:keydown={(e) => e.key === "Enter" && handleLogin()}
				/>
			</div>

			<button class="admin-login-btn" on:click={handleLogin} disabled={loading}>
				{#if loading}登录中...{:else}登录{/if}
			</button>
		</div>
	{:else}
		<!-- 评论管理面板 -->
		<div class="admin-panel">
			<div class="admin-panel-header">
				<div>
					<h2>评论管理</h2>
					<p class="admin-panel-sub">共 {comments.length} 条评论 · 待审核 {pendingCount} · 已通过 {approvedCount}</p>
				</div>
				<div class="admin-panel-actions">
					<button class="admin-btn admin-btn-secondary" on:click={loadComments}>刷新</button>
					<button class="admin-btn admin-btn-danger" on:click={handleLogout}>退出登录</button>
				</div>
			</div>

			{#if actionMessage}
				<div class="admin-action-message">{actionMessage}</div>
			{/if}

			<!-- 筛选 -->
			<div class="admin-filter">
				<button
					class="admin-filter-btn"
					class:active={filterStatus === "all"}
					on:click={() => { filterStatus = "all"; }}
				>全部 ({comments.length})</button>
				<button
					class="admin-filter-btn"
					class:active={filterStatus === "pending"}
					on:click={() => { filterStatus = "pending"; }}
				>待审核 ({pendingCount})</button>
				<button
					class="admin-filter-btn"
					class:active={filterStatus === "approved"}
					on:click={() => { filterStatus = "approved"; }}
				>已通过 ({approvedCount})</button>
			</div>

			<!-- 评论列表 -->
			{#if commentsLoading}
				<div class="admin-loading">加载中...</div>
			{:else if filteredComments.length === 0}
				<div class="admin-empty">暂无评论</div>
			{:else}
				<div class="admin-comment-list">
					{#each filteredComments as comment (comment.id)}
						<div class="admin-comment-item">
							<div class="admin-comment-header">
								<div class="admin-comment-user">
									<span class="admin-comment-nickname">{comment.nickname}</span>
									{#if comment.email}
										<span class="admin-comment-email">{comment.email}</span>
									{/if}
									<span class="admin-comment-date">{formatDate(comment.created_at)}</span>
								</div>
								<div class="admin-comment-meta">
									{#if comment.post_path}
										<span class="admin-comment-path">{comment.post_path}</span>
									{/if}
									<span class="admin-status-badge {getStatusBadge(comment.status).class}">
										{getStatusBadge(comment.status).text}
									</span>
								</div>
							</div>
							<div class="admin-comment-content">{comment.content}</div>
							<div class="admin-comment-actions">
								{#if comment.status === "pending"}
									<button class="admin-btn admin-btn-success" on:click={() => approveComment(comment.id)}>
										通过审核
									</button>
								{/if}
								<button class="admin-btn admin-btn-danger" on:click={() => deleteComment(comment.id)}>
									删除
								</button>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.admin-comments {
		font-family: inherit;
		color: #f1f5f9;
		max-width: 900px;
		margin: 0 auto;
		padding: 2rem 1rem;
	}

	/* 登录表单 */
	.admin-login {
		max-width: 420px;
		margin: 4rem auto;
		padding: 2.5rem 2rem;
		background: rgba(15, 23, 42, 0.85);
		border: 1px solid rgba(99, 102, 241, 0.2);
		border-radius: 16px;
		backdrop-filter: blur(10px);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
	}

	.admin-login h2 {
		font-size: 1.4rem;
		font-weight: 600;
		margin: 0 0 0.5rem 0;
		color: #f1f5f9;
	}

	.admin-login-sub {
		font-size: 0.85rem;
		color: #94a3b8;
		margin: 0 0 1.5rem 0;
	}

	.admin-error {
		padding: 0.6rem 0.85rem;
		background: rgba(239, 68, 68, 0.15);
		color: #f87171;
		border: 1px solid rgba(239, 68, 68, 0.3);
		border-radius: 8px;
		font-size: 0.85rem;
		margin-bottom: 1rem;
	}

	.admin-form-group {
		margin-bottom: 1.25rem;
	}

	.admin-form-group label {
		display: block;
		font-size: 0.8rem;
		color: #cbd5e1;
		margin-bottom: 0.5rem;
		font-weight: 500;
		letter-spacing: 0.02em;
	}

	.admin-form-group input {
		width: 100%;
		padding: 0.75rem 1rem;
		background: rgba(30, 41, 59, 0.8);
		border: 1px solid rgba(148, 163, 184, 0.25);
		border-radius: 10px;
		color: #f1f5f9;
		font-size: 0.95rem;
		box-sizing: border-box;
		transition: all 0.2s;
	}

	.admin-form-group input::placeholder {
		color: #64748b;
	}

	.admin-form-group input:focus {
		outline: none;
		border-color: #6366f1;
		background: rgba(30, 41, 59, 0.95);
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
	}

	.admin-login-btn {
		width: 100%;
		padding: 0.85rem;
		background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		margin-top: 0.5rem;
	}

	.admin-login-btn:hover:not(:disabled) {
		opacity: 0.92;
		transform: translateY(-1px);
		box-shadow: 0 4px 16px rgba(99, 102, 241, 0.4);
	}

	.admin-login-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* 管理面板 */
	.admin-panel-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.admin-panel-header h2 {
		font-size: 1.4rem;
		font-weight: 600;
		margin: 0 0 0.3rem 0;
		color: #f1f5f9;
	}

	.admin-panel-sub {
		font-size: 0.85rem;
		color: #94a3b8;
		margin: 0;
	}

	.admin-panel-actions {
		display: flex;
		gap: 0.5rem;
	}

	.admin-action-message {
		padding: 0.6rem 0.85rem;
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border: 1px solid rgba(16, 185, 129, 0.3);
		border-radius: 8px;
		font-size: 0.85rem;
		margin-bottom: 1rem;
	}

	/* 筛选 */
	.admin-filter {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
	}

	.admin-filter-btn {
		padding: 0.4rem 0.85rem;
		background: rgba(30, 41, 59, 0.6);
		border: 1px solid rgba(148, 163, 184, 0.15);
		border-radius: 999px;
		color: #94a3b8;
		font-size: 0.8rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.admin-filter-btn:hover {
		color: #e2e8f0;
		border-color: rgba(148, 163, 184, 0.3);
	}

	.admin-filter-btn.active {
		background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
		color: white;
		border-color: transparent;
	}

	/* 评论列表 */
	.admin-loading,
	.admin-empty {
		text-align: center;
		padding: 3rem;
		color: #94a3b8;
	}

	.admin-comment-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.admin-comment-item {
		padding: 1.25rem;
		background: rgba(15, 23, 42, 0.6);
		border: 1px solid rgba(148, 163, 184, 0.12);
		border-radius: 12px;
		transition: border-color 0.2s;
	}

	.admin-comment-item:hover {
		border-color: rgba(99, 102, 241, 0.3);
	}

	.admin-comment-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.75rem;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.admin-comment-user {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		flex-wrap: wrap;
	}

	.admin-comment-nickname {
		font-weight: 600;
		font-size: 0.9rem;
		color: #f1f5f9;
	}

	.admin-comment-email {
		font-size: 0.75rem;
		color: #64748b;
	}

	.admin-comment-date {
		font-size: 0.75rem;
		color: #64748b;
	}

	.admin-comment-meta {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.admin-comment-path {
		font-size: 0.75rem;
		color: #a5b4fc;
		background: rgba(99, 102, 241, 0.15);
		padding: 0.15rem 0.5rem;
		border-radius: 4px;
		font-family: monospace;
	}

	.admin-status-badge {
		font-size: 0.7rem;
		padding: 0.15rem 0.5rem;
		border-radius: 999px;
		font-weight: 500;
	}

	.status-approved {
		background: rgba(16, 185, 129, 0.15);
		color: #10b981;
	}

	.status-pending {
		background: rgba(245, 158, 11, 0.15);
		color: #f59e0b;
	}

	.status-hidden {
		background: rgba(107, 114, 128, 0.15);
		color: #6b7280;
	}

	.admin-comment-content {
		font-size: 0.9rem;
		line-height: 1.7;
		color: #cbd5e1;
		white-space: pre-wrap;
		word-break: break-word;
		margin-bottom: 0.75rem;
	}

	.admin-comment-actions {
		display: flex;
		gap: 0.5rem;
	}

	.admin-btn {
		padding: 0.4rem 0.85rem;
		border: none;
		border-radius: 8px;
		font-size: 0.8rem;
		cursor: pointer;
		transition: all 0.2s;
		font-weight: 500;
	}

	.admin-btn:hover {
		opacity: 0.85;
		transform: translateY(-1px);
	}

	.admin-btn-secondary {
		background: rgba(51, 65, 85, 0.8);
		color: #e2e8f0;
		border: 1px solid rgba(148, 163, 184, 0.2);
	}

	.admin-btn-danger {
		background: rgba(239, 68, 68, 0.15);
		color: #f87171;
		border: 1px solid rgba(239, 68, 68, 0.3);
	}

	.admin-btn-success {
		background: rgba(16, 185, 129, 0.15);
		color: #34d399;
		border: 1px solid rgba(16, 185, 129, 0.3);
	}

	@media (max-width: 640px) {
		.admin-comments {
			padding: 1rem;
		}

		.admin-comment-header {
			flex-direction: column;
		}
	}
</style>
