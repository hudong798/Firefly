/**
 * 修仙系统核心服务
 * 集成 Auth、Profile、Task、Wallet、Shop 等功能
 */
import { supabase } from "@/lib/supabase";
import type {
	Profile,
	Wallet,
	WalletTransaction,
	Task,
	TaskClaim,
	Product,
	Order,
	Transfer,
	Pill,
	InventoryItem,
	ResellListing,
} from "./types";

// ============================================================
// Auth 相关
// ============================================================

/** 注册 */
export async function register(
	username: string,
	email: string,
	password: string,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		// 检查用户名是否已存在
		const { data: existing } = await supabase
			.from("profiles")
			.select("id")
			.eq("username", username)
			.limit(1);

		if (existing && existing.length > 0) {
			return { success: false, error: "用户名已被使用" };
		}

		// 统一使用 user_+username@freex.app 作为邮箱，确保用户名登录能匹配
		const authEmail = `user_${username}@freex.app`;

		// 注册 Auth 用户
		const { data, error } = await supabase.auth.signUp({
			email: authEmail,
			password,
			options: {
				data: { username },
			},
		});

		if (error) throw error;
		if (!data.user) return { success: false, error: "注册失败" };

		// 等待 profile 创建后，保存原始注册ID
		setTimeout(async () => {
			try {
				await supabase
					.from("profiles")
					.update({ original_username: username })
					.eq("id", data.user!.id);
			} catch (e) {
				console.error("保存 original_username 失败", e);
			}
		}, 1000);

		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "注册失败" };
	}
}

/** 登录（支持用户名或邮箱） */
export async function login(
	identifier: string,
	password: string,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		let email = identifier;

		// 如果不是邮箱格式，用 user_+username@freex.app
		if (!identifier.includes("@")) {
			if (identifier === "0001") {
				email = "owner@freex.local";
			} else {
				email = `user_${identifier}@freex.app`;
			}
		}

		const { data, error } = await supabase.auth.signInWithPassword({
			email,
			password,
		});

		if (error) throw error;
		if (!data.user) return { success: false, error: "登录失败" };

		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "登录失败，请检查用户名和密码" };
	}
}

/** 退出登录 */
export async function logout(): Promise<void> {
	if (!supabase) return;
	await supabase.auth.signOut();
	clearUserCache();
}

/** 获取当前用户 */
// 用户缓存，避免重复网络请求
let _cachedUser: any | null = null;
let _cacheTime = 0;
const CACHE_TTL = 30000; // 30秒缓存

export async function getCurrentUser(forceRefresh = false) {
	if (!supabase) return null;
	// 使用本地 session（无网络请求），比 getUser() 快很多
	const now = Date.now();
	if (!forceRefresh && _cachedUser && now - _cacheTime < CACHE_TTL) {
		return _cachedUser;
	}
	const { data } = await supabase.auth.getSession();
	const user = data.session?.user || null;
	_cachedUser = user;
	_cacheTime = now;
	return user;
}

/** 清除用户缓存（登出时调用） */
export function clearUserCache() {
	_cachedUser = null;
	_cacheTime = 0;
}

/** 获取当前会话 */
export async function getSession() {
	if (!supabase) return null;
	const { data } = await supabase.auth.getSession();
	return data.session || null;
}

/** 监听 Auth 状态变化 */
export function onAuthChange(callback: (event: string, session: any) => void) {
	if (!supabase) return () => {};
	const { data } = supabase.auth.onAuthStateChange(callback);
	return data.subscription.unsubscribe;
}

// ============================================================
// Profile 相关
// ============================================================

/** 获取当前用户 profile */
export async function getMyProfile(): Promise<Profile | null> {
	if (!supabase) return null;
	const user = await getCurrentUser();
	if (!user) return null;

	const { data, error } = await supabase
		.from("profiles")
		.select("*")
		.eq("id", user.id)
		.limit(1);

	if (error || !data || data.length === 0) return null;
	return data[0] as Profile;
}

/** 根据 ID 获取 profile */
export async function getProfileById(id: string): Promise<Profile | null> {
	if (!supabase) return null;
	const { data, error } = await supabase
		.from("profiles")
		.select("*")
		.eq("id", id)
		.limit(1);

	if (error || !data || data.length === 0) return null;
	return data[0] as Profile;
}

