// 想法动态数据源：像 QQ 动态一样，一条一条记录当下想法
// 想发新动态？在数组最前面加一条即可：
// {
//   date: "2026-08-24 12:30",
//   content: "今天的想法……",
//   mood: "😊",            // 可选：心情 emoji
//   tags: ["日常"],        // 可选：小标签
// },
export interface ThoughtMoment {
	date: string;
	content: string;
	mood?: string;
	tags?: string[];
}

export const moments: ThoughtMoment[] = [
	{
		date: "2026-08-24 00:30",
		content:
			"给网站做了一版大改造：想法页改成了 QQ 动态一样的形式，各个板块也都有了明确的定位。折腾到半夜，但看到效果觉得值了 ✨",
		mood: "😆",
		tags: ["建站", "日常"],
	},
	{
		date: "2026-08-23 22:10",
		content: "影视板块又收录了几个新站点，再也不怕剧荒了。",
		mood: "🎬",
		tags: ["资源"],
	},
	{
		date: "2026-08-20 21:05",
		content:
			"决定把这里当成自己的小树洞，想到什么就写什么，不用长篇大论，随手的记录才有生活气息。",
		mood: "🌱",
		tags: ["随笔"],
	},
];
