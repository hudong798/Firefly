/**
 * 旅行 / 轨迹 Service
 * 数据来源：Supabase travels 表
 * 降级：未配置 Supabase 时返回静态数据（src/data/travels.ts）
 */
import { query, type Pagination } from "./base";
import type { Database } from "@/types/database";
import type { TravelEntry } from "@/data/travels";
import { travels as staticTravels } from "@/data/travels";

export type Travel = Database["public"]["Tables"]["travels"]["Row"];

/** 将 Supabase Travel 记录转换为页面使用的 TravelEntry 格式 */
export function supabaseTravelToEntry(t: Travel): TravelEntry {
	// 格式化日期：start_date "2024-06-12" + end_date "2024-06-20" → "2024.06.12 - 06.20"
	let dateStr = "";
	if (t.start_date) {
		const start = t.start_date.replace(/-/g, ".");
		if (t.end_date) {
			const endMonthDay = t.end_date.slice(5).replace(/-/g, ".");
			dateStr = `${start} - ${endMonthDay}`;
		} else {
			dateStr = start;
		}
	}

	// 格式化地点：country + destination → "日本 · 大阪 / 京都 / 奈良"
	const location = t.country && t.destination ? `${t.country} · ${t.destination}` : t.destination || t.country || "";

	return {
		slug: t.slug || "",
		title: t.title,
		cover: t.cover_image || "",
		date: dateStr,
		location,
		summary: t.description || "",
		tags: t.tags || [],
		content: t.content || undefined,
		gallery: t.gallery || undefined,
	};
}

/** 获取旅行列表（优先 Supabase，降级静态数据） */
export async function getTravelEntries(): Promise<TravelEntry[]> {
	const supabaseData = await getTravels();
	if (supabaseData.length > 0) {
		return supabaseData.map(supabaseTravelToEntry);
	}
	return staticTravels;
}

/** 按 slug 获取单条旅行（优先 Supabase，降级静态数据） */
export async function getTravelEntryBySlug(slug: string): Promise<TravelEntry | null> {
	// 先查 Supabase
	const { data, error } = await query<Travel[]>((client) =>
		client.from("travels").select("*").eq("slug", slug).limit(1),
	);
	if (!error && data && data.length > 0) {
		return supabaseTravelToEntry(data[0]);
	}
	// 降级静态数据
	return staticTravels.find((t) => t.slug === slug) || null;
}

/** 获取旅行列表（按年份倒序、sort_order 排序） */
export async function getTravels(
	opts: { year?: number; status?: "published" | "draft" } & Pagination = {},
): Promise<Travel[]> {
	const { year, status = "published", page = 1, pageSize = 50 } = opts;
	const { data, error } = await query<Travel[]>((client) =>
		client
			.from("travels")
			.select("*")
			.eq("status", status)
			.order("year", { ascending: false })
			.order("sort_order", { ascending: true })
			.range((page - 1) * pageSize, page * pageSize - 1),
	);
	if (error || !data) return [];
	return data;
}

/** 获取单条旅行（按 id） */
export async function getTravelById(id: string): Promise<Travel | null> {
	const { data, error } = await query<Travel[]>((client) =>
		client.from("travels").select("*").eq("id", id).limit(1),
	);
	if (error || !data || data.length === 0) return null;
	return data[0];
}

/** 获取所有可用年份 */
export async function getTravelYears(): Promise<number[]> {
	const { data, error } = await query<{ year: number }[]>((client) =>
		client.from("travels").select("year").eq("status", "published").not("year", "is", null),
	);
	if (error || !data) return [];
	return [...new Set(data.map((d) => d.year).filter(Boolean) as number[])].sort((a, b) => b - a);
}

/** 统计旅行数量 */
export async function countTravels(status: "published" | "draft" = "published"): Promise<number> {
	const { data, error } = await query<{ count: number }[]>((client) =>
		client.from("travels").select("id", { count: "exact" }).eq("status", status),
	);
	if (error || !data) return 0;
	return data.length;
}
