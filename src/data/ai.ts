// AI 板块：常用 AI 工具数据源（与 ai.astro 共用，便于搜索索引复用）
export interface AiTool {
	name: string;
	logo: string;
	url: string;
}

// 国内 AI
const deepseek = { name: "DeepSeek", logo: "/assets/ai-logos/deepseek.png", url: "https://chat.deepseek.com" };
const kimi = { name: "Kimi", logo: "/assets/ai-logos/kimi.png", url: "https://kimi.moonshot.cn" };
const doubao = { name: "豆包", logo: "/assets/ai-logos/doubao.png", url: "https://www.doubao.com" };
const qwen = { name: "通义千问", logo: "/assets/ai-logos/qwen.png", url: "https://tongyi.aliyun.com" };
const minimax = { name: "MiniMax", logo: "/assets/ai-logos/minimax.png", url: "https://www.minimaxi.com" };
const coze = { name: "Coze", logo: "/assets/ai-logos/coze.png", url: "https://www.coze.com" };
const wenxin = { name: "文心一言", logo: "/assets/ai-logos/wenxin.png", url: "https://yiyan.baidu.com" };
const chatglm = { name: "智谱清言", logo: "/assets/ai-logos/chatglm.png", url: "https://chatglm.cn" };
const xfyun = { name: "讯飞星火", logo: "/assets/ai-logos/xfyun.png", url: "https://www.xfyun.cn" };
const baichuan = { name: "百川智能", logo: "/assets/ai-logos/baichuan.png", url: "https://www.baichuan-ai.com" };
const yuanbao = { name: "腾讯元宝", logo: "/assets/ai-logos/yuanbao.png", url: "https://yuanbao.tencent.com" };
const hunyuan = { name: "腾讯混元", logo: "/assets/ai-logos/hunyuan.png", url: "https://hunyuan.tencent.com" };
const stepfun = { name: "阶跃星辰", logo: "/assets/ai-logos/stepfun.png", url: "https://www.stepfun.com" };
const tiangong = { name: "天工 AI", logo: "/assets/ai-logos/tiangong.png", url: "https://tiangong.cn" };
const metaso = { name: "秘塔 AI", logo: "/assets/ai-logos/metaso.png", url: "https://metaso.cn" };
const nanobot = { name: "纳米 AI", logo: "/assets/ai-logos/nanobot.png", url: "https://nanobot.cn" };
const sensechat = { name: "商汤商量", logo: "/assets/ai-logos/sensechat.png", url: "https://sensechat.sensetime.com" };

// 国外 AI
const chatgpt = { name: "ChatGPT", logo: "/assets/ai-logos/chatgpt.png", url: "https://chatgpt.com" };
const claude = { name: "Claude", logo: "/assets/ai-logos/claude.png", url: "https://claude.ai" };
const openclaw = { name: "OpenClaw", logo: "/assets/ai-logos/openclaw.png", url: "https://openclaw.ai" };
const aiStudio = { name: "AI Studio", logo: "/assets/ai-logos/ai-studio.png", url: "https://aistudio.google.com" };
const gemini = { name: "Gemini", logo: "/assets/ai-logos/gemini.png", url: "https://gemini.google.com" };
const perplexity = { name: "Perplexity", logo: "/assets/ai-logos/perplexity.png", url: "https://www.perplexity.ai" };
const mistral = { name: "Mistral", logo: "/assets/ai-logos/mistral.png", url: "https://mistral.ai" };
const poe = { name: "Poe", logo: "/assets/ai-logos/poe.png", url: "https://poe.com" };
const metaAi = { name: "Meta AI", logo: "/assets/ai-logos/meta-ai.png", url: "https://meta.ai" };
const copilot = { name: "Copilot", logo: "/assets/ai-logos/copilot.png", url: "https://copilot.microsoft.com" };
const grok = { name: "Grok", logo: "/assets/ai-logos/grok.png", url: "https://grok.com" };
const you = { name: "You.com", logo: "/assets/ai-logos/you.png", url: "https://you.com" };
const pi = { name: "Pi", logo: "/assets/ai-logos/pi.png", url: "https://pi.ai" };
const characterAi = { name: "Character.AI", logo: "/assets/ai-logos/character-ai.png", url: "https://character.ai" };
const phind = { name: "Phind", logo: "/assets/ai-logos/phind.png", url: "https://www.phind.com" };
const writesonic = { name: "Writesonic", logo: "/assets/ai-logos/writesonic.png", url: "https://writesonic.com" };

