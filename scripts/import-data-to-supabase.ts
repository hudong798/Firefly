/**
 * 将现有硬编码数据导入 Supabase
 *
 * 用法：
 *   1. 在 .env.local 中配置：
 *      PUBLIC_SUPABASE_URL=...
 *      SUPABASE_SERVICE_ROLE_KEY=...
 *   2. 运行：pnpm dlx tsx scripts/import-data-to-supabase.ts
 *
 * 数据源：
 *   src/data/travels.ts   → travels 表
 *   src/data/tv.ts        → archives 表（影视）
 *   src/data/comics.ts    → archives 表（漫画）
 *   src/data/communities.ts → archives 表（社区）
 *   src/data/tools.ts     → archives 表（工具）
 *   src/data/ai.ts        → ai_tools 表
 */
import { createClient } from "@supabase/supabase-js";
import { travels } from "../src/data/travels";
import { tvSites } from "../src/data/tv";
import { comics } from "../src/data/comics";
import { communities } from "../src/data/communities";
import { toolGroups } from "../src/data/tools";
import { aiTools, aiGroups } from "../src/data/ai";
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

// 手动加载 .env.local（tsx 不会自动加载）
const envPath = resolve(process.cwd(), ".env.local");
if (existsSync(envPath)) {
	const envContent = readFileSync(envPath, "utf-8");
	for (const line of envContent.split("\n")) {
		const trimmed = line.trim();
		if (!trimmed || trimmed.startsWith("#")) continue;
		const eqIdx = trimmed.indexOf("=");
		if (eqIdx > 0) {
			const key = trimmed.slice(0, eqIdx).trim();
			const value = trimmed.slice(eqIdx + 1).trim().replace(/^["']|["']$/g, "");
			if (!(key in process.env)) process.env[key] = value;
		}
	}
}

// ---------- 配置 ----------
const SUPABASE_URL = process.env.PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
	console.error("❌ 缺少环境变量：PUBLIC_SUPABASE_URL 和 SUPABASE_SERVICE_ROLE_KEY");
	console.error("   请在 .env.local 中配置后再运行");
	process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
	auth: { persistSession: false },
});

// ---------- 工具函数 ----------
async function clearTable(table: string) {
	const { error } = await supabase.from(table).delete().neq("id", "00000000-0000-0000-0000-000000000000");
	if (error) console.error(`  清空 ${table} 失败:`, error.message);
}

async function batchInsert(table: string, rows: Record<string, unknown>[]) {
	if (rows.length === 0) return;
	const BATCH = 500;
	for (let i = 0; i < rows.length; i += BATCH) {
		const chunk = rows.slice(i, i + BATCH);
		const { error } = await supabase.from(table).insert(chunk);
		if (error) {
			console.error(`  插入 ${table} 失败 (${i}-${i + chunk.length}):`, error.message);
			return;
		}
	}
}

// ---------- 数据转换 ----------

/** 旅行数据转换 */
function transformTravels() {
	return travels.map((t, idx) => {
		// 解析年份：date "2024.06.12 - 06.20"
		const yearMatch = t.date?.match(/^(\d{4})/);
		const year = yearMatch ? parseInt(yearMatch[1], 10) : null;

		// 解析日期范围
		let startDate: string | null = null;
		let endDate: string | null = null;
		const dateMatch = t.date?.match(/(\d{4})\.(\d{2})\.(\d{2})\s*[-–]\s*(\d{2})\.(\d{2})/);
		if (dateMatch) {
			startDate = `${dateMatch[1]}-${dateMatch[2]}-${dateMatch[3]}`;
			endDate = `${dateMatch[1]}-${dateMatch[4]}-${dateMatch[5]}`;
		} else {
			const singleMatch = t.date?.match(/(\d{4})\.(\d{2})\.(\d{2})/);
			if (singleMatch) startDate = `${singleMatch[1]}-${singleMatch[2]}-${singleMatch[3]}`;
		}

		// 解析地点："日本 · 大阪 / 京都 / 奈良"
		let country = "中国";
		let destination = t.location || "";
		const locMatch = t.location?.match(/^(.+?)\s*[·•]\s*(.+)$/);
		if (locMatch) {
			country = locMatch[1].trim();
			destination = locMatch[2].trim();
		}

		return {
			title: t.title,
			destination,
			country,
			province: null,
			city: null,
			start_date: startDate,
			end_date: endDate,
			description: t.summary || null,
			cover_image: t.cover || null,
			latitude: null,
			longitude: null,
			year,
			tags: t.tags || [],
			content: t.content || null,
			gallery: t.gallery || [],
			sort_order: idx,
			status: "published" as const,
		};
	});
}

