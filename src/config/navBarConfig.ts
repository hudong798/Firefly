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
        name: "LinuxDo",
        url: "https://linux.do",
        external: true,
        icon: "fa6-solid:link",
      },
        {
        name: "DepThink",
        url: "https://www.depthink.xyz",
        external: true,
        icon: "fa6-solid:link",
      },
      {
        name: "Moontv影视",
        url: "https://moon.52798.xyz",
        external: true,
        icon: "fa6-solid:video",
      },
        {
        name: "努努影视",
        url: "https://nnyy.la/",
        external: true,
        icon: "fa6-solid:video",
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

  // links.push(LinkPreset.Friends);

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
