/**
 * Supabase 数据库类型定义
 * 与 supabase/schema.sql 中的表结构对应
 */

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Database {
	public: {
		Tables: {
			/** 回声 / 文章 */
			echoes: {
				Row: {
					id: string;
					title: string;
					content: string;
					excerpt: string | null;
					cover_image: string | null;
					tags: string[] | null;
					status: "draft" | "published";
					view_count: number;
					like_count: number;
					created_at: string;
					updated_at: string;
				};
				Insert: Partial<Database["public"]["Tables"]["echoes"]["Row"]>;
				Update: Partial<Database["public"]["Tables"]["echoes"]["Row"]>;
			};

			/** 旅行 / 轨迹 */
			travels: {
				Row: {
					id: string;
					title: string;
					destination: string;
					country: string;
					province: string | null;
					city: string | null;
					start_date: string | null;
					end_date: string | null;
					description: string | null;
					cover_image: string | null;
					latitude: number | null;
					longitude: number | null;
					year: number | null;
					tags: string[] | null;
					content: string | null;
					gallery: string[] | null;
					sort_order: number;
					status: "draft" | "published";
					created_at: string;
					updated_at: string;
				};
				Insert: Partial<Database["public"]["Tables"]["travels"]["Row"]>;
				Update: Partial<Database["public"]["Tables"]["travels"]["Row"]>;
			};

			/** 档案 / 收藏 */
			archives: {
				Row: {
					id: string;
					title: string;
					description: string | null;
					category: "影视" | "漫画" | "社区" | "工具";
					cover_image: string | null;
					url: string;
					rating: number | null;
					tags: string[] | null;
					sort_order: number;
					status: "draft" | "published";
					created_at: string;
					updated_at: string;
				};
				Insert: Partial<Database["public"]["Tables"]["archives"]["Row"]>;
				Update: Partial<Database["public"]["Tables"]["archives"]["Row"]>;
			};

			/** 评论 / 信号 */
			comments: {
				Row: {
					id: string;
					post_id: string | null;
					nickname: string;
					email: string | null;
					website: string | null;
					content: string;
					avatar: string | null;
					parent_id: string | null;
					status: "pending" | "approved" | "hidden";
					created_at: string;
					updated_at: string;
				};
				Insert: Partial<Database["public"]["Tables"]["comments"]["Row"]>;
				Update: Partial<Database["public"]["Tables"]["comments"]["Row"]>;
			};

			/** AI 工具 */
			ai_tools: {
				Row: {
					id: string;
					name: string;
					description: string | null;
					logo: string | null;
					url: string;
					category: string | null;
					tags: string[] | null;
					rating: number | null;
					status: "draft" | "published";
					featured: boolean;
					sort_order: number;
					created_at: string;
					updated_at: string;
				};
				Insert: Partial<Database["public"]["Tables"]["ai_tools"]["Row"]>;
				Update: Partial<Database["public"]["Tables"]["ai_tools"]["Row"]>;
			};
		};
		Views: Record<string, never>;
		Functions: {
			increment_echo_view: {
				Args: { p_id: string };
				Returns: undefined;
			};
			increment_echo_like: {
				Args: { p_id: string };
				Returns: undefined;
			};
		};
		Enums: Record<string, never>;
	};
}