/** 根据用户名获取 profile */
export async function getProfileByUsername(username: string): Promise<Profile | null> {
	if (!supabase) return null;
	const { data, error } = await supabase
		.from("profiles")
		.select("*")
		.eq("username", username)
		.limit(1);

	if (error || !data || data.length === 0) return null;
	return data[0] as Profile;
}

/** 更新当前用户昵称 */
export async function updateMyUsername(username: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	const user = await getCurrentUser();
	if (!user) return { success: false, error: "未登录" };

	// 检查用户名是否已被占用
	const existing = await getProfileByUsername(username);
	if (existing && existing.id !== user.id) {
		return { success: false, error: "该道号已被占用" };
	}

	const { error } = await supabase
		.from("profiles")
		.update({ username })
		.eq("id", user.id);

	if (error) return { success: false, error: error.message };
	return { success: true };
}

/** 更新当前用户头像（Base64） */
export async function updateMyAvatar(avatarDataUrl: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	const user = await getCurrentUser();
	if (!user) return { success: false, error: "未登录" };

	const { error } = await supabase
		.from("profiles")
		.update({ avatar: avatarDataUrl })
		.eq("id", user.id);

	if (error) return { success: false, error: error.message };
	return { success: true };
}

/** 修改密码 */
export async function changePassword(
	oldPassword: string,
	newPassword: string,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	const user = await getCurrentUser();
	if (!user) return { success: false, error: "未登录" };

	if (!oldPassword || !newPassword) {
		return { success: false, error: "密码不能为空" };
	}

	if (newPassword.length < 6) {
		return { success: false, error: "新密码至少 6 位" };
	}

	try {
		// 验证原密码
		const { data: profile } = await supabase
			.from("profiles")
			.select("username")
			.eq("id", user.id)
			.single();

		if (!profile) {
			return { success: false, error: "用户不存在" };
		}

		const authEmail = `user_${profile.username}@freex.app`;
		const { error: signInError } = await supabase.auth.signInWithPassword({
			email: authEmail,
			password: oldPassword,
		});

		if (signInError) {
			return { success: false, error: "原密码错误" };
		}

		// 修改密码
		const { error: updateError } = await supabase.auth.updateUser({
			password: newPassword,
		});

		if (updateError) {
			return { success: false, error: updateError.message };
		}

		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "修改密码失败" };
	}
}

/** 获取所有用户（管理员/宗主） */
export async function getAllProfiles(): Promise<Profile[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("profiles")
		.select("*")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Profile[];
}

/** 更新用户角色（宗主） */
export async function updateUserRole(userId: string, role: "owner" | "admin" | "user"): Promise<boolean> {
	if (!supabase) return false;
	const { error } = await supabase
		.from("profiles")
		.update({ role })
		.eq("id", userId);
	return !error;
}

/** 更新用户状态（宗主/管理员） */
export async function updateUserStatus(userId: string, status: "active" | "disabled"): Promise<boolean> {
	if (!supabase) return false;
	const { error } = await supabase
		.from("profiles")
		.update({ status })
		.eq("id", userId);
	return !error;
}

/** 删除用户（仅宗主） */
export async function deleteUser(userId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };
	try {
		const { data, error } = await supabase.rpc("delete_user", { p_user_id: userId });
		if (error) throw error;
		return data || { success: false, error: "删除失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "删除失败" };
	}
}

/** 重置用户密码（宗主/管理员） */
export async function resetUserPassword(userId: string, newPassword: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };
	try {
		const { data, error } = await supabase.rpc("reset_user_password", { p_user_id: userId, p_new_password: newPassword });
		if (error) throw error;
		return data || { success: false, error: "重置失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "重置失败" };
	}
}

// ============================================================
// Wallet 相关
// ============================================================

/** 获取我的钱包 */
export async function getMyWallet(): Promise<Wallet | null> {
	if (!supabase) return null;
	const user = await getCurrentUser();
	if (!user) return null;

	const { data, error } = await supabase
		.from("wallets")
		.select("*")
		.eq("user_id", user.id)
		.limit(1);

	if (error || !data || data.length === 0) return null;
	return data[0] as Wallet;
}

