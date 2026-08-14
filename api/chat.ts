// 博客 AI 对话 —— Vercel Serverless Function
// 1) 代理 DeepSeek API（Key 只存服务端环境变量 DEEPSEEK_API_KEY）
// 2) 站内文章检索（RAG）：根据用户问题从 public/ai-posts.json 检索相关文章，
//    把内容摘要注入上下文，让 AI 能引用站内文章并返回可点击链接。
// 部署后访问：POST /api/chat  { messages: [{ role: "user"|"assistant", content: string }] }
// 返回：{ reply: string }

import aiPosts from "../public/ai-posts.json";

const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";
const MODEL = "deepseek-chat";
const RETRIEVE_TOP_K = 4; // 检索返回的最相关文章数
const CONTEXT_CHARS = 800; // 每篇文章注入的内容长度

// ---------- 检索 ----------
function normalize(s: string): string {
  return s.toLowerCase();
}

// 提取查询词：英文单词 + 中文单字/双字组合
function extractTerms(query: string): string[] {
  const q = normalize(query).trim();
  const terms = new Set<string>();
  for (const m of q.matchAll(/[a-z0-9]+/g)) {
    if (m[0].length > 0) terms.add(m[0]);
  }
  const cjk = q.match(/[\u4e00-\u9fa5]+/g) || [];
  for (const chunk of cjk) {
    if (chunk.length <= 2) terms.add(chunk);
    for (let i = 0; i < chunk.length - 1; i++) terms.add(chunk.slice(i, i + 2));
  }
  return [...terms].filter((t) => t.length > 0);
}

// 按关键词命中给每篇文章打分（标题/标签权重高）
function retrieve(query: string, posts: any[], k = RETRIEVE_TOP_K): any[] {
  const terms = extractTerms(query);
  if (terms.length === 0) return [];
  const scored = posts.map((p) => {
    const title = normalize(p.title);
    const tags = (p.tags || []).join(" ").toLowerCase();
    const desc = normalize(p.description);
    const text = normalize(p.text);
    let score = 0;
    for (const t of terms) {
      if (title.includes(t)) score += 3;
      if (tags.includes(t)) score += 2.5;
      if (desc.includes(t)) score += 2;
      if (text.includes(t)) score += 1;
    }
    return { p, score };
  });
  return scored
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, k)
    .map((x) => x.p);
}

function buildContext(posts: any[]): string {
  return posts
    .map(
      (p, i) =>
        `【站内文章 ${i + 1}】\n标题：${p.title}\n链接：/posts/${p.slug}/\n标签：${(p.tags || []).join("、") || "无"}\n摘要：${(p.description || p.text).slice(0, 200)}\n内容：${p.text.slice(0, CONTEXT_CHARS)}`,
    )
    .join("\n\n---\n\n");
}

function buildPostList(posts: any[]): string {
  return posts
    .map((p) => `- ${p.title} -> /posts/${p.slug}/`)
    .join("\n");
}

const BASE_SYSTEM_PROMPT = `你是「itong - 798」个人博客的 AI 助手（域名 52798.xyz，采用 AI 工作台/聊天式风格设计）。
职责：回答访客关于博主、博客内容、网站功能的问题，也可以回答一般性问题。
当用户询问站内内容时，优先基于下方提供的「站内文章」回答，并用 Markdown 链接格式引用文章，例如 [文章标题](/posts/文章slug/)，让用户可以直接点击进入文章。
如果用户的问题与站内文章无关，正常回答即可；不确定的事如实说明，不要编造。
要求：友好、简洁，使用简体中文回答。`;

export default async function handler(req: any, res: any) {
  // 只允许 POST
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: "服务端未配置 DEEPSEEK_API_KEY" });
  }

  const raw = req.body || {};
  let messages = Array.isArray(raw.messages) ? raw.messages : [];

  // 校验、裁剪历史消息
  messages = messages
    .filter(
      (m: any) =>
        m &&
        (m.role === "user" || m.role === "assistant") &&
        typeof m.content === "string",
    )
    .slice(-20)
    .map((m: any) => ({
      role: m.role,
      content: m.content.slice(0, 2000),
    }));

  if (messages.length === 0) {
    return res.status(400).json({ error: "消息不能为空" });
  }

  // 用最近一条用户消息做站内检索
  const lastUser = [...messages].reverse().find((m: any) => m.role === "user");
  const query = lastUser ? lastUser.content : "";
  const hitPosts = retrieve(query, aiPosts);
  const siteContext =
    hitPosts.length > 0
      ? `站内检索到相关文章：\n${buildContext(hitPosts)}`
      : "（本次未检索到直接相关的站内文章，可按需从站内全部文章列表中引用）";
  const allPosts = buildPostList(aiPosts);

  const systemPrompt = `${BASE_SYSTEM_PROMPT}

站内全部文章列表（共 ${aiPosts.length} 篇）：
${allPosts}

${siteContext}`;

  try {
    const upstream = await fetch(DEEPSEEK_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [{ role: "system", content: systemPrompt }, ...messages],
        stream: false,
        temperature: 0.7,
        max_tokens: 1024,
      }),
    });

    const data = await upstream.json();

    if (!upstream.ok) {
      return res.status(502).json({
        error: `上游错误 ${upstream.status}: ${
          data?.error?.message || "unknown"
        }`,
      });
    }

    const reply = data?.choices?.[0]?.message?.content?.trim();
    if (!reply) {
      return res.status(502).json({ error: "上游返回空回复" });
    }

    return res.status(200).json({ reply });
  } catch (e: any) {
    return res.status(500).json({
      error: `调用失败: ${e?.message || "unknown"}`,
    });
  }
}
