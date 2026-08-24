// 游戏板块：在线游戏链接数据源（与 games.astro 共用）
export interface GameItem {
	name: string;
	icon: string;
	desc: string;
	url: string;
}

export const onlineGames: GameItem[] = [
	{ name: "中国象棋", icon: "♟️", desc: "人机对战", url: "https://www.xiangqi.com" },
	{ name: "国际象棋", icon: "👑", desc: "在线对弈", url: "https://www.chess.com/play/online" },
	{ name: "2048", icon: "🔢", desc: "经典数字合并", url: "https://play2048.co" },
	{ name: "扫雷", icon: "💣", desc: "经典逻辑游戏", url: "https://minesweeper.online" },
	{ name: "数独", icon: "🧩", desc: "数字推理", url: "https://www.sudoku.com" },
	{ name: "俄罗斯方块", icon: "🟦", desc: "经典下落方块", url: "https://tetris.com/play-tetris" },
];

// 站内可玩的小游戏（非外部链接，指向游戏页）
export const builtinGames: GameItem[] = [
	{ name: "五子棋", icon: "⚫", desc: "站内人机对战", url: "/games/" },
	{ name: "井字棋", icon: "⭕", desc: "站内人机对战", url: "/games/" },
];
