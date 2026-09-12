-- ============================================================
-- FreeX 数据导入 Seed
-- 旅行: 6 条
-- 档案: 57 条
-- AI工具: 62 条
-- ============================================================

DELETE FROM public.travels;
DELETE FROM public.archives;
DELETE FROM public.ai_tools;

-- ---------- 旅行数据 ----------
INSERT INTO public.travels (title, destination, country, province, city, start_date, end_date, description, cover_image, latitude, longitude, year, tags, content, gallery, sort_order, status) VALUES
  ('关西初夏行', '大阪 / 京都 / 奈良', '日本', NULL, NULL, '2024-06-12', '2024-06-20', '循着古都的檐角与巷弄，把初夏的绿意、寺庙的钟声和街角的烟火气一并收进行囊。', 'https://picsum.photos/seed/kyoto-summer/640/420', NULL, NULL, 2024, ARRAY['古都', '美食', 'City Walk'], '## 行程概览

九天里，从大阪的喧嚣一路往南，穿进京都的巷弄，再往奈良追几只不怕人的鹿。初夏的关西没有盛夏的黏腻，最适合慢慢走。

- **Day 1-3 大阪**：心斋桥的人潮、道顿堀的霓虹，还有黑门市场的现烤星鳗。
- **Day 4-7 京都**：伏见稻荷的千本鸟居、岚山的竹林、清水寺的黄昏。
- **Day 8-9 奈良**：奈良公园的鹿、东大寺的大佛，最后在若草山上看一场日落。

## 那些记住的画面

清晨六点的清水寺几乎没有游客，木质舞台悬在半空，京都被薄雾罩着，像一张没干的水彩。傍晚在鸭川边坐下，看当地人把脚泡进水里，风吹过来是凉的。

> 旅行最妙的从不是景点，而是某个你突然想停下来的瞬间。

## 吃什么

大阪的章鱼烧要趁烫，京都的抹茶冰淇淋苦得克制，奈良的柿叶寿司带着山林的味道。一路吃下来，胃比相机更诚实。', ARRAY['https://picsum.photos/seed/kyoto-torii/800/600', 'https://picsum.photos/seed/kyoto-bamboo/800/600', 'https://picsum.photos/seed/osaka-night/800/600', 'https://picsum.photos/seed/nara-deer/800/600', 'https://picsum.photos/seed/kyoto-temple/800/600', 'https://picsum.photos/seed/arashiyama/800/600'], 0, 'published'),
  ('滇西北环线', '大理 / 丽江 / 香格里拉', '中国', NULL, NULL, '2023-10-01', '2023-10-09', '苍山洱海的风、古城的石板路、海拔三千米的星空，一路向西遇见秋天的第一场雪。', 'https://picsum.photos/seed/yunnan-trip/640/420', NULL, NULL, 2023, ARRAY['自然', '自驾', '高原'], '## 一路向西

八天环线，从大理的苍山洱海起步，过丽江的古城与玉龙雪山，最后抵达香格里拉——海拔骤升，呼吸开始变慢。

- **大理**：骑行环洱海，风很大，云很低。
- **丽江**：束河比大研安静，玉龙雪山的雪线已经退得很靠上。
- **香格里拉**：普达措的秋天，是金黄的草甸和冷蓝色的湖。

## 海拔与星空

在香格里拉的第一晚有点高反，但半夜推开窗，银河就挂在松赞林寺的金顶上方。那一刻觉得，三千米的值得。

> 高原教会我的事：慢一点，再慢一点。

## 路上的味道

大理的酸辣鱼、丽江的腊排骨火锅、香格里拉的酥油茶。越往西，味道越厚重，像在替稀薄的空气补一点热量。', ARRAY['https://picsum.photos/seed/erhai-lake/800/600', 'https://picsum.photos/seed/lijiang-old/800/600', 'https://picsum.photos/seed/yulong-snow/800/600', 'https://picsum.photos/seed/shangri-la/800/600', 'https://picsum.photos/seed/pudacuo/800/600', 'https://picsum.photos/seed/yunnan-star/800/600'], 1, 'published'),
  ('海岛慢时光', '普吉 / 皮皮岛', '泰国', NULL, NULL, '2024-02-08', '2024-02-15', '把日程表丢进海里，只在意潮起潮落和日落的颜色，做一周没有闹钟的人。', 'https://picsum.photos/seed/island-time/640/420', NULL, NULL, 2024, ARRAY['海岛', '潜水', '度假'], '## 没有日程的一周

普吉的酒店阳台上能看到海，皮皮岛的水清到能数清脚下的沙子。这一周，闹钟被我关了，取而代之的是潮水的节奏。

- **普吉**：卡伦海滩的落日，是橘子味儿的。
- **皮皮岛**：跳岛游、浮潜，鱼群从手边游过。
- **皇帝岛**：人少，水静，适合发呆。

## 潜进水里

第一次浮潜，憋着气看珊瑚像森林一样在脚下展开。上岸后，整个人轻得不像话。

> 海会替你把时间这件事，暂时没收。

## 吃什么

冬阴功的酸辣、芒果糯米饭的甜、椰子水的清。岛上的饭，总是带着海风的咸。', ARRAY['https://picsum.photos/seed/phuket-beach/800/600', 'https://picsum.photos/seed/phi-phi/800/600', 'https://picsum.photos/seed/snorkel/800/600', 'https://picsum.photos/seed/sunset-island/800/600', 'https://picsum.photos/seed/coconut/800/600', 'https://picsum.photos/seed/longtail-boat/800/600'], 2, 'published'),
  ('江南烟雨录', '苏州 / 杭州', '中国', NULL, NULL, '2023-04-03', '2023-04-07', '在园林的漏窗后听雨，于西湖的断桥边发呆，把江南的温润揉进四天三夜。', 'https://picsum.photos/seed/jiangnan-rain/640/420', NULL, NULL, 2023, ARRAY['古镇', '园林', '美食'], '## 四天，两座城

清明前后，江南总在下雨。苏州的园林和杭州的湖，都在烟雨里软成了一幅水墨。

- **苏州**：拙政园的借景、留园的漏窗，雨打芭蕉最好听。
- **杭州**：西湖的断桥、苏堤的柳，租辆单车慢慢骑。

## 漏窗后的雨

坐在园林的廊下，看雨水顺着瓦当滴成线，透过漏窗，远处的亭子被框成一幅活的画。

> 江南的美，在于它不急着给你看全部。

## 吃什么

苏州的松鼠桂鱼、杭州的西湖醋鱼、街边的定胜糕。甜糯的口味，和这里的气候一样温吞。', ARRAY['https://picsum.photos/seed/suzhou-garden/800/600', 'https://picsum.photos/seed/west-lake/800/600', 'https://picsum.photos/seed/lingering-garden/800/600', 'https://picsum.photos/seed/jiangnan-rain2/800/600', 'https://picsum.photos/seed/hangzhou-willow/800/600', 'https://picsum.photos/seed/suzhou-bridge/800/600'], 3, 'published'),
  ('西南旷野自驾', '川西 / 甘孜', '中国', NULL, NULL, '2022-07-15', '2022-07-24', '翻过折多山口，草原、经幡与雪山在窗外轮番上演，自由是油门踩下去的风。', 'https://picsum.photos/seed/west-road/640/420', NULL, NULL, 2022, ARRAY['自驾', '草原', '雪山'], '## 油门与旷野

十天自驾，从成都往西，翻过折多山口，一路都是没有边界的风景。自由，是踩下油门时灌进车窗的风。

- **康定**：跑马溜溜的城，折多河在城里奔流。
- **新都桥**：摄影家的天堂，光影在草甸上画画。
- **稻城亚丁**：雪山、海子、牛奶海，走得腿软也值。

## 折多山口的风

海拔四千多的垭口，经幡被风吹得猎猎作响，远处的贡嘎雪山在云里若隐若现。那一刻，车里谁都没说话。

> 有些路，开过一次，就再也忘不掉。

## 在路上

川西的饭馆大多简陋，但牦牛肉汤锅热气腾腾。深夜的营地，星空低得伸手就能碰到。', ARRAY['https://picsum.photos/seed/xinduqiao/800/600', 'https://picsum.photos/seed/yading-snow/800/600', 'https://picsum.photos/seed/daocheng-lake/800/600', 'https://picsum.photos/seed/ganzi-prairie/800/600', 'https://picsum.photos/seed/prayer-flag/800/600', 'https://picsum.photos/seed/sichuan-road/800/600'], 4, 'published'),
  ('北欧极光夜', '特罗姆瑟', '挪威', NULL, NULL, '2023-12-20', '2023-12-28', '在北极圈内的小城里守候，直到绿色的光幕在夜空里缓缓铺开，冻僵的手指都值得。', 'https://picsum.photos/seed/nordic-aurora/640/420', NULL, NULL, 2023, ARRAY['极光', '冰雪', '追光'], '## 在北极圈等光

圣诞前后的特罗姆瑟，白天只有几小时。剩下的时间，都在等夜幕降下，等那道绿色的幕布。

- **市区**：极地教堂像冰晶，海边能看峡湾。
- **郊外露营**：裹成粽子，架好三脚架，等极光。
- **狗拉雪橇**：哈士奇带着你在雪原里飞奔。

## 光幕铺开的那一刻

等了三晚，第四晚云散了。绿色的光从天边漫上来，像有人在天上轻轻挥笔。冻僵的手指按下快门时，觉得一切都值了。

> 极光不会为谁提前预告，它只奖赏愿意等待的人。

## 冷与暖

室外零下十几度，回到小屋喝一碗热驯鹿肉汤，身体慢慢化开。极夜里的温暖，格外具体。', ARRAY['https://picsum.photos/seed/aurora-green/800/600', 'https://picsum.photos/seed/tromso-night/800/600', 'https://picsum.photos/seed/husky-sled/800/600', 'https://picsum.photos/seed/arctic-church/800/600', 'https://picsum.photos/seed/snow-mountain/800/600', 'https://picsum.photos/seed/aurora-wide/800/600'], 5, 'published');

-- ---------- 档案数据 ----------
INSERT INTO public.archives (title, description, category, cover_image, url, rating, tags, sort_order, status) VALUES
  ('非凡资源', NULL, '影视', NULL, 'https://ffzy5.tv', 4, ARRAY['综合'], 0, 'published'),
  ('vidhub', NULL, '影视', NULL, 'https://vidhub4.cc', 4, ARRAY['综合'], 1, 'published'),
  ('毒舌 91', NULL, '影视', NULL, 'https://duse1.com', 4, ARRAY['综合'], 2, 'published'),
  ('网飞猫', NULL, '影视', NULL, 'https://ncat1.app', 4, ARRAY['综合'], 3, 'published'),
  ('可可影视', NULL, '影视', NULL, 'https://kkys03.com', 4, ARRAY['综合'], 4, 'published'),
  ('发现 TV', NULL, '影视', NULL, 'https://faxiantv.cc', 4, ARRAY['综合'], 5, 'published'),
  ('努努', NULL, '影视', NULL, 'https://nnyy.la', 4, ARRAY['综合'], 6, 'published'),
  ('ikan', NULL, '影视', NULL, 'https://ikanbot.com', 4, ARRAY['综合'], 7, 'published'),
  ('每日分享·不死鸟', NULL, '影视', NULL, 'https://iui.su/fx/', 4, ARRAY['综合'], 8, 'published'),
  ('歪比巴卜', NULL, '影视', NULL, 'https://www.wbbb1.com/', 4, ARRAY['综合'], 9, 'published'),
  ('雅图', NULL, '影视', NULL, 'https://yatu.tv', 3, ARRAY['综合'], 10, 'published'),
  ('近未來盡未來. - Rui', NULL, '影视', NULL, 'https://xon.ip-ddns.com/', 3, ARRAY['综合'], 11, 'published'),
  ('影视导航', NULL, '影视', NULL, 'https://www.klyingshi2.com/', 3, ARRAY['综合'], 12, 'published'),
  ('影视森林', NULL, '影视', NULL, 'https://www.549.tv', 4, ARRAY['综合'], 13, 'published'),
  ('hqvod', NULL, '影视', NULL, 'https://www.hqvod.com', 4, ARRAY['综合'], 14, 'published'),
  ('西瓜影视', NULL, '影视', NULL, 'https://xiguazx.cc', 4, ARRAY['综合'], 15, 'published'),
  ('vv3nwjk', NULL, '影视', NULL, 'https://www.vv3nwjk.com', 4, ARRAY['综合'], 16, 'published'),
  ('233 动漫', NULL, '影视', NULL, 'https://233dm.com', 4, ARRAY['动漫'], 17, 'published'),
  ('火车太堵', NULL, '影视', NULL, 'https://hctd1.com', 4, ARRAY['短剧'], 18, 'published'),
  ('看片狂人', NULL, '影视', NULL, 'https://kpkuang.one', 4, ARRAY['短剧'], 19, 'published'),
  ('libvio', NULL, '影视', NULL, 'https://libvio.vip', 4, ARRAY['网盘'], 20, 'published'),
  ('饺子', NULL, '影视', NULL, 'https://jiaozi.me', 3, ARRAY['网盘'], 21, 'published'),
  ('动漫之家', NULL, '漫画', NULL, 'https://www.dmzj.com', NULL, ARRAY['漫画'], 22, 'published'),
  ('哔哩哔哩漫画', NULL, '漫画', NULL, 'https://manga.bilibili.com', NULL, ARRAY['漫画'], 23, 'published'),
  ('腾讯动漫', NULL, '漫画', NULL, 'https://ac.qq.com', NULL, ARRAY['漫画'], 24, 'published'),
  ('快看漫画', NULL, '漫画', NULL, 'https://www.kuaikanmanhua.com', NULL, ARRAY['条漫'], 25, 'published'),
  ('漫画堆', NULL, '漫画', NULL, 'https://www.manhuadui.com', NULL, ARRAY['漫画'], 26, 'published'),
  ('漫画DB', NULL, '漫画', NULL, 'https://www.manhuadb.com', NULL, ARRAY['漫画'], 27, 'published'),
  ('知音漫客', NULL, '漫画', NULL, 'https://www.zymk.cn', NULL, ARRAY['漫画'], 28, 'published'),
  ('小年漫画', NULL, '漫画', NULL, 'https://www.xiao-nian.com', NULL, ARRAY['条漫'], 29, 'published'),
  ('Webtoon', NULL, '漫画', NULL, 'https://www.webtoons.com', NULL, ARRAY['海外'], 30, 'published'),
  ('MangaDex', NULL, '漫画', NULL, 'https://mangadex.org', NULL, ARRAY['海外'], 31, 'published'),
  ('LINUX DO', 'linux.do', '社区', NULL, 'https://linux.do', NULL, ARRAY[]::text[], 32, 'published'),
  ('NodeSeek', 'VPS / 主机社区', '社区', NULL, 'https://www.nodeseek.com', NULL, ARRAY[]::text[], 33, 'published'),
  ('NodeLoc', 'nodeloc.com', '社区', NULL, 'https://www.nodeloc.com', NULL, ARRAY[]::text[], 34, 'published'),
  ('HelloGitHub', '有趣的开源社区', '社区', NULL, 'https://hellogithub.com', NULL, ARRAY[]::text[], 35, 'published'),
  ('IT之家', 'ithome.com', '社区', NULL, 'https://www.ithome.com', NULL, ARRAY[]::text[], 36, 'published'),
  ('Dcard社区（中国台湾）', 'dcard.tw', '社区', NULL, 'https://www.dcard.tw', NULL, ARRAY[]::text[], 37, 'published'),
  ('天涯', 'tianya.cv', '社区', NULL, 'https://tianya.cv', NULL, ARRAY[]::text[], 38, 'published'),
  ('Notion', '笔记 / 知识库', '工具', NULL, 'https://www.notion.so', NULL, ARRAY['效率工具'], 39, 'published'),
  ('语雀', '中文知识库', '工具', NULL, 'https://www.yuque.com', NULL, ARRAY['效率工具'], 40, 'published'),
  ('飞书', '文档 / 协作', '工具', NULL, 'https://www.feishu.cn', NULL, ARRAY['效率工具'], 41, 'published'),
  ('幕布', '大纲 / 思维导图', '工具', NULL, 'https://mubu.com', NULL, ARRAY['效率工具'], 42, 'published'),
  ('XMind', '思维导图', '工具', NULL, 'https://xmind.cn', NULL, ARRAY['效率工具'], 43, 'published'),
  ('Iconify', '海量图标库', '工具', NULL, 'https://icones.js.org', NULL, ARRAY['设计素材'], 44, 'published'),
  ('Coolors', '配色方案生成', '工具', NULL, 'https://coolors.co', NULL, ARRAY['设计素材'], 45, 'published'),
  ('Unsplash', '免费高清图', '工具', NULL, 'https://unsplash.com', NULL, ARRAY['设计素材'], 46, 'published'),
  ('阿里巴巴矢量图标库', '中文图标', '工具', NULL, 'https://www.iconfont.cn', NULL, ARRAY['设计素材'], 47, 'published'),
  ('Vercel', '前端托管', '工具', NULL, 'https://vercel.com', NULL, ARRAY['开发工具'], 48, 'published'),
  ('Netlify', '静态托管', '工具', NULL, 'https://netlify.com', NULL, ARRAY['开发工具'], 49, 'published'),
  ('GitHub', '代码托管', '工具', NULL, 'https://github.com', NULL, ARRAY['开发工具'], 50, 'published'),
  ('JSON.cn', 'JSON 格式化', '工具', NULL, 'https://www.json.cn', NULL, ARRAY['开发工具'], 51, 'published'),
  ('Can I Use', '浏览器兼容查询', '工具', NULL, 'https://caniuse.com', NULL, ARRAY['开发工具'], 52, 'published'),
  ('奶牛快传', '大文件传输', '工具', NULL, 'https://cowtransfer.com', NULL, ARRAY['文件与传输'], 53, 'published'),
  ('文叔叔', '文件传输', '工具', NULL, 'https://www.wenshushu.cn', NULL, ARRAY['文件与传输'], 54, 'published'),
  ('TinyPNG', '图片压缩', '工具', NULL, 'https://tinypng.com', NULL, ARRAY['文件与传输'], 55, 'published'),
  ('格式工厂', '格式转换', '工具', NULL, 'https://www.pcfreetime.com', NULL, ARRAY['文件与传输'], 56, 'published');

-- ---------- AI 工具数据 ----------
INSERT INTO public.ai_tools (name, description, logo, url, category, tags, rating, status, featured, sort_order) VALUES
  ('DeepSeek', NULL, '/assets/ai-logos/deepseek.png', 'https://chat.deepseek.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 0),
  ('Kimi', NULL, '/assets/ai-logos/kimi.png', 'https://kimi.moonshot.cn', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 1),
  ('豆包', NULL, '/assets/ai-logos/doubao.png', 'https://www.doubao.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 2),
  ('通义千问', NULL, '/assets/ai-logos/qwen.png', 'https://tongyi.aliyun.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 3),
  ('MiniMax', NULL, '/assets/ai-logos/minimax.png', 'https://www.minimaxi.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 4),
  ('Coze', NULL, '/assets/ai-logos/coze.png', 'https://www.coze.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 5),
  ('文心一言', NULL, '/assets/ai-logos/wenxin.png', 'https://yiyan.baidu.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 6),
  ('智谱清言', NULL, '/assets/ai-logos/chatglm.png', 'https://chatglm.cn', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 7),
  ('讯飞星火', NULL, '/assets/ai-logos/xfyun.png', 'https://www.xfyun.cn', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 8),
  ('百川智能', NULL, '/assets/ai-logos/baichuan.png', 'https://www.baichuan-ai.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 9),
  ('腾讯元宝', NULL, '/assets/ai-logos/yuanbao.png', 'https://yuanbao.tencent.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 10),
  ('腾讯混元', NULL, '/assets/ai-logos/hunyuan.png', 'https://hunyuan.tencent.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 11),
  ('阶跃星辰', NULL, '/assets/ai-logos/stepfun.png', 'https://www.stepfun.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 12),
  ('天工 AI', NULL, '/assets/ai-logos/tiangong.png', 'https://tiangong.cn', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 13),
  ('秘塔 AI', NULL, '/assets/ai-logos/metaso.png', 'https://metaso.cn', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 14),
  ('纳米 AI', NULL, '/assets/ai-logos/nanobot.png', 'https://nanobot.cn', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 15),
  ('商汤商量', NULL, '/assets/ai-logos/sensechat.png', 'https://sensechat.sensetime.com', '国内 AI', ARRAY[]::text[], NULL, 'published', false, 16),
  ('ChatGPT', NULL, '/assets/ai-logos/chatgpt.png', 'https://chatgpt.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 17),
  ('Claude', NULL, '/assets/ai-logos/claude.png', 'https://claude.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 18),
  ('OpenClaw', NULL, '/assets/ai-logos/openclaw.png', 'https://openclaw.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 19),
  ('AI Studio', NULL, '/assets/ai-logos/ai-studio.png', 'https://aistudio.google.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 20),
  ('Gemini', NULL, '/assets/ai-logos/gemini.png', 'https://gemini.google.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 21),
  ('Perplexity', NULL, '/assets/ai-logos/perplexity.png', 'https://www.perplexity.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 22),
  ('Mistral', NULL, '/assets/ai-logos/mistral.png', 'https://mistral.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 23),
  ('Poe', NULL, '/assets/ai-logos/poe.png', 'https://poe.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 24),
  ('Meta AI', NULL, '/assets/ai-logos/meta-ai.png', 'https://meta.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 25),
  ('Copilot', NULL, '/assets/ai-logos/copilot.png', 'https://copilot.microsoft.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 26),
  ('Grok', NULL, '/assets/ai-logos/grok.png', 'https://grok.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 27),
  ('You.com', NULL, '/assets/ai-logos/you.png', 'https://you.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 28),
  ('Pi', NULL, '/assets/ai-logos/pi.png', 'https://pi.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 29),
  ('Character.AI', NULL, '/assets/ai-logos/character-ai.png', 'https://character.ai', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 30),
  ('Phind', NULL, '/assets/ai-logos/phind.png', 'https://www.phind.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 31),
  ('Writesonic', NULL, '/assets/ai-logos/writesonic.png', 'https://writesonic.com', '国外 AI', ARRAY[]::text[], NULL, 'published', false, 32),
  ('即梦 AI', NULL, '/assets/ai-logos/jimeng.png', 'https://jimeng.jianying.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 33),
  ('Midjourney', NULL, '/assets/ai-logos/midjourney.png', 'https://www.midjourney.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 34),
  ('Stable Diffusion', NULL, '/assets/ai-logos/stability.png', 'https://stability.ai', '绘画', ARRAY[]::text[], NULL, 'published', false, 35),
  ('可灵', NULL, '/assets/ai-logos/kling.png', 'https://klingai.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 36),
  ('通义万相', NULL, '/assets/ai-logos/wanx.png', 'https://wanx.aliyun.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 37),
  ('文心一格', NULL, '/assets/ai-logos/yige.png', 'https://yige.baidu.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 38),
  ('Leonardo.AI', NULL, '/assets/ai-logos/leonardo.png', 'https://leonardo.ai', '绘画', ARRAY[]::text[], NULL, 'published', false, 39),
  ('Adobe Firefly', NULL, '/assets/ai-logos/adobe-firefly.png', 'https://www.firefly.adobe.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 40),
  ('海艺 AI', NULL, '/assets/ai-logos/seaart.png', 'https://www.seaart.ai', '绘画', ARRAY[]::text[], NULL, 'published', false, 41),
  ('Ideogram', NULL, '/assets/ai-logos/ideogram.png', 'https://ideogram.ai', '绘画', ARRAY[]::text[], NULL, 'published', false, 42),
  ('Playground', NULL, '/assets/ai-logos/playground.png', 'https://playground.ai', '绘画', ARRAY[]::text[], NULL, 'published', false, 43),
  ('NightCafe', NULL, '/assets/ai-logos/nightcafe.png', 'https://nightcafe.studio', '绘画', ARRAY[]::text[], NULL, 'published', false, 44),
  ('无界 AI', NULL, '/assets/ai-logos/wujieai.png', 'https://www.wujieai.com', '绘画', ARRAY[]::text[], NULL, 'published', false, 45),
  ('DALL·E', NULL, '/assets/ai-logos/dalle.png', 'https://openai.com/dall-e', '绘画', ARRAY[]::text[], NULL, 'published', false, 46),
  ('Ollama', NULL, '/assets/ai-logos/ollama.png', 'https://ollama.com', '模型', ARRAY[]::text[], NULL, 'published', false, 47),
  ('OpenRouter', NULL, '/assets/ai-logos/openrouter.png', 'https://openrouter.ai', '模型', ARRAY[]::text[], NULL, 'published', false, 48),
  ('Hugging Face', NULL, '/assets/ai-logos/huggingface.png', 'https://huggingface.co', '模型', ARRAY[]::text[], NULL, 'published', false, 49),
  ('Replicate', NULL, '/assets/ai-logos/replicate.png', 'https://replicate.com', '模型', ARRAY[]::text[], NULL, 'published', false, 50),
  ('Together AI', NULL, '/assets/ai-logos/together.png', 'https://www.together.ai', '模型', ARRAY[]::text[], NULL, 'published', false, 51),
  ('Groq', NULL, '/assets/ai-logos/groq.png', 'https://groq.com', '模型', ARRAY[]::text[], NULL, 'published', false, 52),
  ('硅基流动', NULL, '/assets/ai-logos/siliconflow.png', 'https://siliconflow.cn', '模型', ARRAY[]::text[], NULL, 'published', false, 53),
  ('魔搭 ModelScope', NULL, '/assets/ai-logos/modelscope.png', 'https://modelscope.cn', '模型', ARRAY[]::text[], NULL, 'published', false, 54),
  ('Fireworks', NULL, '/assets/ai-logos/fireworks.png', 'https://fireworks.ai', '模型', ARRAY[]::text[], NULL, 'published', false, 55),
  ('DeepInfra', NULL, '/assets/ai-logos/deepinfra.png', 'https://deepinfra.com', '模型', ARRAY[]::text[], NULL, 'published', false, 56),
  ('百度千帆', NULL, '/assets/ai-logos/qianfan.png', 'https://qianfan.cloud.baidu.com', '模型', ARRAY[]::text[], NULL, 'published', false, 57),
  ('阿里百炼', NULL, '/assets/ai-logos/bailian.png', 'https://bailian.console.aliyun.com', '模型', ARRAY[]::text[], NULL, 'published', false, 58),
  ('NVIDIA NIM', NULL, '/assets/ai-logos/nvidia.png', 'https://build.nvidia.com', '模型', ARRAY[]::text[], NULL, 'published', false, 59),
  ('Cerebras', NULL, '/assets/ai-logos/cerebras.png', 'https://www.cerebras.ai', '模型', ARRAY[]::text[], NULL, 'published', false, 60),
  ('Anyscale', NULL, '/assets/ai-logos/anyscale.png', 'https://www.anyscale.com', '模型', ARRAY[]::text[], NULL, 'published', false, 61);

