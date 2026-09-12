/**
 * AI 工具 Service
 * 数据来源：Supabase ai_tools 表
 */
import { query, type Pagination } from "./base";
import type { Database } from "@/types/database";
import { aiGroups as staticAiGroups } from "@/data/ai";

export type AiTool = Database["public"]["Tables"]["ai_tools"]["Row"];

// ---------- 页面使用的数据类型 ----------
export interface AiToolItem {
	name: string;
	url: string;
	logo?: string;
	icon?: string;
}
export interface AiGroup {
	title: string;
	items: AiToolItem[];
}

/** 将 Supabase AiTool 转换为页面使用的格式 */
function toAiToolItem(t: AiTool): AiToolItem {
	return {
		name: t.name,
		url: t.url || "",
		logo: t.logo || undefined,
		icon: "",
	};
}

/** 获取 AI 工具分组（优先 Supabase，降级静态数据） */
export async function getAiToolGroups(): Promise<AiGroup[]> {
	const allTools = await getAiTools({ pageSize: 200 });
	if (allTools.length > 0) {
		// 按 category 分组
		const groupsMap = new Map<string, AiToolItem[]>();
		for (const t of allTools) {
			const cat = t.category || "其他";
			if (!groupsMap.has(cat)) groupsMap.set(cat, []);
			groupsMap.get(cat)!.push(toAiToolItem(t));
		}
		return Array.from(groupsMap.entries()).map(([title, items]) => ({ title, items }));
	}
	// 降级静态数据
	return staticAiGroups.map((g) => ({
		title: g.title,
		items: g.items.map((i) => ({
			name: i.name,
			url: i.url,
			logo: (i as any).logo || undefined,
			icon: (i as any).icon || "",
		})),
	}));
}

/** 获取 AI 工具列表 */
export async function getAiTools(
	opts: { category?: string; featured?: boolean; status?: "published" | "draft" } & Pagination = {},
): Promise<AiTool[]> {
	const { category, featured, status = "published", page = 1, pageSize = 100 } = opts;
	const { data, error } = await query<AiTool[]>((client) => {
		let base = client.from("ai_tools").select("*").eq("status", status);
		if (category) base = base.eq("category", category);
		if (featured !== undefined) base = base.eq("featured", featured);
		return base
			.order("featured", { ascending: false })
			.order("sort_order", { ascending: true })
			.range((page - 1) * pageSize, page * pageSize - 1);
	});
	if (error || !data) return [];
	return data;
}

/** 获取所有分类 */
export async function getAiToolCategories(): Promise<string[]> {
	const { data, error } = await query<{ category: string }[]>((client) =>
		client
			.from("ai_tools")
			.select("category")
			.eq("status", "published")
			.not("category", "is", null),
	);
	if (error || !data) return [];
	return [...new Set(data.map((d) => d.category).filter(Boolean) as string[])].sort();
}

/** 搜索 AI 工具 */
export async function searchAiTools(keyword: string): Promise<AiTool[]> {
	if (!keyword.trim()) return [];
	const { data, error } = await query<AiTool[]>((client) =>
		client
			.from("ai_tools")
			.select("*")
			.eq("status", "published")
			.or(`name.ilike.%${keyword}%,description.ilike.%${keyword}%,tags.cs.{${keyword}}`)
			.limit(50),
	);
	if (error || !data) return [];
	return data;
}
