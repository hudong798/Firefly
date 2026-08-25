// 阅读板块：每本书的阅读感悟（微信朋友圈风格时间流）

// 列表页感悟最多展示字数，超出需进入详情页
export const READING_PREVIEW_LIMIT = 200;

export interface BookNote {
	id: string;
	title: string;
	author: string;
	cover: string; // 封面 emoji
	hue: number; // 封面主色相 0-360，用于生成渐变
	date: string; // 分享日期
	tags: string[];
	feeling: string; // 感悟正文，\n 分段
	likes: number;
	comments: number;
}

// 倒序：最新阅读排在最前
export const bookNotes: BookNote[] = [
	{
		id: "living",
		title: "活着",
		author: "余华",
		cover: "📖",
		hue: 8,
		date: "2026-08-20",
		tags: ["长篇小说", "生死", "经典"],
		feeling:
			"合上《活着》，窗外正好下起雨。福贵从纨绔少爷到孤身一人，一次次送走父亲、母亲、妻子、儿女、女婿，最后只剩一头老牛作伴，却还能在田埂上唱起歌。\n我们总以为活着需要某个宏大的意义撑着，可余华写的是：活着本身就是忍耐，也是力气。苦难从不预约，它只是来了，然后又走了，留下的人继续吃饭、劳作、呼吸。\n那些以为扛不过去的夜晚，其实都过去了。书里没有控诉，没有煽情，只有一种中国农民特有的、沉默而倔强的活法。读它的时候我常常走神，想起外婆讲述的饥荒年代——他们那一代人，似乎天生就懂得「活着就行」这四个字的重量。",
		likes: 128,
		comments: 23,
	},
	{
		id: "three-body",
		title: "三体",
		author: "刘慈欣",
		cover: "🚀",
		hue: 210,
		date: "2026-08-12",
		tags: ["科幻", "硬科幻", "宇宙"],
		feeling:
			"凌晨三点读完第三部，盯着天花板发了很久的呆。\n「弱小和无知不是生存的障碍，傲慢才是。」当文明在宇宙尺度下渺小如尘，我们争吵的、焦虑的，忽然都轻了。\n推荐给每一个偶尔会仰望星空的人。",
		likes: 96,
		comments: 17,
	},
	{
		id: "shitiesheng",
		title: "史铁生散文集",
		author: "史铁生",
		cover: "🍂",
		hue: 32,
		date: "2026-07-30",
		tags: ["散文", "哲思", "命运"],
		feeling:
			"史铁生写地坛，写轮椅，写看不见的光。\n他说「死是一件不必急于求成的事」，那一刻我好像也被允许慢慢来。\n身体的囚笼关不住思想的辽阔——这本书适合在安静的午后，一字一句地读。",
		likes: 74,
		comments: 9,
	},
	{
		id: "little-prince",
		title: "小王子",
		author: "圣埃克苏佩里",
		cover: "🌹",
		hue: 340,
		date: "2026-07-18",
		tags: ["童话", "纯真", "治愈"],
		feeling:
			"长大后才敢读《小王子》。\n「所有大人都曾经是小孩，虽然，只有少数的人记得。」我们忙着数星星的价值，却忘了抬头看它们眨眼。\n今天给自己买一束玫瑰，不为谁，就为那句「你为你的玫瑰花费的时间，使你的玫瑰变得重要」。",
		likes: 153,
		comments: 31,
	},
	{
		id: "sapiens",
		title: "人类简史",
		author: "尤瓦尔·赫拉利",
		cover: "🌍",
		hue: 150,
		date: "2026-06-29",
		tags: ["历史", "人类学", "认知"],
		feeling:
			"《人类简史》颠覆了我很多「理所当然」。\n钱、国家、公司，本质都是人类共同相信的故事。我们靠虚构的能力建立了文明，也可能被自己编的剧本困住。\n读完最大的收获：保持怀疑，也保持想象。",
		likes: 88,
		comments: 14,
	},
];
