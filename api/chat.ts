// 博客 AI 对话 —— Vercel Serverless Function
// 代理 DeepSeek API，API Key 只存在服务端环境变量 DEEPSEEK_API_KEY 中，绝不下发到浏览器。
// 部署后访问：POST /api/chat  { messages: [{ role: "user"|"assistant", content: string }] }
// 返回：{ reply: string }

const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";
const MODEL = "deepseek-chat";

const SYSTEM_PROMPT = `你是「itong - 798」个人博客的 AI 助手（域名 52798.xyz，采用 AI 工作台/聊天式风格设计）。
职责：回答访客关于博主、博客内容、网站功能的问题，也可以回答一般性问题。
博客内容概览：DSH（DeepSeek Harness）功能介绍、影视网站资源合集、Markdown/Mermaid/数学公式教程、写真集等。
要求：友好、简洁，使用简体中文回答；不确定的事如实说明，不要编造。`;

// 安全限制：控制单次请求的成本与滥用风险
const MAX_HISTORY = 20; // 最多携带的历史消息条数
const MAX_CHARS = 2000; // 单条消息最大字符数
const MAX_TOKENS = 1024; // 单次回复最大 token 数

export default async function handler(req: any, res: any) {
	// 只允许 POST
	if (req.method !== "POST") {
		res.setHeader("Allow", "POST");
		return res.status(405).json({ error: "Method Not Allowed" });
	}

	const apiKey = process.env.DEEPSEEK_API_KEY;
	if (!apiKey) {
		return res
			.status(500)
			.json({ error: "服务端未配置 DEEPSEEK_API_KEY" });
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
		.slice(-MAX_HISTORY)
		.map((m: any) => ({
			role: m.role,
			content: m.content.slice(0, MAX_CHARS),
		}));

	if (messages.length === 0) {
		return res.status(400).json({ error: "消息不能为空" });
	}

	try {
		const upstream = await fetch(DEEPSEEK_ENDPOINT, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${apiKey}`,
			},
			body: JSON.stringify({
				model: MODEL,
				messages: [
					{ role: "system", content: SYSTEM_PROMPT },
					...messages,
				],
				stream: false,
				temperature: 0.7,
				max_tokens: MAX_TOKENS,
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
