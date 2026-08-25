// AI 板块：常用 AI 工具数据源（与 ai.astro 共用，便于搜索索引复用）
export interface AiTool {
	name: string;
	logo: string;
	url: string;
}

// 已有本地高清 logo 的工具（优先复用）
const deepseek = { name: "DeepSeek", logo: "/assets/ai-logos/deepseek.png", url: "https://chat.deepseek.com" };
const chatgpt = { name: "ChatGPT", logo: "/assets/ai-logos/chatgpt.png", url: "https://chatgpt.com" };
const claude = { name: "Claude", logo: "/assets/ai-logos/claude.png", url: "https://claude.ai" };
const kimi = { name: "Kimi", logo: "/assets/ai-logos/kimi.png", url: "https://kimi.moonshot.cn" };
const doubao = { name: "豆包", logo: "/assets/ai-logos/doubao.png", url: "https://www.doubao.com" };
const qwen = { name: "通义千问", logo: "/assets/ai-logos/qwen.png", url: "https://tongyi.aliyun.com" };
const jimeng = { name: "即梦 AI", logo: "/assets/ai-logos/jimeng.png", url: "https://jimeng.jianying.com" };
const minimax = { name: "MiniMax", logo: "/assets/ai-logos/minimax.png", url: "https://www.minimaxi.com" };
const ollama = { name: "Ollama", logo: "/assets/ai-logos/ollama.png", url: "https://ollama.com" };
const openclaw = { name: "OpenClaw", logo: "/assets/ai-logos/openclaw.png", url: "https://openclaw.ai" };
const aiStudio = { name: "AI Studio", logo: "/assets/ai-logos/ai-studio.png", url: "https://aistudio.google.com" };
const openrouter = { name: "OpenRouter", logo: "/assets/ai-logos/openrouter.png", url: "https://openrouter.ai" };
const coze = { name: "Coze", logo: "/assets/ai-logos/coze.png", url: "https://www.coze.com" };
const huggingface = { name: "Hugging Face", logo: "/assets/ai-logos/huggingface.png", url: "https://huggingface.co" };

// 其余工具使用各官网真实 favicon（Google favicon 服务，浏览器加载时拉取）
const fav = (domain: string) =>
	`https://www.google.com/s2/favicons?sz=128&domain=${domain}`;

// 按板块分组（AI 页渲染使用）
export interface AiGroup {
	title: string;
	items: AiTool[];
}

