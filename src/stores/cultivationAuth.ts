/**
 * 修仙系统 Auth Store
 * 管理登录状态和用户信息
 */
import { writable, derived } from "svelte/store";
import type { Profile, Wallet } from "../services/cultivation/types";
import { getMyProfile, getMyWallet, onAuthChange, getCurrentUser, logout as apiLogout } from "../services/cultivation";

interface AuthState {
	isLoading: boolean;
	isLoggedIn: boolean;
	user: any | null;
	profile: Profile | null;
	wallet: Wallet | null;
}

const initialState: AuthState = {
	isLoading: true,
	isLoggedIn: false,
	user: null,
	profile: null,
	wallet: null,
};

export const authStore = writable<AuthState>(initialState);

/** 初始化 Auth 状态 */
export async function initAuth() {
	authStore.update((s) => ({ ...s, isLoading: true }));

	try {
		const user = await getCurrentUser();
		if (user) {
			const [profile, wallet] = await Promise.all([getMyProfile(), getMyWallet()]);
			authStore.set({
				isLoading: false,
				isLoggedIn: true,
				user,
				profile,
				wallet,
			});
		} else {
			authStore.set({ ...initialState, isLoading: false });
		}
	} catch (e) {
		authStore.set({ ...initialState, isLoading: false });
	}

	// 监听 Auth 变化
	onAuthChange(async (event, session) => {
		if (event === "SIGNED_IN" && session) {
			const [profile, wallet] = await Promise.all([getMyProfile(), getMyWallet()]);
			authStore.set({
				isLoading: false,
				isLoggedIn: true,
				user: session.user,
				profile,
				wallet,
			});
		} else if (event === "SIGNED_OUT") {
			authStore.set({ ...initialState, isLoading: false });
		}
	});
}

/** 刷新用户数据 */
export async function refreshAuth() {
	const user = await getCurrentUser();
	if (!user) {
		authStore.set({ ...initialState, isLoading: false });
		return;
	}
	const [profile, wallet] = await Promise.all([getMyProfile(), getMyWallet()]);
	authStore.update((s) => ({
		...s,
		isLoggedIn: true,
		user,
		profile,
		wallet,
	}));
}

/** 派生：是否是管理员 */
export const isAdmin = derived(authStore, ($auth) => {
	return $auth.profile?.role === "admin" || $auth.profile?.role === "owner";
});

/** 派生：是否是宗主 */
export const isOwner = derived(authStore, ($auth) => {
	return $auth.profile?.role === "owner";
});

/** 退出登录 */
export async function logout() {
	await apiLogout();
	authStore.set({ ...initialState, isLoading: false });
}
