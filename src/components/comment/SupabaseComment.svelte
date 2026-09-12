<script lang="ts">
	import { onMount } from "svelte";
	import { supabase } from "@/lib/supabase";

	export let postPath: string = "";
	export let title: string = "评论";

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

	let comments: Comment[] = [];
	let loading = true;
	let submitting = false;
	let submitMessage = "";
	let submitError = false;

	// 表单
	let nickname = "";
	let email = "";
	let content = "";
	let replyTo: Comment | null = null;

	// 生成头像（基于昵称的 identicon 风格颜色）
	function getAvatarColor(name: string): string {
		const colors = [
			"#6366f1", "#8b5cf6", "#a855f7", "#d946ef",
			"#ec4899", "#f43f5e", "#ef4444", "#f97316",
			"#f59e0b", "#eab308", "#84cc16", "#22c55e",
			"#10b981", "#14b8a6", "#06b6d4", "#0ea5e9",
			"#3b82f6",
		];
		let hash = 0;
		for (let i = 0; i < name.length; i++) {
			hash = name.charCodeAt(i) + ((hash << 5) - hash);
		}
		return colors[Math.abs(hash) % colors.length];
	}

	function getInitial(name: string): string {
		return name.charAt(0).toUpperCase();
	}

	function formatDate(dateStr: string): string {
		const d = new Date(dateStr);
		const now = new Date();
		const diff = now.getTime() - d.getTime();
		const minutes = Math.floor(diff / 60000);
		const hours = Math.floor(diff / 3600000);
		const days = Math.floor(diff / 86400000);

		if (minutes < 1) return "刚刚";
		if (minutes < 60) return `${minutes} 分钟前`;
		if (hours < 24) return `${hours} 小时前`;
		if (days < 30) return `${days} 天前`;
		return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
	}

	// 构建树形评论
	function buildTree(flatComments: Comment[]): Comment[] {
		const map = new Map<string, Comment & { children?: Comment[] }>();
		const roots: (Comment & { children?: Comment[] })[] = [];

		for (const c of flatComments) {
			map.set(c.id, { ...c, children: [] });
		}
		for (const c of flatComments) {
			const node = map.get(c.id)!;
			if (c.parent_id && map.has(c.parent_id)) {
				map.get(c.parent_id)!.children!.push(node);
			} else {
				roots.push(node);
			}
		}
		return roots;
	}

	let treeComments: (Comment & { children?: Comment[] })[] = [];

	async function loadComments() {
		if (!supabase) {
			loading = false;
			return;
		}
		loading = true;
		try {
			const { data, error } = await supabase
				.from("comments")
				.select("*")
				.eq("post_path", postPath)
				.eq("status", "approved")
				.order("created_at", { ascending: true });

			if (error) throw error;
			comments = (data as Comment[]) || [];
			treeComments = buildTree(comments);
		} catch (e) {
			console.error("加载评论失败:", e);
			comments = [];
			treeComments = [];
		} finally {
			loading = false;
		}
	}

	async function submitComment() {
		if (!nickname.trim() || !content.trim()) {
			submitMessage = "请填写昵称和评论内容";
			submitError = true;
			return;
		}
		if (!supabase) {
			submitMessage = "评论系统未配置";
			submitError = true;
			return;
		}

		submitting = true;
		submitMessage = "";
		submitError = false;

		try {
			const { error } = await supabase.from("comments").insert({
				nickname: nickname.trim(),
				email: email.trim() || null,
				content: content.trim(),
				post_path: postPath,
				parent_id: replyTo?.id || null,
				status: "approved",
			});

			if (error) throw error;

			submitMessage = "评论发表成功";
			submitError = false;
			content = "";
			replyTo = null;
			// 重新加载评论列表
			loadComments();
		} catch (e: any) {
			console.error("提交评论失败:", e);
			submitMessage = e?.message || "提交失败，请稍后重试";
			submitError = true;
		} finally {
			submitting = false;
		}
	}

	function startReply(comment: Comment) {
		replyTo = comment;
		// 滚动到表单
		const formEl = document.getElementById("supabase-comment-form");
		if (formEl) formEl.scrollIntoView({ behavior: "smooth", block: "center" });
	}

	function cancelReply() {
		replyTo = null;
	}

	onMount(() => {
		loadComments();
	});
</script>

