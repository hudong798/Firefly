/**
 * Supabase 客户端
 *
 * 仅使用 anon key（公开），通过 RLS 控制权限。
 * Service Role Key 只能存在服务端环境变量，禁止进入前端代码。
 *
 * 环境变量（在 .env.local 或 Vercel 中配置）：
 *   PUBLIC_SUPABASE_URL      项目 URL
 *   PUBLIC_SUPABASE_ANON_KEY 匿名公钥
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database";

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL as string | undefined;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY as string | undefined;

/**
 * 浏览器端 Supabase 客户端。
 * 未配置环境变量时返回 null，页面应优雅降级（显示静态数据或空状态）。
 */
export const supabase: SupabaseClient<Database> | null =
	supabaseUrl && supabaseAnonKey
		? createClient<Database>(supabaseUrl, supabaseAnonKey, {
				auth: {
					persistSession: true,
					autoRefreshToken: true,
				},
			})
		: null;

/** Supabase 是否已配置 */
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);