/** 获取我的星辰币流水 */
export async function getMyTransactions(limit = 50): Promise<WalletTransaction[]> {
	if (!supabase) return [];
	const user = await getCurrentUser();
	if (!user) return [];

	const { data, error } = await supabase
		.from("wallet_transactions")
		.select("*")
		.eq("user_id", user.id)
		.order("created_at", { ascending: false })
		.limit(limit);

	if (error || !data) return [];
	return data as WalletTransaction[];
}

/** 转赠星辰币（RPC） */
export async function transferCoins(
	receiverId: string,
	amount: number,
	note?: string,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("transfer_coins", {
			p_receiver_id: receiverId,
			p_amount: amount,
			p_note: note || null,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true };
		}
		return { success: false, error: data?.error || "转赠失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "转赠失败" };
	}
}

// ============================================================
// Task 相关
// ============================================================

/** 获取已发布的任务列表 */
export async function getPublishedTasks(): Promise<Task[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("tasks")
		.select("*")
		.eq("status", "published")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Task[];
}

/** 获取所有任务（管理员） */
export async function getAllTasks(): Promise<Task[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("tasks")
		.select("*")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Task[];
}

/** 创建任务（管理员/宗主） */
export async function createTask(
	title: string,
	description: string,
	rewardCoins: number,
	category: string = "初级任务",
	maxClaimants: number = 0,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const user = await getCurrentUser();
		if (!user) return { success: false, error: "未登录" };

		const { error } = await supabase.from("tasks").insert({
			title,
			description,
			reward_coins: rewardCoins,
			category,
			max_claimants: maxClaimants >= 0 ? maxClaimants : 0,
			creator_id: user.id,
			status: "published",
		});

		if (error) throw error;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "创建任务失败" };
	}
}

/** 更新任务状态 */
export async function updateTaskStatus(taskId: string, status: "draft" | "published" | "offline"): Promise<boolean> {
	if (!supabase) return false;
	const { error } = await supabase
		.from("tasks")
		.update({ status })
		.eq("id", taskId);
	return !error;
}

/** 领取任务 */
export async function claimTask(taskId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const user = await getCurrentUser();
		if (!user) return { success: false, error: "未登录" };

		// 使用原子性 RPC 函数，防止并发超领
		const { data, error } = await supabase.rpc("claim_task_atomic", {
			p_task_id: taskId,
			p_user_id: user.id,
		});

		if (error) throw error;

		if (data && !data.success) {
			return { success: false, error: data.error || "领取失败" };
		}

		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "领取任务失败" };
	}
}

/** 获取我的任务领取记录 */
export async function getMyTaskClaims(): Promise<TaskClaim[]> {
	if (!supabase) return [];
	const user = await getCurrentUser();
	if (!user) return [];

	const { data, error } = await supabase
		.from("task_claims")
		.select("*")
		.eq("user_id", user.id)
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as TaskClaim[];
}

/** 获取待审核的任务（管理员） */
export async function getPendingReviews(): Promise<TaskClaim[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("task_claims")
		.select("*")
		.eq("status", "submitted")
		.order("submitted_at", { ascending: true });

	if (error || !data) return [];
	return data as TaskClaim[];
}

/** 提交任务（上传证明） */
export async function submitTask(
	claimId: string,
	proofText: string,
	proofImages: string[] = [],
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { error } = await supabase
			.from("task_claims")
			.update({
				status: "submitted",
				proof_text: proofText,
				proof_images: proofImages,
				submitted_at: new Date().toISOString(),
			})
			.eq("id", claimId);

		if (error) throw error;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "提交失败" };
	}
}

/** 审核通过（RPC，自动发放奖励） */
export async function approveTaskClaim(
	claimId: string,
	reviewNote?: string,
): Promise<{ success: boolean; error?: string; reward?: number }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("approve_task_claim", {
			p_claim_id: claimId,
			p_review_note: reviewNote || null,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true, reward: data.reward };
		}
		return { success: false, error: data?.error || "审核失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "审核失败" };
	}
}

