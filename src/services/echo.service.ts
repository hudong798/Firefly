/**
 * 回声 / 文章 Service
 * 数据来源：Supabase echoes 表
 * 注意：当前文章仍主要使用 Astro content collection（SSG），
 * 此 Service 用于未来动态文章或评论关联。
 */
import { query, type Pagination } from "./base";
import type { Database } from "@/types/database";
import type { ThoughtMoment } from "@/data/thoughts";
import { moments as staticMoments } from "@/data/thoughts";

export type Echo = Database["public"]["Tables"]["echoes"]["Row"];

/** 将 Supabase echo 行转换为 ThoughtMoment 格式 */
export function echoToThought(echo: Echo): ThoughtMoment {
	const d = new Date(echo.created_at);
	const y = d.getFullYear();
	const m = String(d.getMonth() + 1).padStart(2, "0");
	const day = String(d.getDate()).padStart(2, "0");
	const h = String(d.getHours()).padStart(2, "0");
	const min = String(d.getMinutes()).padStart(2, "0");
	return {
		id: echo.slug || echo.id,
		date: `${y}-${m}-${day} ${h}:${min}`,
		content: echo.content,
		mood: echo.mood || undefined,
		tags: echo.tags || undefined,
	};
}

/** 获取回声/说说列表（优先 Supabase，降级到静态数据） */
export async function getThoughts(): Promise<ThoughtMoment[]> {
	const { data, error } = await query<Echo[]>((client) =>
		client
			.from("echoes")
			.select("*")
			.eq("status", "published")
			.order("created_at", { ascending: false }),
	);
	if (error || !data || data.length === 0) {
		return staticMoments;
	}
	return data.map(echoToThought);
}

/** 根据 slug 获取单条回声/说说 */
export async function getThoughtBySlug(slug: string): Promise<ThoughtMoment | null> {
	const { data, error } = await query<Echo[]>((client) =>
		client.from("echoes").select("*").eq("slug", slug).eq("status", "published").limit(1),
	);
	if (error || !data || data.length === 0) {
		// 降级到静态数据
		const found = staticMoments.find((m) => m.id === slug);
		return found || null;
	}
	return echoToThought(data[0]);
}

/** 获取文章列表 */
export async function getEchoes(
	opts: { tag?: string; status?: "published" | "draft" } & Pagination = {},
): Promise<Echo[]> {
	const { tag, status = "published", page = 1, pageSize = 20 } = opts;
	const { data, error } = await query<Echo[]>((client) => {
		let base = client.from("echoes").select("*").eq("status", status);
		if (tag) base = base.contains("tags", [tag]);
		return base.order("created_at", { ascending: false }).range(
			(page - 1) * pageSize,
			page * pageSize - 1,
		);
	});
	if (error || !data) return [];
	return data;
}

/** 获取单篇文章 */
export async function getEchoById(id: string): Promise<Echo | null> {
	const { data, error } = await query<Echo[]>((client) =>
		client.from("echoes").select("*").eq("id", id).limit(1),
	);
	if (error || !data || data.length === 0) return null;
	return data[0];
}

/** 增加浏览量 */
export async function incrementEchoView(id: string): Promise<void> {
	await query((client) => (client as unknown as { rpc: (fn: string, args: Record<string, unknown>) => unknown }).rpc("increment_echo_view", { p_id: id }));
}

/** 增加点赞 */
export async function incrementEchoLike(id: string): Promise<void> {
	await query((client) => (client as unknown as { rpc: (fn: string, args: Record<string, unknown>) => unknown }).rpc("increment_echo_like", { p_id: id }));
}
