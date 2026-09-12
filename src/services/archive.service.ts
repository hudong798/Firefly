/**
 * 档案 / 收藏 Service
 * 数据来源：Supabase archives 表
 * 分类：影视 / 漫画 / 社区 / 工具
 */
import { query, type Pagination } from "./base";
import type { Database } from "@/types/database";
import { tvSites as staticTvSites } from "@/data/tv";
import { comics as staticComics } from "@/data/comics";
import { communities as staticCommunities } from "@/data/communities";
import { toolGroups as staticToolGroups } from "@/data/tools";

export type Archive = Database["public"]["Tables"]["archives"]["Row"];
export type ArchiveCategory = "影视" | "漫画" | "社区" | "工具";

export const ARCHIVE_CATEGORIES: ArchiveCategory[] = ["影视", "漫画", "社区", "工具"];

// ---------- 页面使用的数据类型 ----------
export interface TvSite {
	name: string;
	url: string;
	type: string;
	rating?: number;
}
export interface ComicSite {
	name: string;
	url: string;
	type: string;
}
export interface CommunitySite {
	name: string;
	url: string;
	desc?: string;
}
export interface ToolSite {
	name: string;
	url: string;
	desc?: string;
	icon?: string;
}
export interface ToolGroup {
	title: string;
	items: ToolSite[];
}

// ---------- 数据转换 ----------
/** 将 Supabase Archive 转换为影视站点格式 */
function toTvSite(a: Archive): TvSite {
	return {
		name: a.title,
		url: a.url || "",
		type: a.tags?.[0] || "综合",
		rating: a.rating ?? undefined,
	};
}

/** 将 Supabase Archive 转换为漫画站点格式 */
function toComicSite(a: Archive): ComicSite {
	return {
		name: a.title,
		url: a.url || "",
		type: a.tags?.[0] || "漫画",
	};
}

/** 将 Supabase Archive 转换为社区站点格式 */
function toCommunitySite(a: Archive): CommunitySite {
	return {
		name: a.title,
		url: a.url || "",
		desc: a.description || undefined,
	};
}

/** 将 Supabase Archive 转换为工具站点格式 */
function toToolSite(a: Archive): ToolSite {
	return {
		name: a.title,
		url: a.url || "",
		desc: a.description || undefined,
		icon: "",
	};
}

/** 从 Supabase 获取所有档案（带降级） */
async function getAllArchives(): Promise<Archive[]> {
	const data = await getArchives({ pageSize: 500 });
	return data;
}

/** 获取影视站点列表（优先 Supabase，降级静态数据） */
export async function getTvSites(): Promise<TvSite[]> {
	const archives = await getAllArchives();
	const tvArchives = archives.filter((a) => a.category === "影视");
	if (tvArchives.length > 0) {
		return tvArchives.map(toTvSite);
	}
	return staticTvSites.map((s) => ({ name: s.name, url: s.url, type: s.type, rating: s.rating }));
}

/** 获取漫画站点列表（优先 Supabase，降级静态数据） */
export async function getComicSites(): Promise<ComicSite[]> {
	const archives = await getAllArchives();
	const comicArchives = archives.filter((a) => a.category === "漫画");
	if (comicArchives.length > 0) {
		return comicArchives.map(toComicSite);
	}
	return staticComics.map((c) => ({ name: c.name, url: c.url, type: c.type }));
}

/** 获取社区站点列表（优先 Supabase，降级静态数据） */
export async function getCommunitySites(): Promise<CommunitySite[]> {
	const archives = await getAllArchives();
	const communityArchives = archives.filter((a) => a.category === "社区");
	if (communityArchives.length > 0) {
		return communityArchives.map(toCommunitySite);
	}
	return staticCommunities.map((c) => ({ name: c.name, url: c.url, desc: c.desc }));
}

/** 获取工具分组列表（优先 Supabase，降级静态数据） */
export async function getToolGroups(): Promise<ToolGroup[]> {
	const archives = await getAllArchives();
	const toolArchives = archives.filter((a) => a.category === "工具");
	if (toolArchives.length > 0) {
		// 按 tags[0] 分组
		const groupsMap = new Map<string, ToolSite[]>();
		for (const a of toolArchives) {
			const groupName = a.tags?.[0] || "其他工具";
			if (!groupsMap.has(groupName)) groupsMap.set(groupName, []);
			groupsMap.get(groupName)!.push(toToolSite(a));
		}
		return Array.from(groupsMap.entries()).map(([title, items]) => ({ title, items }));
	}
	return staticToolGroups.map((g) => ({
		title: g.title,
		items: g.items.map((i) => ({ name: i.name, url: i.url, desc: i.desc, icon: (i as any).icon || "" })),
	}));
}

/** 获取档案列表 */
export async function getArchives(
	opts: { category?: ArchiveCategory; status?: "published" | "draft" } & Pagination = {},
): Promise<Archive[]> {
	const { category, status = "published", page = 1, pageSize = 100 } = opts;
	let q = query<Archive[]>((client) => {
		let base = client.from("archives").select("*").eq("status", status);
		if (category) base = base.eq("category", category);
		return base.order("sort_order", { ascending: true }).range(
			(page - 1) * pageSize,
			page * pageSize - 1,
		);
	});
	const { data, error } = await q;
	if (error || !data) return [];
	return data;
}

/** 按分类分组获取 */
export async function getArchivesGroupedByCategory(): Promise<Record<ArchiveCategory, Archive[]>> {
	const all = await getArchives({ pageSize: 500 });
	const grouped = {} as Record<ArchiveCategory, Archive[]>;
	for (const cat of ARCHIVE_CATEGORIES) grouped[cat] = [];
	for (const item of all) {
		if (ARCHIVE_CATEGORIES.includes(item.category as ArchiveCategory)) {
			grouped[item.category as ArchiveCategory].push(item);
		}
	}
	return grouped;
}

/** 统计各分类数量 */
export async function countArchivesByCategory(): Promise<Record<ArchiveCategory, number>> {
	const all = await getArchives({ pageSize: 500 });
	const counts = {} as Record<ArchiveCategory, number>;
	for (const cat of ARCHIVE_CATEGORIES) counts[cat] = 0;
	for (const item of all) {
		if (ARCHIVE_CATEGORIES.includes(item.category as ArchiveCategory)) {
			counts[item.category as ArchiveCategory]++;
		}
	}
	return counts;
}