/** 审核通过任务（同时发放星辰币和随机虎粮） */
export async function approveTaskWithQi(
	claimId: string,
	reviewNote?: string,
): Promise<{ success: boolean; error?: string; reward?: number; qi_earned?: number }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("approve_task_with_qi", {
			p_claim_id: claimId,
			p_review_note: reviewNote || null,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true, reward: data.reward, qi_earned: data.qi_earned };
		}
		return { success: false, error: data?.error || "审核失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "审核失败" };
	}
}

/** 驳回任务 */
export async function rejectTaskClaim(
	claimId: string,
	reviewNote: string,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const user = await getCurrentUser();
		const { error } = await supabase
			.from("task_claims")
			.update({
				status: "rejected",
				reviewed_at: new Date().toISOString(),
				reviewer_id: user?.id,
				review_note: reviewNote,
			})
			.eq("id", claimId);

		if (error) throw error;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "驳回失败" };
	}
}

// ============================================================
// Shop 相关
// ============================================================

/** 获取上架商品 */
export async function getActiveProducts(): Promise<Product[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("products")
		.select("*")
		.eq("status", "active")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Product[];
}

/** 获取所有商品（管理员） */
export async function getAllProducts(): Promise<Product[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("products")
		.select("*")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Product[];
}

/** 创建商品（管理员） */
export async function createProduct(
	name: string,
	description: string,
	price: number,
	stock: number = 1,
	imageUrl?: string,
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const user = await getCurrentUser();
		if (!user) return { success: false, error: "未登录" };

		const { error } = await supabase.from("products").insert({
			name,
			description,
			price,
			stock: stock > 0 ? stock : 1,
			image_url: imageUrl || null,
			creator_id: user.id,
			status: "active",
		});

		if (error) throw error;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "创建商品失败" };
	}
}

/** 更新商品状态 */
export async function updateProductStatus(productId: string, status: "active" | "inactive"): Promise<boolean> {
	if (!supabase) return false;
	const { error } = await supabase
		.from("products")
		.update({ status })
		.eq("id", productId);
	return !error;
}

/** 兑换商品（RPC） */
export async function redeemProduct(productId: string): Promise<{ success: boolean; error?: string; orderId?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("redeem_product", {
			p_product_id: productId,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true, orderId: data.order_id };
		}
		return { success: false, error: data?.error || "兑换失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "兑换失败" };
	}
}

/** 获取我的兑换记录 */
export async function getMyOrders(): Promise<Order[]> {
	if (!supabase) return [];
	const user = await getCurrentUser();
	if (!user) return [];

	const { data, error } = await supabase
		.from("orders")
		.select("*, products(name, description, image_url)")
		.eq("user_id", user.id)
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Order[];
}

/** 获取所有订单（管理员） */
export async function getAllOrders(): Promise<Order[]> {
	if (!supabase) return [];

	const { data, error } = await supabase
		.from("orders")
		.select("*, products(name, description, image_url), profiles(username)")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Order[];
}

/** 发货（管理员） */
export async function shipOrder(orderId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("ship_order", {
			p_order_id: orderId,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true };
		}
		return { success: false, error: data?.error || "发货失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "发货失败" };
	}
}

/** 确认收货（用户） */
export async function confirmReceipt(orderId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("confirm_receipt", {
			p_order_id: orderId,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true };
		}
		return { success: false, error: data?.error || "确认收货失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "确认收货失败" };
	}
}

/** 退款（管理员/卖家） */
export async function refundOrder(orderId: string, reason?: string): Promise<{ success: boolean; error?: string; refundAmount?: number }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("refund_order", {
			p_order_id: orderId,
			p_reason: reason || null,
		});

		if (error) throw error;
		if (data?.success) {
			return { success: true, refundAmount: data.refund_amount };
		}
		return { success: false, error: data?.error || "退款失败" };
	} catch (e: any) {
		return { success: false, error: e?.message || "退款失败" };
	}
}

// ============================================================
// 我的仙铺相关
// ============================================================

/** 获取我的仙铺仙货 */
export async function getMyShopProducts(): Promise<Product[]> {
	if (!supabase) return [];
	const user = await getCurrentUser();
	if (!user) return [];

	const { data, error } = await supabase
		.from("products")
		.select("*")
		.eq("creator_id", user.id)
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Product[];
}

