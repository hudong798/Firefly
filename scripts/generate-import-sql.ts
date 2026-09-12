/**
 * 生成数据导入 SQL（用于在 Supabase SQL Editor 中执行）
 * 用法：pnpm dlx tsx scripts/generate-import-sql.ts
 * 输出：supabase/seed.sql
 */
import { travels } from "../src/data/travels";
import { tvSites } from "../src/data/tv";
import { comics } from "../src/data/comics";
import { communities } from "../src/data/communities";
import { toolGroups } from "../src/data/tools";
import { aiTools, aiGroups } from "../src/data/ai";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

// ---------- 工具函数 ----------
function escapeSql(val: unknown): string {
	if (val === null || val === undefined) return "NULL";
	if (typeof val === "number") return String(val);
	if (typeof val === "boolean") return val ? "true" : "false";
	if (Array.isArray(val)) {
		if (val.length === 0) return "ARRAY[]::text[]";
		const items = val.map((v) => escapeSql(v)).join(", ");
		return `ARRAY[${items}]`;
	}
	const str = String(val).replace(/'/g, "''");
	return `'${str}'`;
}

function generateInsert(table: string, rows: Record<string, unknown>[]): string {
	if (rows.length === 0) return "";
	const columns = Object.keys(rows[0]);
	const values = rows.map((row) => {
		const vals = columns.map((col) => escapeSql(row[col]));
		return `  (${vals.join(", ")})`;
	});
	return `INSERT INTO public.${table} (${columns.join(", ")}) VALUES\n${values.join(",\n")};\n`;
}

// ---------- 数据转换 ----------
function transformTravels() {
	return travels.map((t: any, idx: number) => {
		const yearMatch = t.date?.match(/^(\d{4})/);
		const year = yearMatch ? parseInt(yearMatch[1], 10) : null;

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
			status: "published",
		};
	});
}

function transformArchives() {
	const rows: Record<string, unknown>[] = [];
	let order = 0;

	for (const item of tvSites as any[]) {
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

	for (const item of comics as any[]) {
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

	for (const item of communities as any[]) {
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

	for (const group of toolGroups as any[]) {
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

function transformAiTools() {
	const nameToCategory = new Map<string, string>();
	for (const group of aiGroups as any[]) {
		for (const item of group.items) {
			nameToCategory.set(item.name, group.title.replace(/^[^\w\u4e00-\u9fa5]+/, ""));
		}
	}

	return (aiTools as any[]).map((item, idx) => ({
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
function main() {
	console.log("🚀 生成数据导入 SQL...");

	const travelRows = transformTravels();
	const archiveRows = transformArchives();
	const aiRows = transformAiTools();

	let sql = "-- ============================================================\n";
	sql += "-- FreeX 数据导入 Seed\n";
	sql += "-- 旅行: " + travelRows.length + " 条\n";
	sql += "-- 档案: " + archiveRows.length + " 条\n";
	sql += "-- AI工具: " + aiRows.length + " 条\n";
	sql += "-- ============================================================\n\n";

	// 清空表（避免重复导入）
	sql += "DELETE FROM public.travels;\n";
	sql += "DELETE FROM public.archives;\n";
	sql += "DELETE FROM public.ai_tools;\n\n";

	// 旅行
	sql += "-- ---------- 旅行数据 ----------\n";
	sql += generateInsert("travels", travelRows);
	sql += "\n";

	// 档案
	sql += "-- ---------- 档案数据 ----------\n";
	sql += generateInsert("archives", archiveRows);
	sql += "\n";

	// AI 工具
	sql += "-- ---------- AI 工具数据 ----------\n";
	sql += generateInsert("ai_tools", aiRows);
	sql += "\n";

	const outputPath = resolve(process.cwd(), "supabase/seed.sql");
	writeFileSync(outputPath, sql, "utf-8");

	console.log("✅ 已生成:", outputPath);
	console.log("   旅行:", travelRows.length, "条");
	console.log("   档案:", archiveRows.length, "条");
	console.log("   AI工具:", aiRows.length, "条");
	console.log("   文件大小:", (sql.length / 1024).toFixed(1), "KB");
	console.log("");
	console.log("📝 下一步：在 Supabase SQL Editor 中打开并执行 supabase/seed.sql");
}

main();
