import type { NavBarConfig, NavBarLink } from "../types/config";
import { LinkPreset } from "../types/config";
import { siteConfig } from "./siteConfig";

// 根据页面开关动态生成导航栏配置
const getDynamicNavBarConfig = (): NavBarConfig => {
  const links: (NavBarLink | LinkPreset)[] = [
    LinkPreset.Home,
    LinkPreset.Archive,
  ];

  // 根据配置决定是否添加追番页面
  if (siteConfig.pages.anime) {
    links.push(LinkPreset.Anime);
  }

  // 支持自定义导航栏链接,并且支持多级菜单
  links.push({
    name: "链接",
    url: "/links/",
    icon: "material-symbols:link",
    children: [
      {
        name: "linuxdo",
        url: "https://linux.do",
        external: true,
        icon: "fa6-solid:link",
      },
      {
        name: "moontv",
        url: "https://moon.52798.xyz",
        external: true,
        icon: "fa6-solid:video",
      },
       {
        name: "music",
        url: "https://music.52798.xyz",
        external: true,
        icon: "fa6-solid:music",
      },
      {
        name: "童锦程写真",
        url: "https://www.52798.xyz/article/xiezhen",
        external: true,
        icon: "fa6-solid:image",
      },
       {
        name: "Builtful-girl",
        url: "https://mv.1008008.xyz/",
        external: true,
        icon: "fa6-solid:video",
      },
      {
        name: "douyin",
        url: "https://www.douyin.com/user/MS4wLjABAAAA4UZncV9bemBJ9WFytjwrFTl75yfRuOn_I-qKdcke1I0E-3NEET5WFSiDDSIGlRUU?from_tab_name=main",
        external: true,
        icon: "fa6-brands:tiktok",
      },
    ],
  });

  links.push(LinkPreset.Friends);

  links.push({
    name: "关于",
    url: "/content/",
    icon: "material-symbols:info",
    children: [
      ...(siteConfig.pages.sponsor ? [LinkPreset.Sponsor] : []), // 根据配置决定是否添加赞助页面
      LinkPreset.About,
    ],
  });
  return { links };
};

export const navBarConfig: NavBarConfig = getDynamicNavBarConfig();