/** 获取我的仙铺订单（购买我仙货的订单） */
export async function getMyShopOrders(): Promise<Order[]> {
	if (!supabase) return [];
	const user = await getCurrentUser();
	if (!user) return [];

	// 先查询我的商品 ID 列表
	const { data: myProducts, error: productsError } = await supabase
		.from("products")
		.select("id")
		.eq("creator_id", user.id);

	if (productsError || !myProducts || myProducts.length === 0) return [];

	const productIds = myProducts.map((p: any) => p.id);

	// 再查询这些商品的订单（别的用户购买我的商品）
	const { data, error } = await supabase
		.from("orders")
		.select("*, products(name, description, image_url), profiles!orders_user_id_fkey(username)")
		.in("product_id", productIds)
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Order[];
}

/** 更新我的商品状态（上下架） */
export async function updateMyProductStatus(
	productId: string,
	status: "active" | "inactive",
): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const user = await getCurrentUser();
		if (!user) return { success: false, error: "未登录" };

		// 先检查是否是自己的商品
		const { data: product } = await supabase
			.from("products")
			.select("creator_id")
			.eq("id", productId)
			.single();

		if (!product || product.creator_id !== user.id) {
			return { success: false, error: "只能操作自己的商品" };
		}

		const { error } = await supabase
			.from("products")
			.update({ status })
			.eq("id", productId);

		if (error) throw error;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "操作失败" };
	}
}

/** 获取上架商品（含卖家信息） */
export async function getActiveProductsWithSeller(): Promise<Product[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("products")
		.select("*, profiles!products_creator_id_fkey(username)")
		.eq("status", "active")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as Product[];
}

// ============================================================
// 统计相关
// ============================================================

/** 获取我的修仙统计 */
export async function getMyStats(): Promise<{
	tasksCompleted: number;
	totalCoins: number;
	qi: number;
	realm: string;
}> {
	const [claims, wallet, profile] = await Promise.all([
		getMyTaskClaims(),
		getMyWallet(),
		getMyProfile(),
	]);
	const tasksCompleted = claims.filter((c) => c.status === "approved").length;
	const totalCoins = wallet?.coins || 0;
	const qi = profile?.qi || 0;

	const { getRealm } = await import("./types");
	const realm = getRealm(qi);

	return { tasksCompleted, totalCoins, qi, realm };
}

// ============================================================
// 丹药相关
// ============================================================

/** 获取上架丹药列表 */
export async function getActivePills(): Promise<Pill[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("pills")
		.select("*")
		.eq("status", "active")
		.order("grade", { ascending: true })
		.order("price", { ascending: true });

	if (error || !data) return [];
	return data as Pill[];
}

/** 购买丹药 */
export async function buyPill(pillId: string): Promise<{ success: boolean; error?: string; inventory_id?: string; remaining_coins?: number }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("buy_pill", { p_pill_id: pillId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "购买失败" };
	}
}

// ============================================================
// 储物袋相关
// ============================================================

/** 获取我的储物袋 */
export async function getMyInventory(status: "owned" | "used" = "owned"): Promise<InventoryItem[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("inventory")
		.select("*")
		.eq("status", status)
		.order("obtained_at", { ascending: false });

	if (error || !data) return [];
	return data as InventoryItem[];
}

/** 标记物品为已使用（作废），如果在转售中则同时下架 */
export async function markItemAsUsed(inventoryId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const user = await getCurrentUser();
		if (!user) return { success: false, error: "未登录" };

		// 先查询物品信息
		const { data: item, error: itemError } = await supabase
			.from("inventory")
			.select("*")
			.eq("id", inventoryId)
			.eq("user_id", user.id)
			.single();

		if (itemError || !item) return { success: false, error: "物品不存在" };
		if (item.status === "used") return { success: false, error: "物品已使用" };

		// 如果物品在转售中，先删除转售记录
		if (item.status === "listed") {
			const { error: listingError } = await supabase
				.from("resell_listings")
				.delete()
				.eq("inventory_id", inventoryId);
			if (listingError) return { success: false, error: listingError.message };
		}

		// 更新物品状态为已使用
		const { error: updateError } = await supabase
			.from("inventory")
			.update({ status: "used", used_at: new Date().toISOString() })
			.eq("id", inventoryId)
			.eq("user_id", user.id);

		if (updateError) return { success: false, error: updateError.message };
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "操作失败" };
	}
}

