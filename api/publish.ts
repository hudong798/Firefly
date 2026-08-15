// 发布文章：校验管理员令牌后，通过 GitHub API 提交新文章到仓库，
// Vercel 检测到推送后自动重新部署上线
export const config = { runtime: "nodejs" };

import { createHmac, timingSafeEqual } from "node:crypto";

const REPO = "hudong798/Firefly";
const BRANCH = "master";

function getSecret(): string {
  return process.env.ADMIN_PASSWORD || "";
}

function signToken(payload: string): string {
  return createHmac("sha256", getSecret()).update(payload).digest("base64url");
}

function verifyToken(token: string | undefined): boolean {
  if (!token) return false;
  const [b64, sig] = token.split(".");
  if (!b64 || !sig) return false;
  let payload: any;
  try {
    payload = JSON.parse(Buffer.from(b64, "base64url").toString("utf8"));
  } catch {
    return false;
  }
  if (
    !payload ||
    payload.role !== "admin" ||
    typeof payload.exp !== "number" ||
    payload.exp < Date.now()
  ) {
    return false;
  }
  const expected = signToken(b64);
  try {
    return timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
  } catch {
    return false;
  }
}

function getCookieToken(req: any): string | undefined {
  const cookie: string | undefined = req.headers.cookie;
  if (!cookie) return undefined;
  for (const part of cookie.split(";")) {
    const idx = part.indexOf("=");
    if (idx < 0) continue;
    const key = part.slice(0, idx).trim();
    if (key === "wb_admin_token") return part.slice(idx + 1).trim();
  }
  return undefined;
}

export default async function handler(req: any, res: any) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  // 1. 鉴权
  if (!verifyToken(getCookieToken(req))) {
    return res.status(401).json({ error: "未登录或无权限" });
  }
  const ghToken = process.env.GITHUB_TOKEN;
  if (!ghToken) {
    return res.status(500).json({ error: "服务端未配置 GITHUB_TOKEN" });
  }

  // 2. 校验输入
  const { title, description, category, tags, content } = req.body || {};
  const clean = (s: unknown) => (typeof s === "string" ? s.trim() : "");
  const t = clean(title);
  const c = clean(content);
  if (!t) return res.status(400).json({ error: "标题不能为空" });
  if (!c) return res.status(400).json({ error: "正文不能为空" });
  if (c.length > 200000) return res.status(400).json({ error: "正文过长" });

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
    return res.status(502).json({
      error: `GitHub 提交失败 ${gh.status}: ${ghData?.message || "unknown"}`,
    });
  }

  return res.status(200).json({ ok: true, slug, url: `/posts/${slug}/` });
}