<div class="sb-comments" id="supabase-comments">
	<!-- 评论标题 -->
	<div class="sb-comments-header">
		<div class="sb-comments-title">
			<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="sb-comments-icon">
				<path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
			</svg>
			<span>{title}</span>
			{#if !loading}
				<span class="sb-comments-count">{comments.length}</span>
			{/if}
		</div>
		<a href="/admin/comments" class="sb-admin-link" target="_blank" rel="noopener">
			<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="sb-admin-icon">
				<path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
				<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
			</svg>
			评论管理
		</a>
	</div>

	<!-- 评论表单 -->
	<div class="sb-comment-form" id="supabase-comment-form">
		{#if replyTo}
			<div class="sb-reply-notice">
				<span>回复 <strong>{replyTo.nickname}</strong></span>
				<button class="sb-reply-cancel" on:click={cancelReply}>取消</button>
			</div>
		{/if}

		<div class="sb-form-row">
			<input
				type="text"
				bind:value={nickname}
				placeholder="昵称 *"
				class="sb-form-input"
				maxlength={50}
			/>
			<input
				type="email"
				bind:value={email}
				placeholder="邮箱（可选，不会公开）"
				class="sb-form-input"
				maxlength={100}
			/>
		</div>

		<textarea
			bind:value={content}
			placeholder="写下你的评论..."
			class="sb-form-textarea"
			rows={3}
			maxlength={1000}
		></textarea>

		{#if submitMessage}
			<div class="sb-form-message" class:error={submitError}>
				{submitMessage}
			</div>
		{/if}

		<div class="sb-form-actions">
			<span class="sb-form-hint">支持 Markdown 纯文本</span>
			<button
				class="sb-form-submit"
				on:click={submitComment}
				disabled={submitting || !supabase}
			>
				{#if submitting}提交中...{:else}发表评论{/if}
			</button>
		</div>
	</div>

	<!-- 评论列表 -->
	<div class="sb-comments-list">
		{#if loading}
			<div class="sb-loading">
				<div class="sb-loading-spinner"></div>
				<span>加载评论中...</span>
			</div>
		{:else if treeComments.length === 0}
			<div class="sb-empty">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" class="sb-empty-icon">
					<path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
				</svg>
				<p>还没有评论，来发表第一条吧</p>
			</div>
		{:else}
			{#each treeComments as comment (comment.id)}
				<div class="sb-comment-item">
					<div class="sb-comment-avatar" style="background: {getAvatarColor(comment.nickname)}">
						{getInitial(comment.nickname)}
					</div>
					<div class="sb-comment-body">
						<div class="sb-comment-meta">
							<span class="sb-comment-nickname">{comment.nickname}</span>
							<span class="sb-comment-date">{formatDate(comment.created_at)}</span>
						</div>
						<div class="sb-comment-content">{comment.content}</div>
						<div class="sb-comment-actions">
							<button class="sb-comment-reply" on:click={() => startReply(comment)}>
								回复
							</button>
						</div>

						{#if comment.children && comment.children.length > 0}
							<div class="sb-comment-replies">
								{#each comment.children as reply (reply.id)}
									<div class="sb-comment-item sb-comment-item--reply">
										<div class="sb-comment-avatar sb-comment-avatar--small" style="background: {getAvatarColor(reply.nickname)}">
											{getInitial(reply.nickname)}
										</div>
										<div class="sb-comment-body">
											<div class="sb-comment-meta">
												<span class="sb-comment-nickname">{reply.nickname}</span>
												<span class="sb-comment-date">{formatDate(reply.created_at)}</span>
											</div>
											<div class="sb-comment-content">{reply.content}</div>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			{/each}
		{/if}
	</div>
</div>

<style>
	.sb-comments {
		font-family: inherit;
		color: var(--text-90, #e6edf3);
	}

	.sb-comments-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
		padding-bottom: 1rem;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		gap: 1rem;
		flex-wrap: wrap;
	}

	.sb-comments-title {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.sb-comments-icon {
		width: 1.25rem;
		height: 1.25rem;
		color: var(--primary, #6366f1);
	}

	.sb-comments-count {
		font-size: 0.8rem;
		font-weight: 400;
		color: var(--content-meta, #8b949e);
		background: rgba(255, 255, 255, 0.05);
		padding: 0.15rem 0.5rem;
		border-radius: 999px;
	}

	.sb-admin-link {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.35rem 0.75rem;
		background: rgba(99, 102, 241, 0.1);
		border: 1px solid rgba(99, 102, 241, 0.2);
		border-radius: 999px;
		color: var(--primary, #6366f1);
		font-size: 0.75rem;
		font-weight: 500;
		text-decoration: none;
		transition: all 0.2s;
	}

	.sb-admin-link:hover {
		background: rgba(99, 102, 241, 0.2);
		border-color: rgba(99, 102, 241, 0.4);
	}

	.sb-admin-icon {
		width: 0.85rem;
		height: 0.85rem;
	}

	/* 表单 */
	.sb-comment-form {
		margin-bottom: 2rem;
		padding: 1.25rem;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 12px;
	}

	.sb-reply-notice {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.75rem;
		padding: 0.5rem 0.75rem;
		background: rgba(99, 102, 241, 0.1);
		border-radius: 8px;
		font-size: 0.85rem;
		color: var(--primary, #6366f1);
	}

	.sb-reply-cancel {
		background: none;
		border: none;
		color: var(--content-meta, #8b949e);
		cursor: pointer;
		font-size: 0.8rem;
	}

	.sb-reply-cancel:hover {
		color: var(--text-90, #e6edf3);
	}

	.sb-form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.sb-form-input,
	.sb-form-textarea {
		width: 100%;
		padding: 0.6rem 0.85rem;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 8px;
		color: var(--text-90, #e6edf3);
		font-size: 0.9rem;
		font-family: inherit;
		resize: vertical;
		transition: border-color 0.2s;
		box-sizing: border-box;
	}

	.sb-form-input:focus,
	.sb-form-textarea:focus {
		outline: none;
		border-color: var(--primary, #6366f1);
	}

	.sb-form-input::placeholder,
	.sb-form-textarea::placeholder {
		color: var(--content-meta, #6e7681);
	}

	.sb-form-textarea {
		margin-bottom: 0.75rem;
	}

	.sb-form-message {
		margin-bottom: 0.75rem;
		padding: 0.5rem 0.75rem;
		border-radius: 8px;
		font-size: 0.85rem;
		background: rgba(16, 185, 129, 0.1);
		color: #10b981;
	}

	.sb-form-message.error {
		background: rgba(239, 68, 68, 0.1);
		color: #ef4444;
	}

	.sb-form-actions {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.sb-form-hint {
		font-size: 0.8rem;
		color: var(--content-meta, #6e7681);
	}

	.sb-form-submit {
		padding: 0.55rem 1.25rem;
		background: var(--primary, #6366f1);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 500;
		cursor: pointer;
		transition: opacity 0.2s;
	}

	.sb-form-submit:hover:not(:disabled) {
		opacity: 0.9;
	}

	.sb-form-submit:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* 评论列表 */
	.sb-comments-list {
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
	}

	.sb-loading,
	.sb-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		color: var(--content-meta, #8b949e);
		gap: 0.75rem;
	}

	.sb-loading-spinner {
		width: 1.5rem;
		height: 1.5rem;
		border: 2px solid rgba(255, 255, 255, 0.1);
		border-top-color: var(--primary, #6366f1);
		border-radius: 50%;
		animation: sb-spin 0.8s linear infinite;
	}

	@keyframes sb-spin {
		to { transform: rotate(360deg); }
	}

	.sb-empty-icon {
		width: 2.5rem;
		height: 2.5rem;
		opacity: 0.3;
	}

	.sb-comment-item {
		display: flex;
		gap: 0.85rem;
	}

	.sb-comment-avatar {
		flex-shrink: 0;
		width: 2.5rem;
		height: 2.5rem;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-weight: 600;
		font-size: 1rem;
	}

	.sb-comment-avatar--small {
		width: 2rem;
		height: 2rem;
		font-size: 0.85rem;
	}

	.sb-comment-body {
		flex: 1;
		min-width: 0;
	}

	.sb-comment-meta {
		display: flex;
		align-items: baseline;
		gap: 0.6rem;
		margin-bottom: 0.35rem;
	}

	.sb-comment-nickname {
		font-weight: 600;
		font-size: 0.9rem;
		color: var(--text-90, #e6edf3);
	}

	.sb-comment-date {
		font-size: 0.75rem;
		color: var(--content-meta, #6e7681);
	}

	.sb-comment-content {
		font-size: 0.9rem;
		line-height: 1.7;
		color: var(--text-70, #c9d1d9);
		word-break: break-word;
		white-space: pre-wrap;
	}

	.sb-comment-actions {
		margin-top: 0.4rem;
	}

	.sb-comment-reply {
		background: none;
		border: none;
		color: var(--content-meta, #6e7681);
		font-size: 0.8rem;
		cursor: pointer;
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
		transition: color 0.2s;
	}

	.sb-comment-reply:hover {
		color: var(--primary, #6366f1);
	}

	.sb-comment-replies {
		margin-top: 1rem;
		padding-left: 1rem;
		border-left: 2px solid rgba(255, 255, 255, 0.06);
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.sb-comment-item--reply {
		display: flex;
		gap: 0.6rem;
	}

	@media (max-width: 640px) {
		.sb-form-row {
			grid-template-columns: 1fr;
		}

		.sb-comment-avatar {
			width: 2rem;
			height: 2rem;
			font-size: 0.85rem;
		}
	}
</style>