export const aiGroups: AiGroup[] = [
	{
		title: "国内 AI",
		items: [
			deepseek,
			kimi,
			doubao,
			qwen,
			minimax,
			coze,
			{ name: "文心一言", logo: fav("yiyan.baidu.com"), url: "https://yiyan.baidu.com" },
			{ name: "智谱清言", logo: fav("chatglm.cn"), url: "https://chatglm.cn" },
			{ name: "讯飞星火", logo: fav("xfyun.cn"), url: "https://www.xfyun.cn" },
			{ name: "百川智能", logo: fav("baichuan-ai.com"), url: "https://www.baichuan-ai.com" },
			{ name: "腾讯元宝", logo: fav("yuanbao.tencent.com"), url: "https://yuanbao.tencent.com" },
			{ name: "腾讯混元", logo: fav("hunyuan.tencent.com"), url: "https://hunyuan.tencent.com" },
			{ name: "阶跃星辰", logo: fav("stepfun.com"), url: "https://www.stepfun.com" },
			{ name: "天工 AI", logo: fav("tiangong.cn"), url: "https://tiangong.cn" },
			{ name: "秘塔 AI", logo: fav("metaso.cn"), url: "https://metaso.cn" },
			{ name: "纳米 AI", logo: fav("nanabot.cn"), url: "https://nanabot.cn" },
			{ name: "商汤商量", logo: fav("sensechat.sensetime.com"), url: "https://sensechat.sensetime.com" },
		],
	},
	{
		title: "国外 AI",
		items: [
			chatgpt,
			claude,
			openclaw,
			aiStudio,
			{ name: "Gemini", logo: fav("gemini.google.com"), url: "https://gemini.google.com" },
			{ name: "Perplexity", logo: fav("perplexity.ai"), url: "https://www.perplexity.ai" },
			{ name: "Mistral", logo: fav("mistral.ai"), url: "https://mistral.ai" },
			{ name: "Poe", logo: fav("poe.com"), url: "https://poe.com" },
			{ name: "Meta AI", logo: fav("meta.ai"), url: "https://meta.ai" },
			{ name: "Copilot", logo: fav("copilot.microsoft.com"), url: "https://copilot.microsoft.com" },
			{ name: "Grok", logo: fav("grok.com"), url: "https://grok.com" },
			{ name: "You.com", logo: fav("you.com"), url: "https://you.com" },
			{ name: "Pi", logo: fav("pi.ai"), url: "https://pi.ai" },
			{ name: "Character.AI", logo: fav("character.ai"), url: "https://character.ai" },
			{ name: "Phind", logo: fav("phind.com"), url: "https://www.phind.com" },
			{ name: "Writesonic", logo: fav("writesonic.com"), url: "https://writesonic.com" },
		],
	},
	{
		title: "绘画",
		items: [
			jimeng,
			{ name: "Midjourney", logo: fav("midjourney.com"), url: "https://www.midjourney.com" },
			{ name: "Stable Diffusion", logo: fav("stability.ai"), url: "https://stability.ai" },
			{ name: "可灵", logo: fav("klingai.com"), url: "https://klingai.com" },
			{ name: "通义万相", logo: fav("wanx.aliyun.com"), url: "https://wanx.aliyun.com" },
			{ name: "文心一格", logo: fav("yige.baidu.com"), url: "https://yige.baidu.com" },
			{ name: "Leonardo.AI", logo: fav("leonardo.ai"), url: "https://leonardo.ai" },
			{ name: "Adobe Firefly", logo: fav("adobe.com"), url: "https://www.firefly.adobe.com" },
			{ name: "海艺 AI", logo: fav("seaart.ai"), url: "https://www.seaart.ai" },
			{ name: "Ideogram", logo: fav("ideogram.ai"), url: "https://ideogram.ai" },
			{ name: "Playground", logo: fav("playground.ai"), url: "https://playground.ai" },
			{ name: "NightCafe", logo: fav("nightcafe.studio"), url: "https://nightcafe.studio" },
			{ name: "无界 AI", logo: fav("wujieai.com"), url: "https://www.wujieai.com" },
			{ name: "DALL·E", logo: fav("openai.com"), url: "https://openai.com/dall-e" },
		],
	},
	{
		title: "模型",
		items: [
			ollama,
			openrouter,
			huggingface,
			{ name: "Replicate", logo: fav("replicate.com"), url: "https://replicate.com" },
			{ name: "Together AI", logo: fav("together.ai"), url: "https://www.together.ai" },
			{ name: "Groq", logo: fav("groq.com"), url: "https://groq.com" },
			{ name: "硅基流动", logo: fav("siliconflow.cn"), url: "https://siliconflow.cn" },
			{ name: "魔搭 ModelScope", logo: fav("modelscope.cn"), url: "https://modelscope.cn" },
			{ name: "Fireworks", logo: fav("fireworks.ai"), url: "https://fireworks.ai" },
			{ name: "DeepInfra", logo: fav("deepinfra.com"), url: "https://deepinfra.com" },
			{ name: "百度千帆", logo: fav("qianfan.cloud.baidu.com"), url: "https://qianfan.cloud.baidu.com" },
			{ name: "阿里百炼", logo: fav("bailian.aliyun.com"), url: "https://bailian.console.aliyun.com" },
			{ name: "NVIDIA NIM", logo: fav("nvidia.com"), url: "https://build.nvidia.com" },
			{ name: "Cerebras", logo: fav("cerebras.ai"), url: "https://www.cerebras.ai" },
			{ name: "Anyscale", logo: fav("anyscale.com"), url: "https://www.anyscale.com" },
		],
	},
];

// 扁平列表（搜索索引使用）
export const aiTools: AiTool[] = aiGroups.flatMap((g) => g.items);
