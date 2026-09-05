// 旅行坐标数据：城市经纬度 + 关联文章
export interface TravelPoint {
	id: string;
	name: string;        // 城市/景点名
	lat: number;         // 纬度
	lng: number;         // 经度
	province: string;    // 省份/地区
	country: string;     // 国家
	articleSlug?: string; // 关联文章
	articleTitle?: string;
	date?: string;
	cover?: string;
	summary?: string;
	tags?: string[];
	isDomestic: boolean;
}

export const travelPoints: TravelPoint[] = [
	// 滇西北环线
	{
		id: "dali", name: "大理", lat: 25.6, lng: 100.2, province: "云南", country: "中国",
		articleSlug: "northern-yunnan-loop", articleTitle: "滇西北环线",
		date: "2023.10", cover: "https://picsum.photos/seed/erhai-lake/400/240",
		summary: "苍山洱海的风、古城的石板路，骑行环洱海，风很大云很低。",
		tags: ["自然", "自驾", "高原"], isDomestic: true,
	},
	{
		id: "lijiang", name: "丽江", lat: 26.87, lng: 100.23, province: "云南", country: "中国",
		articleSlug: "northern-yunnan-loop", articleTitle: "滇西北环线",
		date: "2023.10", isDomestic: true,
	},
	{
		id: "shangri-la", name: "香格里拉", lat: 27.83, lng: 99.71, province: "云南", country: "中国",
		articleSlug: "northern-yunnan-loop", articleTitle: "滇西北环线",
		date: "2023.10", isDomestic: true,
	},
	// 江南烟雨录
	{
		id: "suzhou", name: "苏州", lat: 31.3, lng: 120.6, province: "江苏", country: "中国",
		articleSlug: "jiangnan-rain", articleTitle: "江南烟雨录",
		date: "2023.04", cover: "https://picsum.photos/seed/suzhou-garden/400/240",
		summary: "拙政园的借景、留园的漏窗，雨打芭蕉最好听。",
		tags: ["古镇", "园林", "美食"], isDomestic: true,
	},
	{
		id: "hangzhou", name: "杭州", lat: 30.27, lng: 120.15, province: "浙江", country: "中国",
		articleSlug: "jiangnan-rain", articleTitle: "江南烟雨录",
		date: "2023.04", isDomestic: true,
	},
	// 西南旷野自驾
	{
		id: "chengdu", name: "成都", lat: 30.57, lng: 104.07, province: "四川", country: "中国",
		articleSlug: "west-sichuan-road", articleTitle: "西南旷野自驾",
		date: "2022.07", cover: "https://picsum.photos/seed/sichuan-road/400/240",
		summary: "翻过折多山口，草原、经幡与雪山在窗外轮番上演。",
		tags: ["自驾", "草原", "雪山"], isDomestic: true,
	},
	{
		id: "kangding", name: "康定", lat: 30.05, lng: 101.96, province: "四川", country: "中国",
		articleSlug: "west-sichuan-road", articleTitle: "西南旷野自驾",
		date: "2022.07", isDomestic: true,
	},
	{
		id: "daocheng", name: "稻城", lat: 29.04, lng: 100.3, province: "四川", country: "中国",
		articleSlug: "west-sichuan-road", articleTitle: "西南旷野自驾",
		date: "2022.07", isDomestic: true,
	},
	// 关西初夏行（国外，显示在地图边缘）
	{
		id: "osaka", name: "大阪", lat: 34.69, lng: 135.5, province: "关西", country: "日本",
		articleSlug: "kansai-early-summer", articleTitle: "关西初夏行",
		date: "2024.06", cover: "https://picsum.photos/seed/osaka-night/400/240",
		summary: "循着古都的檐角与巷弄，把初夏的绿意收进行囊。",
		tags: ["古都", "美食", "City Walk"], isDomestic: false,
	},
	{
		id: "kyoto", name: "京都", lat: 35.01, lng: 135.77, province: "关西", country: "日本",
		articleSlug: "kansai-early-summer", articleTitle: "关西初夏行",
		date: "2024.06", isDomestic: false,
	},
	// 海岛慢时光（国外）
	{
		id: "phuket", name: "普吉", lat: 8.12, lng: 98.31, province: "普吉", country: "泰国",
		articleSlug: "island-slow-time", articleTitle: "海岛慢时光",
		date: "2024.02", cover: "https://picsum.photos/seed/phuket-beach/400/240",
		summary: "把日程表丢进海里，只在意潮起潮落和日落的颜色。",
		tags: ["海岛", "潜水", "度假"], isDomestic: false,
	},
	// 北欧极光夜（国外）
	{
		id: "tromso", name: "特罗姆瑟", lat: 69.65, lng: 18.96, province: "特罗姆瑟", country: "挪威",
		articleSlug: "nordic-aurora-night", articleTitle: "北欧极光夜",
		date: "2023.12", cover: "https://picsum.photos/seed/aurora-green/400/240",
		summary: "在北极圈内守候，直到绿色的光幕在夜空里缓缓铺开。",
		tags: ["极光", "冰雪", "追光"], isDomestic: false,
	},
];

// 统计
export const travelStats = {
	journeys: 6,
	cities: travelPoints.length,
	domesticCities: travelPoints.filter(p => p.isDomestic).length,
	countries: new Set(travelPoints.map(p => p.country)).size,
	provinces: new Set(travelPoints.filter(p => p.isDomestic).map(p => p.province)).size,
	yearRange: "2022 — 2024",
};

// 所有出现过的年份（降序）
export const travelYears = Array.from(
	new Set(travelPoints.map(p => p.date?.split(".")[0]).filter(Boolean) as string[])
).sort().reverse();

// 按年份动态计算统计（年份筛选联动用）
export function statsForYear(year: string) {
	const list = year === "all"
		? travelPoints
		: travelPoints.filter(p => p.date?.startsWith(year));
	const domestic = list.filter(p => p.isDomestic);
	return {
		cities: list.length,
		domesticCities: domestic.length,
		provinces: new Set(domestic.map(p => p.province)).size,
		journeys: new Set(list.map(p => p.articleSlug).filter(Boolean)).size,
	};
}
