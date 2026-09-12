/**
 * Service 层通用工具
 * 统一处理 Supabase 查询的 loading / success / empty / error 四态
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { supabase, isSupabaseConfigured } from "@/lib/supabase";
import type { Database } from "@/types/database";

export type ServiceResult<T> =
	| { status: "loading"; data: null }
	| { status: "success"; data: T }
	| { status: "empty"; data: [] }
	| { status: "error"; message: string };

/** 安全执行 Supabase 查询，统一错误处理 */
export async function query<T>(
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	fn: (client: SupabaseClient<Database>) => any,
): Promise<{ data: T | null; error: string | null }> {
	if (!isSupabaseConfigured || !supabase) {
		return { data: null, error: "Supabase 未配置" };
	}
	try {
		const { data, error } = await fn(supabase);
		if (error) {
			console.error("[Supabase query error]", error);
			return { data: null, error: "加载失败，请稍后重试" };
		}
		return { data, error: null };
	} catch (err) {
		console.error("[Supabase unexpected error]", err);
		return { data: null, error: "网络异常，请稍后重试" };
	}
}

/** 分页参数 */
export interface Pagination {
	page?: number;
	pageSize?: number;
}

/** 应用分页到 Supabase 查询 */
export function applyPagination(
	q: { range: (from: number, to: number) => unknown },
	{ page = 1, pageSize = 20 }: Pagination,
) {
	const from = (page - 1) * pageSize;
	const to = from + pageSize - 1;
	return q.range(from, to);
}
