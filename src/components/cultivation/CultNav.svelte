<script lang="ts">
	import { onMount } from "svelte";
	import Icon from "@iconify/svelte";
	import { authStore, initAuth, logout, isAdmin, isOwner } from "@/stores/cultivationAuth";
	import { updateMyUsername, updateMyAvatar, changePassword } from "@/services/cultivation";

	let activeNav = "home";
	let showProfileModal = false;
	let newUsername = "";
	let usernameError = "";
	let isSaving = false;

	// 头像上传
	let avatarFileInput: HTMLInputElement | null = null;
	let isUploadingAvatar = false;
	let avatarError = "";

	// 修改密码
	let showPasswordForm = false;
	let oldPassword = "";
	let newPassword = "";
	let passwordError = "";
	let isChangingPassword = false;

	onMount(() => {
		initAuth();
		const path = window.location.pathname;
		if (path.includes("/tasks")) activeNav = "tasks";
		else if (path.includes("/my-tasks")) activeNav = "my-tasks";
		else if (path.includes("/shop")) activeNav = "shop";
		else if (path.includes("/transactions")) activeNav = "transactions";
		else if (path.includes("/transfer")) activeNav = "transfer";
		else if (path.includes("/admin")) activeNav = "admin";
	});

	async function handleLogout() {
		await logout();
		window.location.href = "/cultivation/login/";
	}

	function openProfileModal() {
		newUsername = $authStore.profile?.username || "";
		usernameError = "";
		avatarError = "";
		showPasswordForm = false;
		oldPassword = "";
		newPassword = "";
		passwordError = "";
		showProfileModal = true;
	}

	function closeProfileModal() {
		showProfileModal = false;
	}

	async function handleSaveUsername() {
		const trimmed = newUsername.trim();

		if (!trimmed) {
			usernameError = "道号不能为空";
			return;
		}

		if (trimmed.length < 2) {
			usernameError = "道号至少 2 个字符";
			return;
		}

		if (trimmed === $authStore.profile?.username) {
			usernameError = "道号未改变";
			return;
		}

		isSaving = true;
		usernameError = "";

		const result = await updateMyUsername(trimmed);
		if (result.success) {
			showProfileModal = false;
		} else {
			usernameError = result.error || "保存失败";
		}

		isSaving = false;
	}

	// 头像压缩到 100KB 以内
	function compressImage(file: File): Promise<string> {
		return new Promise((resolve, reject) => {
			const reader = new FileReader();
			reader.onload = (e) => {
				const img = new Image();
				img.onload = () => {
					// 计算缩放比例，最大边长 512px
					let width = img.width;
					let height = img.height;
					const maxSize = 512;
					if (width > maxSize || height > maxSize) {
						if (width > height) {
							height = (height / width) * maxSize;
							width = maxSize;
						} else {
							width = (width / height) * maxSize;
							height = maxSize;
						}
					}

					const canvas = document.createElement("canvas");
					canvas.width = width;
					canvas.height = height;
					const ctx = canvas.getContext("2d");
					if (!ctx) {
						reject(new Error("Canvas 不支持"));
						return;
					}
					ctx.drawImage(img, 0, 0, width, height);

					// 逐步降低质量直到 <= 100KB
					let quality = 0.9;
					const targetSize = 100 * 1024; // 100KB

					function tryCompress() {
						const dataUrl = canvas.toDataURL("image/jpeg", quality);
						const size = Math.round((dataUrl.length - "data:image/jpeg;base64,".length) * 3 / 4);
						if (size <= targetSize || quality <= 0.1) {
							resolve(dataUrl);
						} else {
							quality -= 0.1;
							tryCompress();
						}
					}
					tryCompress();
				};
				img.onerror = () => reject(new Error("图片加载失败"));
				img.src = e.target?.result as string;
			};
			reader.onerror = () => reject(new Error("文件读取失败"));
			reader.readAsDataURL(file);
		});
	}

	async function handleAvatarChange(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;

		if (!file.type.startsWith("image/")) {
			avatarError = "请选择图片文件";
			return;
		}

		isUploadingAvatar = true;
		avatarError = "";

		try {
			const compressedDataUrl = await compressImage(file);
			const result = await updateMyAvatar(compressedDataUrl);
			if (result.success) {
				// 刷新 authStore 中的 profile
				await initAuth();
			} else {
				avatarError = result.error || "上传失败";
			}
		} catch (e: any) {
			avatarError = e?.message || "压缩失败";
		}

		isUploadingAvatar = false;
		if (input) input.value = "";
	}

	async function handleChangePassword() {
		if (!oldPassword) {
			passwordError = "请输入原密码";
			return;
		}
		if (!newPassword) {
			passwordError = "请输入新密码";
			return;
		}
		if (newPassword.length < 6) {
			passwordError = "新密码至少 6 位";
			return;
		}

		isChangingPassword = true;
		passwordError = "";

		const result = await changePassword(oldPassword, newPassword);
		if (result.success) {
			oldPassword = "";
			newPassword = "";
			showPasswordForm = false;
			passwordError = "";
			// 显示成功提示
			alert("密码修改成功");
		} else {
			passwordError = result.error || "修改失败";
		}

		isChangingPassword = false;
	}

	const navItems = [
		{ key: "home", label: "修仙界", href: "/cultivation/", icon: "lucide:orbit" },
		{ key: "tasks", label: "任务", href: "/cultivation/tasks/", icon: "lucide:scroll-text" },
		{ key: "shop", label: "仙市", href: "/cultivation/shop/", icon: "lucide:store" },
	];
