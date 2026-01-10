import type { FriendLink, FriendsPageConfig } from "../types/config";

// 可以在src/content/spec/friends.md中编写友链页面下方的自定义内容

// 友链页面配置
export const friendsPageConfig: FriendsPageConfig = {
	// 显示列数：2列或3列
	columns: 2,
};

// 友链配置
export const friendsConfig: FriendLink[] = [
	{
		title: "LinuxDo",
		imgurl: "https://linux.do/uploads/default/original/4X/d/1/4/d146c68151340881c884d95e0da4acdf369258c6.png",
		desc: "Linux学习与交流社区",
		siteurl: "https://linux.do",
		tags: ["Blog"],
		weight: 10, // 权重，数字越大排序越靠前
		enabled: true, // 是否启用
	},
	{
		title: "DepThink",
		imgurl: "https://docs-firefly.cuteleaf.cn/logo.png",
		desc: "一个专注于技术文档的站点",
		siteurl: "https://www.depthink.xyz",
		tags: ["Docs"],
		weight: 9,
		enabled: true,
	},

		
];

// 获取启用的友链并按权重排序
export const getEnabledFriends = (): FriendLink[] => {
	return friendsConfig
		.filter((friend) => friend.enabled)
		.sort((a, b) => b.weight - a.weight);
};
