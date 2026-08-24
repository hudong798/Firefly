// AI 板块：常用 AI 工具数据源（与 ai.astro 共用，便于搜索索引复用）
export interface AiTool {
	name: string;
	logo: string;
	url: string;
}

export const aiTools: AiTool[] = [
	{ name: "DeepSeek", logo: "/assets/ai-logos/deepseek.png", url: "https://chat.deepseek.com" },
	{ name: "ChatGPT", logo: "/assets/ai-logos/chatgpt.png", url: "https://chatgpt.com" },
	{ name: "Claude", logo: "/assets/ai-logos/claude.png", url: "https://claude.ai" },
	{ name: "Kimi", logo: "/assets/ai-logos/kimi.png", url: "https://kimi.moonshot.cn" },
	{ name: "豆包", logo: "/assets/ai-logos/doubao.png", url: "https://www.doubao.com" },
	{ name: "通义千问", logo: "/assets/ai-logos/qwen.png", url: "https://tongyi.aliyun.com" },
	{ name: "即梦 AI", logo: "/assets/ai-logos/jimeng.png", url: "https://jimeng.jianying.com" },
	{ name: "MiniMax", logo: "/assets/ai-logos/minimax.png", url: "https://www.minimaxi.com" },
	{ name: "Ollama", logo: "/assets/ai-logos/ollama.png", url: "https://ollama.com" },
	{ name: "OpenClaw", logo: "/assets/ai-logos/openclaw.png", url: "https://openclaw.ai" },
	{ name: "AI Studio", logo: "/assets/ai-logos/ai-studio.png", url: "https://aistudio.google.com" },
	{ name: "OpenRouter", logo: "/assets/ai-logos/openrouter.png", url: "https://openrouter.ai" },
	{ name: "Coze", logo: "/assets/ai-logos/coze.png", url: "https://www.coze.com" },
	{ name: "Hugging Face", logo: "/assets/ai-logos/huggingface.png", url: "https://huggingface.co" },
];
