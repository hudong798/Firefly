// 发布文章：校验管理员令牌后，通过 GitHub API 提交新文章到仓库，
// Vercel 检测到推送后自动重新部署上线
import { json, getCookieToken, verifyToken } from "./_lib";

const REPO = "hudong798/Firefly";
const BRANCH = "master";

export default async function handler(req: any, res: any) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return json(res, 405, { error: "Method Not Allowed" });
  }

  // 1. 鉴权
  if (!verifyToken(getCookieToken(req))) {
    return json(res, 401, { error: "未登录或无权限" });
  }
  const ghToken = process.env.GITHUB_TOKEN;
  if (!ghToken) {
    return json(res, 500, { error: "服务端未配置 GITHUB_TOKEN" });
  }

  // 2. 校验输入
  const { title, description, category, tags, content } = req.body || {};
  const clean = (s: unknown) => (typeof s === "string" ? s.trim() : "");
  const t = clean(title);
  const c = clean(content);
  if (!t) return json(res, 400, { error: "标题不能为空" });
  if (!c) return json(res, 400, { error: "正文不能为空" });
  if (c.length > 200000) return json(res, 400, { error: "正文过长" });

  // 3. 生成 slug 与 frontmatter
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  const dateStr = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(
    now.getDate(),
  )}`;
  const rand = Math.random().toString(36).slice(2, 6);
  const slug = `post-${dateStr.replace(/-/g, "")}-${pad(
    now.getHours(),
  )}${pad(now.getMinutes())}-${rand}`;

  const tagList = clean(tags)
    .split(/[,，]/)
    .map((s) => s.trim())
    .filter(Boolean);
  const cat = clean(category);
  const desc = clean(description);

  const quote = (s: string) => JSON.stringify(s);
  const fmLines = [
    "---",
    `title: ${quote(t)}`,
    `published: ${dateStr}`,
    "draft: false",
    `tags: [${tagList.map(quote).join(", ")}]`,
    `category: ${cat ? quote(cat) : ""}`,
    desc ? `description: ${quote(desc)}` : "",
    "---",
    "",
    c,
    "",
  ];
  const markdown = fmLines.join("\n");

  // 4. 提交到 GitHub
  const path = `src/content/posts/${slug}.md`;
  const gh = await fetch(`https://api.github.com/repos/${REPO}/contents/${path}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${ghToken}`,
      "Content-Type": "application/json",
      "User-Agent": "firefly-admin",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: JSON.stringify({
      message: `feat: 新文章 ${t}`,
      content: Buffer.from(markdown, "utf8").toString("base64"),
      branch: BRANCH,
    }),
  });

  const ghData = await gh.json().catch(() => ({}));
  if (!gh.ok) {
    return json(res, 502, {
      error: `GitHub 提交失败 ${gh.status}: ${ghData?.message || "unknown"}`,
    });
  }

  return json(res, 200, { ok: true, slug, url: `/posts/${slug}/` });
}