// 绘画
const jimeng = { name: "即梦 AI", logo: "/assets/ai-logos/jimeng.png", url: "https://jimeng.jianying.com" };
const midjourney = { name: "Midjourney", logo: "/assets/ai-logos/midjourney.png", url: "https://www.midjourney.com" };
const stability = { name: "Stable Diffusion", logo: "/assets/ai-logos/stability.png", url: "https://stability.ai" };
const kling = { name: "可灵", logo: "/assets/ai-logos/kling.png", url: "https://klingai.com" };
const wanx = { name: "通义万相", logo: "/assets/ai-logos/wanx.png", url: "https://wanx.aliyun.com" };
const yige = { name: "文心一格", logo: "/assets/ai-logos/yige.png", url: "https://yige.baidu.com" };
const leonardo = { name: "Leonardo.AI", logo: "/assets/ai-logos/leonardo.png", url: "https://leonardo.ai" };
const adobeFirefly = { name: "Adobe Firefly", logo: "/assets/ai-logos/adobe-firefly.png", url: "https://www.firefly.adobe.com" };
const seaart = { name: "海艺 AI", logo: "/assets/ai-logos/seaart.png", url: "https://www.seaart.ai" };
const ideogram = { name: "Ideogram", logo: "/assets/ai-logos/ideogram.png", url: "https://ideogram.ai" };
const playground = { name: "Playground", logo: "/assets/ai-logos/playground.png", url: "https://playground.ai" };
const nightcafe = { name: "NightCafe", logo: "/assets/ai-logos/nightcafe.png", url: "https://nightcafe.studio" };
const wujieai = { name: "无界 AI", logo: "/assets/ai-logos/wujieai.png", url: "https://www.wujieai.com" };
const dalle = { name: "DALL·E", logo: "/assets/ai-logos/dalle.png", url: "https://openai.com/dall-e" };

// 模型
const ollama = { name: "Ollama", logo: "/assets/ai-logos/ollama.png", url: "https://ollama.com" };
const openrouter = { name: "OpenRouter", logo: "/assets/ai-logos/openrouter.png", url: "https://openrouter.ai" };
const huggingface = { name: "Hugging Face", logo: "/assets/ai-logos/huggingface.png", url: "https://huggingface.co" };
const replicate = { name: "Replicate", logo: "/assets/ai-logos/replicate.png", url: "https://replicate.com" };
const together = { name: "Together AI", logo: "/assets/ai-logos/together.png", url: "https://www.together.ai" };
const groqModel = { name: "Groq", logo: "/assets/ai-logos/groq.png", url: "https://groq.com" };
const siliconflow = { name: "硅基流动", logo: "/assets/ai-logos/siliconflow.png", url: "https://siliconflow.cn" };
const modelscope = { name: "魔搭 ModelScope", logo: "/assets/ai-logos/modelscope.png", url: "https://modelscope.cn" };
const fireworks = { name: "Fireworks", logo: "/assets/ai-logos/fireworks.png", url: "https://fireworks.ai" };
const deepinfra = { name: "DeepInfra", logo: "/assets/ai-logos/deepinfra.png", url: "https://deepinfra.com" };
const qianfan = { name: "百度千帆", logo: "/assets/ai-logos/qianfan.png", url: "https://qianfan.cloud.baidu.com" };
const bailian = { name: "阿里百炼", logo: "/assets/ai-logos/bailian.png", url: "https://bailian.console.aliyun.com" };
const nvidia = { name: "NVIDIA NIM", logo: "/assets/ai-logos/nvidia.png", url: "https://build.nvidia.com" };
const cerebras = { name: "Cerebras", logo: "/assets/ai-logos/cerebras.png", url: "https://www.cerebras.ai" };
const anyscale = { name: "Anyscale", logo: "/assets/ai-logos/anyscale.png", url: "https://www.anyscale.com" };

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
			wenxin,
			chatglm,
			xfyun,
			baichuan,
			yuanbao,
			hunyuan,
			stepfun,
			tiangong,
			metaso,
			nanobot,
			sensechat,
		],
	},
	{
		title: "国外 AI",
		items: [
			chatgpt,
			claude,
			openclaw,
			aiStudio,
			gemini,
			perplexity,
			mistral,
			poe,
			metaAi,
			copilot,
			grok,
			you,
			pi,
			characterAi,
			phind,
			writesonic,
		],
	},
	{
		title: "绘画",
		items: [
			jimeng,
			midjourney,
			stability,
			kling,
			wanx,
			yige,
			leonardo,
			adobeFirefly,
			seaart,
			ideogram,
			playground,
			nightcafe,
			wujieai,
			dalle,
		],
	},
	{
		title: "模型",
		items: [
			ollama,
			openrouter,
			huggingface,
			replicate,
			together,
			groqModel,
			siliconflow,
			modelscope,
			fireworks,
			deepinfra,
			qianfan,
			bailian,
			nvidia,
			cerebras,
			anyscale,
		],
	},
];

// 扁平列表（搜索索引使用）
export const aiTools: AiTool[] = aiGroups.flatMap((g) => g.items);
