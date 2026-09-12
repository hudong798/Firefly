/**
 * 修仙系统类型定义
 */

export type UserRole = "owner" | "admin" | "user";
export type UserStatus = "active" | "disabled";

export interface Profile {
	id: string;
	username: string;
	original_username: string | null;
	avatar: string | null;
	role: UserRole;
	status: UserStatus;
	qi: number;
	created_at: string;
	updated_at: string;
}

export interface Wallet {
	user_id: string;
	coins: number;
	updated_at: string;
}

export type TransactionType =
	| "task_reward"
	| "shop_redeem"
	| "transfer_in"
	| "transfer_out"
	| "admin_adjust";

export interface WalletTransaction {
	id: string;
	user_id: string;
	amount: number;
	type: TransactionType;
	description: string | null;
	related_id: string | null;
	created_at: string;
}

export type TaskStatus = "draft" | "published" | "offline";

export interface Task {
	id: string;
	title: string;
	description: string;
	reward_coins: number;
	creator_id: string;
	status: TaskStatus;
	created_at: string;
	updated_at: string;
}

export type TaskClaimStatus = "claimed" | "submitted" | "approved" | "rejected";
export type RewardStatus = "pending" | "paid" | "failed";

export interface TaskClaim {
	id: string;
	task_id: string;
	user_id: string;
	status: TaskClaimStatus;
	proof_text: string | null;
	proof_images: string[];
	submitted_at: string | null;
	reviewed_at: string | null;
	reviewer_id: string | null;
	review_note: string | null;
	reward_status: RewardStatus;
	reward_amount: number | null;
	created_at: string;
	updated_at: string;
}

export type ProductStatus = "active" | "inactive";

export interface Product {
	id: string;
	name: string;
	description: string;
	image_url: string | null;
	price: number;
	status: ProductStatus;
	creator_id: string;
	created_at: string;
	updated_at: string;
}

export type OrderStatus = "pending" | "completed" | "cancelled" | "fulfilled";

export interface Order {
	id: string;
	user_id: string;
	product_id: string;
	price: number;
	status: OrderStatus;
	created_at: string;
}

export interface Transfer {
	id: string;
	sender_id: string;
	receiver_id: string;
	amount: number;
	note: string | null;
	created_at: string;
}

/** 境界配置（基于灵气） */
export interface RealmLevel {
	name: string;
	minQi: number;
}

export const REALM_LEVELS: RealmLevel[] = [
	{ name: "初入修仙", minQi: 0 },
	{ name: "炼气期", minQi: 100 },
	{ name: "筑基期", minQi: 500 },
	{ name: "金丹期", minQi: 1500 },
	{ name: "元婴期", minQi: 5000 },
	{ name: "化神期", minQi: 10000 },
];

export function getRealm(qi: number): string {
	let current = REALM_LEVELS[0].name;
	for (const level of REALM_LEVELS) {
		if (qi >= level.minQi) {
			current = level.name;
		}
	}
	return current;
}

/** 获取境界进度信息（基于灵气） */
export function getRealmProgress(qi: number): {
	currentRealm: string;
	nextRealm: string | null;
	currentQi: number;
	requiredQi: number;
	progress: number;
	isMaxLevel: boolean;
} {
	let currentIndex = 0;
	for (let i = 0; i < REALM_LEVELS.length; i++) {
		if (qi >= REALM_LEVELS[i].minQi) {
			currentIndex = i;
		}
	}

	const isMaxLevel = currentIndex >= REALM_LEVELS.length - 1;
	const current = REALM_LEVELS[currentIndex];
	const next = isMaxLevel ? null : REALM_LEVELS[currentIndex + 1];

	if (isMaxLevel || !next) {
		return {
			currentRealm: current.name,
			nextRealm: null,
			currentQi: qi,
			requiredQi: current.minQi,
			progress: 100,
			isMaxLevel: true,
		};
	}

	const qiRange = next.minQi - current.minQi;
	const qiDone = qi - current.minQi;
	const progress = qiRange > 0 ? Math.min(100, Math.max(0, (qiDone / qiRange) * 100)) : 100;

	return {
		currentRealm: current.name,
		nextRealm: next.name,
		currentQi: qi,
		requiredQi: next.minQi,
		progress,
		isMaxLevel: false,
	};
}

/** 丹药 */
export interface Pill {
	id: string;
	name: string;
	grade: number;
	description: string;
	qi_bonus: number;
	price: number;
	seller_id: string;
	status: "active" | "sold" | "offline";
	created_at: string;
	updated_at: string;
}

/** 储物袋物品 */
export interface InventoryItem {
	id: string;
	user_id: string;
	item_type: "pill" | "product";
	pill_id: string | null;
	product_id: string | null;
	pill_name: string;
	pill_grade: number;
	pill_qi_bonus: number;
	quantity: number;
	status: "owned" | "used" | "listed";
	resell_price: number | null;
	obtained_at: string;
	used_at: string | null;
	listed_at: string | null;
}

/** 转售列表 */
export interface ResellListing {
	id: string;
	inventory_id: string;
	seller_id: string;
	pill_name: string;
	pill_grade: number;
	pill_qi_bonus: number;
	price: number;
	status: "active" | "sold" | "cancelled";
	created_at: string;
	sold_at: string | null;
}