/** 档案数据转换（影视/漫画/社区/工具） */
function transformArchives() {
	const rows: Record<string, unknown>[] = [];
	let order = 0;

	// 影视
	for (const item of tvSites) {
		rows.push({
			title: item.name,
			description: null,
			category: "影视",
			cover_image: null,
			url: item.url,
			rating: item.rating ?? null,
			tags: [item.type],
			sort_order: order++,
			status: "published",
		});
	}

	// 漫画
	for (const item of comics) {
		rows.push({
			title: item.name,
			description: null,
			category: "漫画",
			cover_image: null,
			url: item.url,
			rating: null,
			tags: [item.type],
			sort_order: order++,
			status: "published",
		});
	}

	// 社区
	for (const item of communities) {
		rows.push({
			title: item.name,
			description: item.desc || null,
			category: "社区",
			cover_image: null,
			url: item.url,
			rating: null,
			tags: [],
			sort_order: order++,
			status: "published",
		});
	}

	// 工具
	for (const group of toolGroups) {
		for (const item of group.items) {
			rows.push({
				title: item.name,
				description: item.desc || null,
				category: "工具",
				cover_image: null,
				url: item.url,
				rating: null,
				tags: [group.title.replace(/^[^\w\u4e00-\u9fa5]+/, "")],
				sort_order: order++,
				status: "published",
			});
		}
	}

	return rows;
}

/** AI 工具转换 */
function transformAiTools() {
	// 建立 name → category 映射
	const nameToCategory = new Map<string, string>();
	for (const group of aiGroups) {
		for (const item of group.items) {
			nameToCategory.set(item.name, group.title.replace(/^[^\w\u4e00-\u9fa5]+/, ""));
		}
	}

	return aiTools.map((item, idx) => ({
		name: item.name,
		description: null,
		logo: item.logo || null,
		url: item.url,
		category: nameToCategory.get(item.name) || null,
		tags: [],
		rating: null,
		status: "published",
		featured: false,
		sort_order: idx,
	}));
}

// ---------- 主流程 ----------
async function main() {
	console.log("🚀 开始导入数据到 Supabase...");
	console.log(`   URL: ${SUPABASE_URL}`);
	console.log("");

	// 1. 旅行
	console.log("📦 [1/4] 导入旅行数据...");
	const travelRows = transformTravels();
	await clearTable("travels");
	await batchInsert("travels", travelRows);
	console.log(`   ✅ 导入 ${travelRows.length} 条旅行记录`);

	// 2. 档案
	console.log("📦 [2/4] 导入档案数据...");
	const archiveRows = transformArchives();
	await clearTable("archives");
	await batchInsert("archives", archiveRows);
	console.log(`   ✅ 导入 ${archiveRows.length} 条档案记录`);

	// 3. AI 工具
	console.log("📦 [3/4] 导入 AI 工具...");
	const aiRows = transformAiTools();
	await clearTable("ai_tools");
	await batchInsert("ai_tools", aiRows);
	console.log(`   ✅ 导入 ${aiRows.length} 条 AI 工具`);

	// 4. 回声（文章使用 content collection，暂不导入）
	console.log("📦 [4/4] 回声/文章...");
	console.log("   ⏭️  跳过（文章仍使用 Astro content collection，SSG 静态生成）");

	console.log("");
	console.log("🎉 数据导入完成！");
	console.log("   旅行: " + travelRows.length + " 条");
	console.log("   档案: " + archiveRows.length + " 条");
	console.log("   AI工具: " + aiRows.length + " 条");
	console.log("");
	console.log("📝 下一步：");
	console.log("   1. 在 Supabase Dashboard 确认数据已导入");
	console.log("   2. 配置 Vercel 环境变量 PUBLIC_SUPABASE_URL / PUBLIC_SUPABASE_ANON_KEY");
	console.log("   3. 逐模块修改页面，从静态数据切换到 Supabase 查询");
}

main().catch((err) => {
	console.error("❌ 导入失败:", err);
	process.exit(1);
});
