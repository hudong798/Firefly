export interface Community {
	name: string;
	url: string;
	icon: string;
	desc: string;
}

// 社区板块：常用/有趣的社区站点（名称来自用户截图）
export const communities: Community[] = [
	{ name: "LINUX DO", url: "https://linux.do", icon: "🐧", desc: "linux.do" },
	{ name: "NodeSeek", url: "https://www.nodeseek.com", icon: "🖥️", desc: "VPS / 主机社区" },
	{ name: "NodeLoc", url: "https://www.nodeloc.com", icon: "🌐", desc: "nodeloc.com" },
	{ name: "HelloGitHub", url: "https://hellogithub.com", icon: "🐙", desc: "有趣的开源社区" },
	{ name: "IT之家", url: "https://www.ithome.com", icon: "📱", desc: "ithome.com" },
	{ name: "Dcard社区（中国台湾）", url: "https://www.dcard.tw", icon: "💬", desc: "dcard.tw" },
	{ name: "天涯", url: "https://tianya.cv", icon: "🌊", desc: "tianya.cv" },
];
