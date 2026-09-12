/**
 * 评论 / 信号 Service
 * 数据来源：Supabase comments 表
 * 注意：当前评论使用 Twikoo 第三方系统，
 * 此 Service 用于未来自建评论系统。
 */
import { query } from "./base";
import type { Database } from "@/types/database";

export type Comment = Database["public"]["Tables"]["comments"]["Row"];

/** 获取某篇文章的已审核评论（按 post_path 查询） */
export async function getCommentsByPath(postPath: string): Promise<Comment[]> {
	const { data, error } = await query<Comment[]>((client) =>
		client
			.from("comments")
			.select("*")
			.eq("post_path", postPath)
			.eq("status", "approved")
			.order("created_at", { ascending: true }),
	);
	if (error || !data) return [];
	return data;
}

/** 获取某篇文章的已审核评论（树形结构） */
export async function getCommentsByPost(postId: string): Promise<Comment[]> {
	const { data, error } = await query<Comment[]>((client) =>
		client
			.from("comments")
			.select("*")
			.eq("post_id", postId)
			.eq("status", "approved")
			.order("created_at", { ascending: true }),
	);
	if (error || !data) return [];
	return data;
}

/** 获取留言板评论（post_id 为 null） */
export async function getGuestbookComments(): Promise<Comment[]> {
	const { data, error } = await query<Comment[]>((client) =>
		client
			.from("comments")
			.select("*")
			.is("post_id", null)
			.eq("status", "approved")
			.order("created_at", { ascending: false })
			.limit(100),
	);
	if (error || !data) return [];
	return data;
}

/** 提交评论（默认 pending 待审核） */
export async function submitComment(input: {
	nickname: string;
	content: string;
	email?: string;
	website?: string;
	avatar?: string;
	post_id?: string;
	post_path?: string;
	parent_id?: string;
}): Promise<{ success: boolean; message: string }> {
	const { data, error } = await query<Comment[]>((client) =>
		(client.from("comments") as unknown as { insert: (row: Record<string, unknown>) => { select: () => unknown } })
			.insert({
				nickname: input.nickname,
				content: input.content,
				email: input.email ?? null,
				website: input.website ?? null,
				avatar: input.avatar ?? null,
				post_id: input.post_id ?? null,
				post_path: input.post_path ?? null,
				parent_id: input.parent_id ?? null,
				status: "pending",
			})
			.select(),
	);
	if (error || !data) return { success: false, message: "提交失败，请稍后重试" };
	return { success: true, message: "评论已提交，等待审核" };
}

/** 统计评论数量 */
export async function countComments(postId?: string): Promise<number> {
	const { data, error } = await query<{ id: string }[]>((client) => {
		let base = client.from("comments").select("id").eq("status", "approved");
		if (postId) base = base.eq("post_id", postId);
		return base;
	});
	if (error || !data) return 0;
	return data.length;
}
