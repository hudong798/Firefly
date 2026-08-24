export type TvType = "综合" | "动漫" | "短剧" | "网盘" | "其他";

export interface TvSite {
	name: string;
	url: string;
	type: TvType;
	rating: number; // 0-100 评分，展示为星标
}

export interface TvLink {
	name: string;
	url: string;
}

export interface TvParser {
	name: string;
	url: string;
}

export interface TvAdult {
	no: number;
	site: string;
}

// 影视网站，按类型分组展示
export const tvSites: TvSite[] = [
	{ name: "非凡资源", url: "https://ffzy5.tv", type: "综合", rating: 4 },
	{ name: "vidhub", url: "https://vidhub4.cc", type: "综合", rating: 4 },
	{ name: "毒舌 91", url: "https://duse1.com", type: "综合", rating: 4 },
	{ name: "网飞猫", url: "https://ncat1.app", type: "综合", rating: 4 },
	{ name: "可可影视", url: "https://kkys03.com", type: "综合", rating: 4 },
	{ name: "发现 TV", url: "https://faxiantv.cc", type: "综合", rating: 4 },
	{ name: "努努", url: "https://nnyy.la", type: "综合", rating: 4 },
	{ name: "ikan", url: "https://ikanbot.com", type: "综合", rating: 4 },
	{ name: "每日分享·不死鸟", url: "https://iui.su/fx/", type: "综合", rating: 4 },
	{ name: "歪比巴卜", url: "https://www.wbbb1.com/", type: "综合", rating: 4 },
	{ name: "雅图", url: "https://yatu.tv", type: "综合", rating: 3 },
	{ name: "近未來盡未來", url: "https://xon.ip-ddns.com/", type: "综合", rating: 3 },
	{ name: "可乐影视2", url: "https://www.klyingshi2.com/", type: "综合", rating: 3 },
	{ name: "233 动漫", url: "https://233dm.com", type: "动漫", rating: 4 },
	{ name: "火车太堵", url: "https://hctd1.com", type: "短剧", rating: 4 },
	{ name: "看片狂人", url: "https://kpkuang.one", type: "短剧", rating: 4 },
	{ name: "libvio", url: "https://libvio.vip", type: "网盘", rating: 4 },
	{ name: "饺子", url: "https://jiaozi.me", type: "网盘", rating: 3 },
];

// 其他推荐
export const tvOthers: TvLink[] = [
	{ name: "TBox", url: "https://tbox.fun" },
	{ name: "硬核指南", url: "https://yinghezhinan.com" },
	{ name: "小鱼", url: "https://xuanzi.ggff.net" },
	{ name: "一糖", url: "https://iitang.com" },
	{ name: "优质网站合集", url: "https://faxianx.com" },
];

// 解析接口
export const tvParsers: TvParser[] = [
	{ name: "HLS 解析", url: "https://jx.hls.one/?url=" },
	{ name: "冰点解析", url: "https://bd.jx.cn/?url=" },
	{ name: "77Flv 解析", url: "https://jx.77flv.cc/?url=" },
	{ name: "2S0 解析", url: "https://jx.2s0.cn/player/?url=" },
];

// 18+ 专区（需手动输入）
export const tvAdult: TvAdult[] = [
	{ no: 1, site: "apiyutu · com" },
	{ no: 2, site: "Naixxzy · com" },
	{ no: 3, site: "xxibaozyw · com" },
	{ no: 4, site: "ckzy · me" },
	{ no: 5, site: "shayuapi · com" },
	{ no: 6, site: "apilj · com" },
	{ no: 7, site: "woaav · lol" },
	{ no: 8, site: "jingpinx · com" },
	{ no: 9, site: "souavzy · vip" },
	{ no: 10, site: "jiejie51-tcpm480 · cc" },
	{ no: 11, site: "992kp · com" },
	{ no: 12, site: "91md · me" },
	{ no: 13, site: "h82wz1 · lwcjcukk · xyz" },
	{ no: 14, site: "yandex · com / search / touch" },
];

// 分组顺序
export const tvTypeOrder: TvType[] = ["综合", "动漫", "短剧", "网盘", "其他"];