/** 使用丹药 */
export async function usePill(inventoryId: string): Promise<{ success: boolean; error?: string; qi_earned?: number; new_qi?: number }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("use_pill", { p_inventory_id: inventoryId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "使用失败" };
	}
}

/** 上架转售丹药 */
export async function listPillForResell(inventoryId: string, price: number): Promise<{ success: boolean; error?: string; listing_id?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("list_pill_for_resell", { p_inventory_id: inventoryId, p_price: price });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "上架失败" };
	}
}

/** 取消转售 */
export async function cancelResell(listingId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("cancel_resell", { p_listing_id: listingId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "取消失败" };
	}
}

/** 获取炒币市场列表 */
export async function getResellListings(): Promise<ResellListing[]> {
	if (!supabase) return [];
	const { data, error } = await supabase
		.from("resell_listings")
		.select("*")
		.eq("status", "active")
		.order("created_at", { ascending: false });

	if (error || !data) return [];
	return data as ResellListing[];
}

/** 购买转售丹药 */
export async function buyResellPill(listingId: string): Promise<{ success: boolean; error?: string; inventory_id?: string; remaining_coins?: number }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("buy_resell_pill", { p_listing_id: listingId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "购买失败" };
	}
}

// ============================================================
// 竞价相关
// ============================================================

/** 参与竞价 */
export async function placeResellBid(listingId: string, bidPrice: number): Promise<{ success: boolean; error?: string; message?: string; bid_price?: number; remaining_coins?: number }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("place_resell_bid", { p_listing_id: listingId, p_bid_price: bidPrice });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "竞价失败" };
	}
}

/** 结束竞价（卖家操作） */
export async function endResellBidding(listingId: string): Promise<{ success: boolean; error?: string; message?: string; final_price?: number; winner_id?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("end_resell_bidding", { p_listing_id: listingId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "结束竞价失败" };
	}
}

/** 取消竞价（竞价者操作） */
export async function cancelResellBid(listingId: string): Promise<{ success: boolean; error?: string; message?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("cancel_resell_bid", { p_listing_id: listingId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "取消竞价失败" };
	}
}

/** 获取竞价信息 */
export async function getResellBidInfo(listingId: string): Promise<{ success: boolean; error?: string; active_bid_count?: number; max_bidders?: number; is_seller?: boolean; my_bid_price?: number | null; has_my_bid?: boolean; listing_status?: string; base_price?: number }> {
	if (!supabase) return { success: false, error: "未初始化" };
	try {
		const { data, error } = await supabase.rpc("get_resell_bid_info", { p_listing_id: listingId });
		if (error) return { success: false, error: error.message };
		return data as any;
	} catch (e: any) {
		return { success: false, error: e?.message || "获取竞价信息失败" };
	}
}

/** 宗主创建丹药 */
export async function createPill(pill: { name: string; grade: number; description: string; qi_bonus: number; price: number }): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "未初始化" };
	const user = await getCurrentUser();
	if (!user) return { success: false, error: "未登录" };

	try {
		const { error } = await supabase
			.from("pills")
			.insert({ ...pill, seller_id: user.id });

		if (error) return { success: false, error: error.message };
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e?.message || "创建失败" };
	}
}

// ============================================================
// 排名相关
// ============================================================

