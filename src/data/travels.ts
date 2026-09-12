// 旅游板块：一个个旅行卡片的数据源
// cover 为封面图 URL（可换成自己的照片）；date 为旅游时间；location 为地点
// slug 为详情页路径（/travel/<slug>/）；content 为 markdown 正文；gallery 为沿途风景照片
export interface TravelEntry {
	slug: string;
	title: string;
	cover: string;
	date: string;
	location: string;
	summary: string;
	tags?: string[];
	content?: string;
	gallery?: string[];
}

export const travels: TravelEntry[] = [
	{
		slug: "kansai-early-summer",
		title: "关西初夏行",
		cover: "https://picsum.photos/seed/kyoto-summer/640/420",
		date: "2024.06.12 - 06.20",
		location: "日本 · 大阪 / 京都 / 奈良",
		summary: "循着古都的檐角与巷弄，把初夏的绿意、寺庙的钟声和街角的烟火气一并收进行囊。",
		tags: ["古都", "美食", "City Walk"],
		content: `## 行程概览

九天里，从大阪的喧嚣一路往南，穿进京都的巷弄，再往奈良追几只不怕人的鹿。初夏的关西没有盛夏的黏腻，最适合慢慢走。

- **Day 1-3 大阪**：心斋桥的人潮、道顿堀的霓虹，还有黑门市场的现烤星鳗。
- **Day 4-7 京都**：伏见稻荷的千本鸟居、岚山的竹林、清水寺的黄昏。
- **Day 8-9 奈良**：奈良公园的鹿、东大寺的大佛，最后在若草山上看一场日落。

## 那些记住的画面

清晨六点的清水寺几乎没有游客，木质舞台悬在半空，京都被薄雾罩着，像一张没干的水彩。傍晚在鸭川边坐下，看当地人把脚泡进水里，风吹过来是凉的。

> 旅行最妙的从不是景点，而是某个你突然想停下来的瞬间。

## 吃什么

大阪的章鱼烧要趁烫，京都的抹茶冰淇淋苦得克制，奈良的柿叶寿司带着山林的味道。一路吃下来，胃比相机更诚实。`,
		gallery: [
			"https://picsum.photos/seed/kyoto-torii/800/600",
			"https://picsum.photos/seed/kyoto-bamboo/800/600",
			"https://picsum.photos/seed/osaka-night/800/600",
			"https://picsum.photos/seed/nara-deer/800/600",
			"https://picsum.photos/seed/kyoto-temple/800/600",
			"https://picsum.photos/seed/arashiyama/800/600",
		],
	},
	{
		slug: "northern-yunnan-loop",
		title: "滇西北环线",
		cover: "https://picsum.photos/seed/yunnan-trip/640/420",
		date: "2023.10.01 - 10.09",
		location: "中国 · 大理 / 丽江 / 香格里拉",
		summary: "苍山洱海的风、古城的石板路、海拔三千米的星空，一路向西遇见秋天的第一场雪。",
		tags: ["自然", "自驾", "高原"],
		content: `## 一路向西

八天环线，从大理的苍山洱海起步，过丽江的古城与玉龙雪山，最后抵达香格里拉——海拔骤升，呼吸开始变慢。

- **大理**：骑行环洱海，风很大，云很低。
- **丽江**：束河比大研安静，玉龙雪山的雪线已经退得很靠上。
- **香格里拉**：普达措的秋天，是金黄的草甸和冷蓝色的湖。

## 海拔与星空

在香格里拉的第一晚有点高反，但半夜推开窗，银河就挂在松赞林寺的金顶上方。那一刻觉得，三千米的值得。

> 高原教会我的事：慢一点，再慢一点。

## 路上的味道

大理的酸辣鱼、丽江的腊排骨火锅、香格里拉的酥油茶。越往西，味道越厚重，像在替稀薄的空气补一点热量。`,
		gallery: [
			"https://picsum.photos/seed/erhai-lake/800/600",
			"https://picsum.photos/seed/lijiang-old/800/600",
			"https://picsum.photos/seed/yulong-snow/800/600",
			"https://picsum.photos/seed/shangri-la/800/600",
			"https://picsum.photos/seed/pudacuo/800/600",
			"https://picsum.photos/seed/yunnan-star/800/600",
		],
	},
	{
		slug: "island-slow-time",
		title: "海岛慢时光",
		cover: "https://picsum.photos/seed/island-time/640/420",
		date: "2024.02.08 - 02.15",
		location: "泰国 · 普吉 / 皮皮岛",
		summary: "把日程表丢进海里，只在意潮起潮落和日落的颜色，做一周没有闹钟的人。",
		tags: ["海岛", "潜水", "度假"],
		content: `## 没有日程的一周

普吉的酒店阳台上能看到海，皮皮岛的水清到能数清脚下的沙子。这一周，闹钟被我关了，取而代之的是潮水的节奏。

- **普吉**：卡伦海滩的落日，是橘子味儿的。
- **皮皮岛**：跳岛游、浮潜，鱼群从手边游过。
- **皇帝岛**：人少，水静，适合发呆。

## 潜进水里

第一次浮潜，憋着气看珊瑚像森林一样在脚下展开。上岸后，整个人轻得不像话。

> 海会替你把时间这件事，暂时没收。

## 吃什么

冬阴功的酸辣、芒果糯米饭的甜、椰子水的清。岛上的饭，总是带着海风的咸。`,
		gallery: [
			"https://picsum.photos/seed/phuket-beach/800/600",
			"https://picsum.photos/seed/phi-phi/800/600",
			"https://picsum.photos/seed/snorkel/800/600",
			"https://picsum.photos/seed/sunset-island/800/600",
			"https://picsum.photos/seed/coconut/800/600",
			"https://picsum.photos/seed/longtail-boat/800/600",
		],
	},
	{
		slug: "jiangnan-rain",
		title: "江南烟雨录",
		cover: "https://picsum.photos/seed/jiangnan-rain/640/420",
		date: "2023.04.03 - 04.07",
		location: "中国 · 苏州 / 杭州",
		summary: "在园林的漏窗后听雨，于西湖的断桥边发呆，把江南的温润揉进四天三夜。",
		tags: ["古镇", "园林", "美食"],
		content: `## 四天，两座城

清明前后，江南总在下雨。苏州的园林和杭州的湖，都在烟雨里软成了一幅水墨。

- **苏州**：拙政园的借景、留园的漏窗，雨打芭蕉最好听。
- **杭州**：西湖的断桥、苏堤的柳，租辆单车慢慢骑。

## 漏窗后的雨

坐在园林的廊下，看雨水顺着瓦当滴成线，透过漏窗，远处的亭子被框成一幅活的画。

> 江南的美，在于它不急着给你看全部。

## 吃什么

苏州的松鼠桂鱼、杭州的西湖醋鱼、街边的定胜糕。甜糯的口味，和这里的气候一样温吞。`,
		gallery: [
			"https://picsum.photos/seed/suzhou-garden/800/600",
			"https://picsum.photos/seed/west-lake/800/600",
			"https://picsum.photos/seed/lingering-garden/800/600",
			"https://picsum.photos/seed/jiangnan-rain2/800/600",
			"https://picsum.photos/seed/hangzhou-willow/800/600",
			"https://picsum.photos/seed/suzhou-bridge/800/600",
		],
	},
	{
		slug: "west-sichuan-road",
		title: "西南旷野自驾",
		cover: "https://picsum.photos/seed/west-road/640/420",
		date: "2022.07.15 - 07.24",
		location: "中国 · 川西 / 甘孜",
		summary: "翻过折多山口，草原、经幡与雪山在窗外轮番上演，自由是油门踩下去的风。",
		tags: ["自驾", "草原", "雪山"],
		content: `## 油门与旷野

十天自驾，从成都往西，翻过折多山口，一路都是没有边界的风景。自由，是踩下油门时灌进车窗的风。

- **康定**：跑马溜溜的城，折多河在城里奔流。
- **新都桥**：摄影家的天堂，光影在草甸上画画。
- **稻城亚丁**：雪山、海子、牛奶海，走得腿软也值。

## 折多山口的风

海拔四千多的垭口，经幡被风吹得猎猎作响，远处的贡嘎雪山在云里若隐若现。那一刻，车里谁都没说话。

> 有些路，开过一次，就再也忘不掉。

## 在路上

川西的饭馆大多简陋，但牦牛肉汤锅热气腾腾。深夜的营地，星空低得伸手就能碰到。`,
		gallery: [
			"https://picsum.photos/seed/xinduqiao/800/600",
			"https://picsum.photos/seed/yading-snow/800/600",
			"https://picsum.photos/seed/daocheng-lake/800/600",
			"https://picsum.photos/seed/ganzi-prairie/800/600",
			"https://picsum.photos/seed/prayer-flag/800/600",
			"https://picsum.photos/seed/sichuan-road/800/600",
		],
	},
	{
		slug: "nordic-aurora-night",
		title: "北欧极光夜",
		cover: "https://picsum.photos/seed/nordic-aurora/640/420",
		date: "2023.12.20 - 12.28",
		location: "挪威 · 特罗姆瑟",
		summary: "在北极圈内的小城里守候，直到绿色的光幕在夜空里缓缓铺开，冻僵的手指都值得。",
		tags: ["极光", "冰雪", "追光"],
		content: `## 在北极圈等光

圣诞前后的特罗姆瑟，白天只有几小时。剩下的时间，都在等夜幕降下，等那道绿色的幕布。

- **市区**：极地教堂像冰晶，海边能看峡湾。
- **郊外露营**：裹成粽子，架好三脚架，等极光。
- **狗拉雪橇**：哈士奇带着你在雪原里飞奔。

## 光幕铺开的那一刻

等了三晚，第四晚云散了。绿色的光从天边漫上来，像有人在天上轻轻挥笔。冻僵的手指按下快门时，觉得一切都值了。

> 极光不会为谁提前预告，它只奖赏愿意等待的人。

## 冷与暖

室外零下十几度，回到小屋喝一碗热驯鹿肉汤，身体慢慢化开。极夜里的温暖，格外具体。`,
		gallery: [
			"https://picsum.photos/seed/aurora-green/800/600",
			"https://picsum.photos/seed/tromso-night/800/600",
			"https://picsum.photos/seed/husky-sled/800/600",
			"https://picsum.photos/seed/arctic-church/800/600",
			"https://picsum.photos/seed/snow-mountain/800/600",
			"https://picsum.photos/seed/aurora-wide/800/600",
		],
	},
];
