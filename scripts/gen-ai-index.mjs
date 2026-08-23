// 生成 AI 检索用的文章索引：扫描 posts 目录，输出 public/ai-posts.json
// 由构建脚本在 astro build 前执行，保证索引始终与文章同步
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import matter from "gray-matter";

const dir = join(process.cwd(), "src/content/posts");
const files = readdirSync(dir).filter(
  (f) => f.endsWith(".md") || f.endsWith(".mdx"),
);

const posts = [];
for (const f of files) {
  const raw = readFileSync(join(dir, f), "utf8");
  const { data, content } = matter(raw);
  if (data.draft) continue;

  const slug = f.replace(/\.(md|mdx)$/, "");

  // 粗略清洗 markdown：去代码块/HTML/图片/链接语法，保留可检索文本
  const text = content
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/!\[[^\]]*\]\([^)]*\)/g, " ")
    .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    .replace(/[#*_>`~\-|]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  posts.push({
    slug,
    title: data.title || slug,
    description: data.description || "",
    tags: data.tags || [],
    category: data.category || "",
    published: data.published
      ? String(data.published).slice(0, 10)
      : "",
    text: text.slice(0, 2000),
  });
}

writeFileSync(
  join(process.cwd(), "public/ai-posts.json"),
  JSON.stringify(posts, null, 2),
);
console.log(
  `✅ AI 文章索引已生成: ${posts.length} 篇 -> public/ai-posts.json`,
);
