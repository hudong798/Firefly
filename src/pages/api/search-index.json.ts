// 统一搜索索引端点：构建期生成静态 JSON（/api/search-index.json）
// 聚合 7 个板块内容，每条带 section / sectionLabel / title / snippet / tags / url / external / search
// 前端顶部搜索框据此实现「跨板块搜索」，结果会标注来自哪个板块。
import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import { moments } from "@/data/thoughts";
import { travels } from "@/data/travels";
import { tvSites, tvOthers, tvParsers, tvAdult } from "@/data/tv";
import { aiTools } from "@/data/ai";
import { toolGroups } from "@/data/tools";
import { onlineGames, builtinGames } from "@/data/games";
import { removeFileExtension } from "@/utils/url-utils";

// 清洗 markdown：去代码块/HTML/图片/链接语法，保留可检索文本
function cleanMarkdown(raw: string): string {
	return raw
		.replace(/```[\s\S]*?```/g, " ")
		.replace(/<[^>]+>/g, " ")
		.replace(/!\[[^\]]*\]\([^)]*\)/g, " ")
		.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
		.replace(/[#*_>`~\-|]/g, " ")
		.replace(/\s+/g, " ")
		.trim();
}

interface IndexItem {
	id: string;
	section: string;
	sectionLabel: string;
	title: string;
	snippet: string;
	tags: string[];
	url: string;
	external: boolean;
	search: string;
}

export const GET: APIRoute = async () => {
	const items: IndexItem[] = [];

	// ---- 文章 ----
	const posts = await getCollection("posts");
	for (const p of posts) {
		if (p.data.draft) continue;
		const slug = removeFileExtension(p.id);
		const text = cleanMarkdown(p.body ?? "");
		const title = p.data.title || slug;
		const tags = (p.data.tags || []).map(String);
		const snippet = p.data.description || text.slice(0, 90);
		const search = [title, p.data.description, tags.join(" "), p.data.category, text]
			.join(" ")
			.toLowerCase();
		items.push({
			id: `post-${slug}`,
			section: "post",
			sectionLabel: "文章",
			title,
			snippet,
			tags,
			url: `/posts/${slug}/`,
			external: false,
			search,
		});
	}

	// ---- 说说 ----
	for (const m of moments) {
		const tags = (m.tags || []).map(String);
		const search = [m.content, tags.join(" "), m.date, m.mood]
			.join(" ")
			.toLowerCase();
		items.push({
			id: `thought-${m.id}`,
			section: "thought",
			sectionLabel: "说说",
			title: `说说 · ${m.date}`,
			snippet: m.content,
			tags,
			url: `/thoughts/${m.id}/`,
			external: false,
			search,
		});
	}

	// ---- 旅游 ----
	for (const t of travels) {
		const tags = (t.tags || []).map(String);
		const search = [t.title, t.summary, tags.join(" "), t.location, t.date, t.content]
			.join(" ")
			.toLowerCase();
		items.push({
			id: `travel-${t.slug}`,
			section: "travel",
			sectionLabel: "旅游",
			title: t.title,
			snippet: `${t.location} · ${t.summary}`,
			tags,
			url: `/travel/${t.slug}/`,
			external: false,
			search,
		});
	}

	// ---- 影视 ----
	for (const s of tvSites) {
		const search = [s.name, s.type, "影视", "电影", "电视剧", "动漫", "在线观看"]
			.join(" ")
			.toLowerCase();
		items.push({
			id: `tv-site-${s.name}`,
			section: "tv",
			sectionLabel: "影视",
			title: s.name,
			snippet: `影视网站（${s.type}）· 在线观影`,
			tags: [s.type],
			url: s.url,
			external: true,
			search,
		});
	}
	for (const o of tvOthers) {
		items.push({
			id: `tv-other-${o.name}`,
			section: "tv",
			sectionLabel: "影视",
			title: o.name,
			snippet: "影视相关推荐站点",
			tags: ["推荐"],
			url: o.url,
			external: true,
			search: [o.name, "影视", "推荐"].join(" ").toLowerCase(),
		});
	}
	for (const p of tvParsers) {
		items.push({
			id: `tv-parser-${p.name}`,
			section: "tv",
			sectionLabel: "影视",
			title: p.name,
			snippet: "视频解析接口",
			tags: ["解析"],
			url: p.url,
			external: true,
			search: [p.name, "解析", "影视"].join(" ").toLowerCase(),
		});
	}
	for (const a of tvAdult) {
		items.push({
			id: `tv-adult-${a.no}`,
			section: "tv",
			sectionLabel: "影视",
			title: `${a.no}. ${a.site}`,
			snippet: "18+ 专区（需手动输入域名）",
			tags: ["18+"],
			url: `/tv/`,
			external: false,
			search: [a.site, "18", "成人", "影视"].join(" ").toLowerCase(),
		});
	}

	// ---- AI ----
	for (const t of aiTools) {
		items.push({
			id: `ai-${t.name}`,
			section: "ai",
			sectionLabel: "AI",
			title: t.name,
			snippet: "AI 工具 · 点击直达官网",
			tags: ["AI"],
			url: t.url,
			external: true,
			search: [t.name, "AI", "人工智能", "对话", "大模型"].join(" ").toLowerCase(),
		});
	}

	// ---- 工具 ----
	for (const g of toolGroups) {
		for (const it of g.items) {
			items.push({
				id: `tool-${it.name}`,
				section: "tool",
				sectionLabel: "工具",
				title: it.name,
				snippet: `${g.title.replace(/^[🔧🎨💻📦]\s*/, "")} · ${it.desc}`,
				tags: [g.title.replace(/^[🔧🎨💻📦]\s*/, "")],
				url: it.url,
				external: true,
				search: [it.name, it.desc, g.title, "工具"].join(" ").toLowerCase(),
			});
		}
	}

	// ---- 游戏 ----
	for (const g of [...onlineGames, ...builtinGames]) {
		items.push({
			id: `game-${g.name}`,
			section: "game",
			sectionLabel: "游戏",
			title: g.name,
			snippet: g.desc,
			tags: ["游戏"],
			url: g.url,
			external: !g.url.startsWith("/"),
			search: [g.name, g.desc, "游戏", "在线"].join(" ").toLowerCase(),
		});
	}

	return new Response(JSON.stringify(items), {
		headers: {
			"Content-Type": "application/json; charset=utf-8",
			"Cache-Control": "public, max-age=3600",
		},
	});
};
