// 漫画资源板块：漫画 / 条漫 / 海外 等在线看漫站点
export interface ComicSite {
	name: string;
	url: string;
	type: "漫画" | "条漫" | "海外";
}

// 倒序无严格意义，按综合热度大致靠前
export const comics: ComicSite[] = [
	{ name: "动漫之家", url: "https://www.dmzj.com", type: "漫画" },
	{ name: "哔哩哔哩漫画", url: "https://manga.bilibili.com", type: "漫画" },
	{ name: "腾讯动漫", url: "https://ac.qq.com", type: "漫画" },
	{ name: "快看漫画", url: "https://www.kuaikanmanhua.com", type: "条漫" },
	{ name: "漫画堆", url: "https://www.manhuadui.com", type: "漫画" },
	{ name: "漫画DB", url: "https://www.manhuadb.com", type: "漫画" },
	{ name: "知音漫客", url: "https://www.zymk.cn", type: "漫画" },
	{ name: "小年漫画", url: "https://www.xiao-nian.com", type: "条漫" },
	{ name: "Webtoon", url: "https://www.webtoons.com", type: "海外" },
	{ name: "MangaDex", url: "https://mangadex.org", type: "海外" },
];

export const comicTypeClass: Record<ComicSite["type"], string> = {
	漫画: "manga",
	条漫: "strip",
	海外: "overseas",
};
