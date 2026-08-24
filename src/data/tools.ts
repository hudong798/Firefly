// 工具板块：按分组展示的工具网站数据源（与 tools.astro 共用）
export interface ToolItem {
	name: string;
	icon: string;
	desc: string;
	url: string;
}

export interface ToolGroup {
	title: string;
	items: ToolItem[];
}

export const toolGroups: ToolGroup[] = [
	{
		title: "🔧 效率工具",
		items: [
			{ name: "Notion", icon: "📓", desc: "笔记 / 知识库", url: "https://www.notion.so" },
			{ name: "语雀", icon: "🐦", desc: "中文知识库", url: "https://www.yuque.com" },
			{ name: "飞书", icon: "💬", desc: "文档 / 协作", url: "https://www.feishu.cn" },
			{ name: "幕布", icon: "🗂️", desc: "大纲 / 思维导图", url: "https://mubu.com" },
			{ name: "XMind", icon: "🧠", desc: "思维导图", url: "https://xmind.cn" },
		],
	},
	{
		title: "🎨 设计素材",
		items: [
			{ name: "Iconify", icon: "🔣", desc: "海量图标库", url: "https://icones.js.org" },
			{ name: "Coolors", icon: "🌈", desc: "配色方案生成", url: "https://coolors.co" },
			{ name: "Unsplash", icon: "📷", desc: "免费高清图", url: "https://unsplash.com" },
			{ name: "阿里巴巴矢量图标库", icon: "🛍️", desc: "中文图标", url: "https://www.iconfont.cn" },
		],
	},
	{
		title: "💻 开发工具",
		items: [
			{ name: "Vercel", icon: "▲", desc: "前端托管", url: "https://vercel.com" },
			{ name: "Netlify", icon: "🕸️", desc: "静态托管", url: "https://netlify.com" },
			{ name: "GitHub", icon: "🐙", desc: "代码托管", url: "https://github.com" },
			{ name: "JSON.cn", icon: "🔧", desc: "JSON 格式化", url: "https://www.json.cn" },
			{ name: "Can I Use", icon: "✅", desc: "浏览器兼容查询", url: "https://caniuse.com" },
		],
	},
	{
		title: "📦 文件与传输",
		items: [
			{ name: "奶牛快传", icon: "🐄", desc: "大文件传输", url: "https://cowtransfer.com" },
			{ name: "文叔叔", icon: "📨", desc: "文件传输", url: "https://www.wenshushu.cn" },
			{ name: "TinyPNG", icon: "🗜️", desc: "图片压缩", url: "https://tinypng.com" },
			{ name: "格式工厂", icon: "🏭", desc: "格式转换", url: "https://www.pcfreetime.com" },
		],
	},
];