</script>

<nav class="cult-nav">
	<div class="cult-nav-inner">
		<a href="/" class="cult-nav-back" title="返回首页" on:click|preventDefault={() => { window.location.href = "/"; }}>
			<Icon icon="lucide:arrow-left" width="20" height="20" />
		</a>

		<a href="/cultivation/" class="cult-nav-brand">
			<Icon icon="lucide:yin-yang" class="cult-nav-brand-icon" width="20" height="20" />
		</a>

		<div class="cult-nav-links">
			{#each navItems as item}
				<a
					href={item.href}
					class="cult-nav-link"
					class:active={activeNav === item.key}
				>
					<Icon icon={item.icon} width="20" height="20" />
					<span class="cult-nav-link-label">{item.label}</span>
				</a>
			{/each}

			{#if $isAdmin}
				<a
					href="/cultivation/admin/"
					class="cult-nav-link"
					class:active={activeNav === "admin"}
				>
					<Icon icon="lucide:settings-2" width="20" height="20" />
					<span class="cult-nav-link-label">管理</span>
				</a>
			{/if}
		</div>

		<div class="cult-nav-user">
			{#if $authStore.isLoading}
				<span class="cult-nav-loading">...</span>
			{:else if $authStore.isLoggedIn && $authStore.profile}
				<div class="cult-nav-user-info">
					<span class="cult-nav-coins">
						<Icon icon="lucide:coins" width="16" height="16" />
						<span class="cult-nav-coins-value">{$authStore.wallet?.coins ?? 0}</span>
					</span>
					<button class="cult-nav-avatar-btn" on:click={openProfileModal} title="账号管理">
						<div class="cult-nav-user-avatar">
							{#if $authStore.profile?.avatar}
								<img src={$authStore.profile.avatar} alt="头像" class="cult-nav-avatar-img" />
							{:else}
								{$authStore.profile.username.charAt(0).toUpperCase()}
							{/if}
						</div>
					</button>
				</div>
			{:else}
				<a href="/cultivation/login/" class="cult-nav-login-btn">登录</a>
			{/if}
		</div>
	</div>
</nav>

<!-- 账号管理模态框 -->
{#if showProfileModal}
	<div class="cult-modal-overlay" on:click={(e) => { if (e.target === e.currentTarget) closeProfileModal(); }}>
		<div class="cult-modal">
			<div class="cult-modal-header">
				<h3 class="cult-modal-title">账号管理</h3>
				<button class="cult-modal-close" on:click={closeProfileModal}>×</button>
			</div>
			<div class="cult-modal-body">
				<!-- 头像上传 -->
				<div class="cult-avatar-upload-section">
					<div class="cult-avatar-preview">
						{#if $authStore.profile?.avatar}
							<img src={$authStore.profile.avatar} alt="头像" class="cult-avatar-preview-img" />
						{:else}
							{$authStore.profile?.username?.charAt(0).toUpperCase() || "?"}
						{/if}
					</div>
					<div class="cult-avatar-upload-info">
						<p class="cult-avatar-upload-hint">头像大小不超过 100KB，超过自动压缩</p>
						<input
							type="file"
							accept="image/*"
							bind:this={avatarFileInput}
							style="display: none;"
							on:change={handleAvatarChange}
						/>
						<button
							class="cult-btn cult-btn-secondary"
							style="padding: 6px 12px; font-size: 13px;"
							on:click={() => avatarFileInput?.click()}
							disabled={isUploadingAvatar}
						>
							{isUploadingAvatar ? "上传中..." : "更换头像"}
						</button>
					</div>
				</div>
				{#if avatarError}
					<div class="cult-form-error">{avatarError}</div>
				{/if}

				<!-- 原始注册ID -->
				{#if $authStore.profile?.original_username}
					<div style="margin-top: 12px; padding: 10px 14px; background: rgba(124, 92, 255, 0.08); border: 1px solid rgba(124, 92, 255, 0.15); border-radius: 8px;">
						<div style="font-size: 12px; color: var(--cult-text-muted); margin-bottom: 2px;">注册ID</div>
						<div style="font-size: 16px; font-weight: 600; color: var(--cult-text); font-family: monospace;">{$authStore.profile.original_username}</div>
					</div>
				{/if}

				<div class="cult-modal-divider"></div>

				<!-- 道号修改 -->
				<div class="cult-form-group">
					<label class="cult-form-label">道号（昵称）</label>
					<input
						type="text"
						class="cult-form-input"
						bind:value={newUsername}
						placeholder="输入新道号"
						maxlength="20"
					/>
				</div>
				{#if usernameError}
					<div class="cult-form-error">{usernameError}</div>
				{/if}
				<button
					class="cult-btn cult-btn-primary"
					style="width: 100%; margin-top: 16px;"
					on:click={handleSaveUsername}
					disabled={isSaving}
				>
					{isSaving ? "保存中..." : "保存道号"}
				</button>

				<div class="cult-modal-divider"></div>

				<!-- 修改密码 -->
				{#if !showPasswordForm}
					<button
						class="cult-btn cult-btn-secondary"
						style="width: 100%; display: flex; align-items: center; justify-content: center; gap: 8px; margin-bottom: 16px;"
						on:click={() => { showPasswordForm = true; passwordError = ""; }}
					>
						<Icon icon="lucide:lock" width="18" height="18" />
						修改密码
					</button>
				{:else}
					<div class="cult-password-form">
						<div class="cult-form-group">
							<label class="cult-form-label">原密码</label>
							<input
								type="password"
								class="cult-form-input"
								bind:value={oldPassword}
								placeholder="输入原密码"
							/>
						</div>
						<div class="cult-form-group" style="margin-top: 12px;">
							<label class="cult-form-label">新密码</label>
							<input
								type="password"
								class="cult-form-input"
								bind:value={newPassword}
								placeholder="输入新密码（至少6位）"
							/>
						</div>
						{#if passwordError}
							<div class="cult-form-error">{passwordError}</div>
						{/if}
						<div style="display: flex; gap: 8px; margin-top: 16px;">
							<button
								class="cult-btn cult-btn-secondary"
								style="flex: 1;"
								on:click={() => { showPasswordForm = false; oldPassword = ""; newPassword = ""; passwordError = ""; }}
							>
								取消
							</button>
							<button
								class="cult-btn cult-btn-primary"
								style="flex: 1;"
								on:click={handleChangePassword}
								disabled={isChangingPassword}
							>
								{isChangingPassword ? "修改中..." : "确认修改"}
							</button>
						</div>
					</div>
				{/if}

				<button class="cult-btn cult-btn-danger" style="width: 100%; display: flex; align-items: center; justify-content: center; gap: 8px;" on:click={handleLogout}>
					<Icon icon="lucide:log-out" width="18" height="18" />
					退出登录
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.cult-nav {
		position: sticky;
		top: 0;
		z-index: 100;
		background: rgba(5, 8, 17, 0.9);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		border-bottom: 1px solid rgba(139, 92, 246, 0.1);
	}

	.cult-nav-inner {
		max-width: 1100px;
		margin: 0 auto;
		padding: 0 20px;
		height: 64px;
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.cult-nav-brand {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-shrink: 0;
	}

	.cult-nav-back {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		border-radius: 10px;
		color: rgba(241, 245, 249, 0.6);
		transition: all 0.15s;
		flex-shrink: 0;
	}

	.cult-nav-back:hover {
		color: #f1f5f9;
		background: rgba(139, 92, 246, 0.12);
	}

	.cult-nav-brand-icon {
		color: #a78bfa;
	}

	.cult-nav-brand-text {
		font-size: 15px;
		font-weight: 600;
		color: #f1f5f9;
		letter-spacing: 0.03em;
	}

	.cult-nav-links {
		display: flex;
		align-items: center;
		gap: 6px;
		flex: 1;
		overflow-x: auto;
		scrollbar-width: none;
	}

	.cult-nav-links::-webkit-scrollbar {
		display: none;
	}

	.cult-nav-link {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		border-radius: 10px;
		color: rgba(241, 245, 249, 0.5);
		font-size: 14px;
		font-weight: 500;
		white-space: nowrap;
		transition: all 0.15s;
	}

	.cult-nav-link:hover {
		color: #f1f5f9;
		background: rgba(139, 92, 246, 0.08);
	}

	.cult-nav-link.active {
		color: #a78bfa;
		background: rgba(139, 92, 246, 0.12);
	}

	.cult-nav-user {
		flex-shrink: 0;
	}

	.cult-nav-user-info {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.cult-nav-coins {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 7px 14px;
		background: rgba(251, 191, 36, 0.08);
		border: 1px solid rgba(251, 191, 36, 0.15);
		border-radius: 10px;
		color: #fcd34d;
	}

	.cult-nav-coins :global(svg) {
		color: #fcd34d;
	}

	.cult-nav-coins-value {
		font-size: 14px;
		font-weight: 600;
	}

	.cult-nav-avatar-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		transition: transform 0.15s;
	}

	.cult-nav-avatar-btn:hover {
		transform: scale(1.1);
	}

	.cult-nav-avatar-btn:active {
		transform: scale(0.95);
	}

	.cult-nav-user-avatar {
		width: 34px;
		height: 34px;
		border-radius: 50%;
		background: linear-gradient(135deg, #6366f1, #8b5cf6);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
		font-weight: 600;
		color: white;
		overflow: hidden;
	}

	.cult-nav-avatar-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 50%;
	}

	.cult-nav-login-btn {
		padding: 6px 14px;
		background: #8b5cf6;
		border-radius: 8px;
		color: white;
		font-size: 13px;
		font-weight: 500;
		transition: all 0.15s;
	}

	.cult-nav-login-btn:hover {
		background: #7c3aed;
	}

	.cult-nav-loading {
		font-size: 13px;
		color: rgba(241, 245, 249, 0.4);
	}

	/* 模态框样式 */
	.cult-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 16px;
	}

	.cult-modal {
		background: #0f1220;
		border: 1px solid rgba(139, 92, 246, 0.2);
		border-radius: 16px;
		width: 100%;
		max-width: 420px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}

	.cult-modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 20px 24px;
		border-bottom: 1px solid rgba(139, 92, 246, 0.1);
	}

	.cult-modal-title {
		font-size: 18px;
		font-weight: 600;
		color: #f1f5f9;
		margin: 0;
	}

	.cult-modal-close {
		background: none;
		border: none;
		color: rgba(241, 245, 249, 0.5);
		font-size: 24px;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		transition: all 0.15s;
	}

	.cult-modal-close:hover {
		background: rgba(139, 92, 246, 0.1);
		color: #f1f5f9;
	}

	.cult-modal-body {
		padding: 24px;
	}

	.cult-modal-divider {
		height: 1px;
		background: rgba(139, 92, 246, 0.15);
		margin: 24px 0;
	}

	.cult-quick-links {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 10px;
	}

	.cult-quick-link {
		width: 100% !important;
		display: flex !important;
		align-items: center !important;
		justify-content: center !important;
		gap: 6px !important;
		margin-bottom: 0 !important;
		padding: 10px 12px !important;
		font-size: 13px !important;
	}

	.cult-form-group {
		margin-bottom: 0;
	}

	.cult-form-label {
		display: block;
		font-size: 13px;
		color: rgba(241, 245, 249, 0.6);
		margin-bottom: 8px;
	}

	.cult-form-input {
		width: 100%;
		padding: 10px 14px;
		background: rgba(139, 92, 246, 0.05);
		border: 1px solid rgba(139, 92, 246, 0.2);
		border-radius: 10px;
		color: #f1f5f9;
		font-size: 14px;
		outline: none;
		transition: all 0.15s;
		box-sizing: border-box;
	}

	.cult-form-input:focus {
		border-color: rgba(139, 92, 246, 0.5);
		background: rgba(139, 92, 246, 0.08);
	}

	.cult-form-input::placeholder {
		color: rgba(241, 245, 249, 0.3);
	}

	.cult-form-error {
		color: #f87171;
		font-size: 13px;
		margin-top: 8px;
	}

	.cult-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 10px 20px;
		border-radius: 10px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s;
		border: none;
		text-decoration: none;
		box-sizing: border-box;
	}

	.cult-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.cult-btn-primary {
		background: #8b5cf6;
		color: white;
	}

	.cult-btn-primary:hover:not(:disabled) {
		background: #7c3aed;
	}

	.cult-btn-secondary {
		background: transparent;
		color: rgba(241, 245, 249, 0.8);
		border: 1px solid rgba(139, 92, 246, 0.3);
	}

	.cult-btn-secondary:hover {
		background: rgba(139, 92, 246, 0.1);
		color: #f1f5f9;
	}

	.cult-btn-danger {
		background: rgba(248, 113, 113, 0.1);
		color: #f87171;
		border: 1px solid rgba(248, 113, 113, 0.3);
	}

	.cult-btn-danger:hover {
		background: rgba(248, 113, 113, 0.15);
		color: #fca5a5;
	}

	@media (max-width: 640px) {
		.cult-nav-inner {
			padding: 0 12px;
			gap: 10px;
			height: 56px;
		}

		.cult-nav-brand-text {
			display: none;
		}

		.cult-nav-link-label {
			display: none;
		}

		.cult-nav-link {
			padding: 8px 10px;
		}

		.cult-nav-coins {
			padding: 5px 10px;
		}

		.cult-nav-user-avatar {
			width: 30px;
			height: 30px;
		}

		.cult-quick-links {
			grid-template-columns: 1fr;
		}
	}

	/* 头像上传 */
	.cult-avatar-upload-section {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 8px;
	}

	.cult-avatar-preview {
		width: 64px;
		height: 64px;
		border-radius: 50%;
		background: linear-gradient(135deg, #6366f1, #8b5cf6);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 24px;
		font-weight: 600;
		color: white;
		flex-shrink: 0;
		overflow: hidden;
	}

	.cult-avatar-preview-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 50%;
	}

	.cult-avatar-upload-info {
		flex: 1;
	}

	.cult-avatar-upload-hint {
		font-size: 12px;
		color: #64748b;
		margin: 0 0 8px 0;
	}

	/* 修改密码表单 */
	.cult-password-form {
		margin-bottom: 8px;
	}
</style>