/** 获取星辰币排名（使用公开 RPC，允许未登录查看） */
export async function getCoinRanking(limit = 10, currentUser?: any | null): Promise<{ rank: number; username: string; coins: number; isMe: boolean }[]> {
	if (!supabase) return [];
	const user = currentUser !== undefined ? currentUser : await getCurrentUser();

	// 优先使用公开 RPC（允许未登录查看）
	const { data: rpcData, error: rpcError } = await supabase
		.rpc("get_public_coin_ranking", { p_limit: limit });

	if (!rpcError && rpcData) {
		return rpcData.map((item: any) => ({
			rank: item.rank,
			username: item.username || "未知",
			coins: item.coins,
			isMe: user?.id === item.user_id,
		}));
	}

	// 回退到直接查表（需要登录）
	const { data, error } = await supabase
		.from("wallets")
		.select("user_id, coins, profiles!wallets_user_id_fkey(username)")
		.order("coins", { ascending: false })
		.limit(limit);

	if (error || !data) return [];

	return data.map((item: any, index: number) => ({
		rank: index + 1,
		username: item.profiles?.username || "未知",
		coins: item.coins,
		isMe: user?.id === item.user_id,
	}));
}

/** 获取境界排名（使用公开 RPC，允许未登录查看） */
export async function getRealmRanking(limit = 10, currentUser?: any | null): Promise<{ rank: number; username: string; realm: string; qi: number; isMe: boolean }[]> {
	if (!supabase) return [];
	const user = currentUser !== undefined ? currentUser : await getCurrentUser();

	// 优先使用公开 RPC（允许未登录查看）
	const { data: rpcData, error: rpcError } = await supabase
		.rpc("get_public_realm_ranking", { p_limit: limit });

	if (!rpcError && rpcData) {
		const { getRealm } = await import("./types");
		return rpcData.map((item: any) => ({
			rank: item.rank,
			username: item.username,
			realm: getRealm(item.qi || 0),
			qi: item.qi || 0,
			isMe: user?.id === item.user_id,
		}));
	}

	// 回退到直接查表（需要登录）
	const { data, error } = await supabase
		.from("profiles")
		.select("id, username, qi")
		.order("qi", { ascending: false })
		.limit(limit);

	if (error || !data) return [];

	const { getRealm } = await import("./types");

	return data.map((item: any, index: number) => ({
		rank: index + 1,
		username: item.username,
		realm: getRealm(item.qi || 0),
		qi: item.qi || 0,
		isMe: user?.id === item.id,
	}));
}

// ============================================================
// 邀请码相关
// ============================================================

export interface InvitationCode {
	id: string;
	code: string;
	created_by: string;
	created_at: string;
	expires_at: string;
	used_by: string | null;
	used_at: string | null;
	is_used: boolean;
}

/** 生成邀请码（只有宗主可以调用） */
export async function generateInvitationCode(): Promise<{ success: boolean; code?: string; expires_at?: string; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("generate_invitation_code");

		if (error) throw error;

		if (data && data.success) {
			return {
				success: true,
				code: data.code,
				expires_at: data.expires_at,
			};
		} else {
			return { success: false, error: data?.error || "生成邀请码失败" };
		}
	} catch (e: any) {
		return { success: false, error: e?.message || "生成邀请码失败" };
	}
}

/** 验证邀请码 */
export async function validateInvitationCode(code: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("validate_invitation_code", { p_code: code });

		if (error) throw error;

		if (data && data.success) {
			return { success: true };
		} else {
			return { success: false, error: data?.error || "邀请码无效" };
		}
	} catch (e: any) {
		return { success: false, error: e?.message || "验证邀请码失败" };
	}
}

/** 使用邀请码 */
export async function useInvitationCode(code: string, userId: string): Promise<{ success: boolean; error?: string }> {
	if (!supabase) return { success: false, error: "Supabase 未配置" };

	try {
		const { data, error } = await supabase.rpc("use_invitation_code", {
			p_code: code,
			p_user_id: userId,
		});

		if (error) throw error;

		if (data && data.success) {
			return { success: true };
		} else {
			return { success: false, error: data?.error || "使用邀请码失败" };
		}
	} catch (e: any) {
		return { success: false, error: e?.message || "使用邀请码失败" };
	}
}

/** 获取所有邀请码列表（只有宗主可以调用） */
export async function getInvitationCodes(): Promise<InvitationCode[]> {
	if (!supabase) return [];

	try {
		const { data, error } = await supabase
			.from("invitation_codes")
			.select("*")
			.order("created_at", { ascending: false });

		if (error || !data) return [];

		return data as InvitationCode[];
	} catch (e) {
		console.error("获取邀请码列表失败:", e);
		return [];
	}
}
