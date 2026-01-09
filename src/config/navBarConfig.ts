import {
	LinkPreset,
	type NavBarConfig,
	type NavBarLink,
	type NavBarSearchConfig,
	NavBarSearchMethod,
} from "../types/config";
import { siteConfig } from "./siteConfig";

// 根据页面开关动态生成导航栏配置
const getDynamicNavBarConfig = (): NavBarConfig => {
	// 基础导航栏链接
	const links: (NavBarLink | LinkPreset)[] = [
		// 主页
		LinkPreset.Home,

		// 归档
		LinkPreset.Archive,
	];

	// 自定义导航栏链接,并且支持多级菜单
	links.push({
		name: "链接",
		url: "/links/",
		icon: "material-symbols:link",

		// 子菜单
		children: [
			{
				name: "Moontv影视",
				url: "https://moon.52798.xyz",
				external: true,
				icon: "fa6-solid:video",
			},
			{
				name: "微信读书",
				url: "https://weread.qq.com",
				external: true,
				icon: "fa6-solid:link",
			},
			{
				name: "在线音乐",
				url: "https://music.52798.xyz",
				external: true,
				icon: "fa6-solid:music",
			},
			{
				name: "短视频小姐姐",
				url: "https://mv.1008008.xyz/",
				external: true,
				icon: "fa6-solid:video",
			},
			{
				name: "作者抖音",
				url: "https://www.douyin.com/user/MS4wLjABAAAAIvbqK_ALcr_o26t6LNsSMV8S1RIpGHRyFON_VchPPxk?from_tab_name=main",
				external: true,
				icon: "fa6-brands:tiktok",
			},
		],
	});

	// 友链
	links.push(LinkPreset.Friends);

	// 根据配置决定是否添加留言板，在siteConfig关闭pages.guestbook时导航栏不显示留言板
	if (siteConfig.pages.guestbook) {
		links.push(LinkPreset.Guestbook);
	}

	// 关于及其子菜单
	links.push({
		name: "关于",
		url: "/content/",
		icon: "material-symbols:info",
		children: [
			// 根据配置决定是否添加赞助，在siteConfig关闭pages.sponsor时导航栏不显示赞助
			...(siteConfig.pages.sponsor ? [LinkPreset.Sponsor] : []),

			// 关于页面
			LinkPreset.About,

			// 根据配置决定是否添加番组计划，在siteConfig关闭pages.bangumi时导航栏不显示番组计划
			...(siteConfig.pages.bangumi ? [LinkPreset.Bangumi] : []),
		],
	});

	// 仅返回链接，其它导航搜索相关配置在模块顶层常量中独立导出
	return { links } as NavBarConfig;
};

// 导航搜索配置
export const navBarSearchConfig: NavBarSearchConfig = {
	method: NavBarSearchMethod.PageFind,
};

export const navBarConfig: NavBarConfig = getDynamicNavBarConfig();
