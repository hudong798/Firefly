<script lang="ts">
	// 井字棋：玩家(X) vs 电脑(O)，先手必胜/平局，纯娱乐
	let board: (0 | 1 | 2)[] = Array(9).fill(0);
	let turn: 1 | 2 = 1; // 1 玩家, 2 电脑
	let gameOver = false;
	let winner = "";
	let thinking = false;

	const lines = [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],
		[0, 3, 6],
		[1, 4, 7],
		[2, 5, 8],
		[0, 4, 8],
		[2, 4, 6],
	];

	function checkWin(p: 1 | 2): boolean {
		return lines.some(([a, b, c]) => board[a] === p && board[b] === p && board[c] === p);
	}

	function findWin(p: 1 | 2): number | null {
		for (let i = 0; i < 9; i++) {
			if (board[i] !== 0) continue;
			board[i] = p;
			const w = checkWin(p);
			board[i] = 0;
			if (w) return i;
		}
		return null;
	}

	function place(i: number, p: 1 | 2) {
		if (board[i] !== 0 || gameOver) return;
		board = board.map((v, idx) => (idx === i ? p : v));
		if (checkWin(p)) {
			gameOver = true;
			winner = p === 1 ? "🎉 你赢了！" : "😅 电脑赢了，再来一局？";
			return;
		}
		if (board.every((v) => v !== 0)) {
			gameOver = true;
			winner = "🤝 平局";
		}
	}

	function handleCell(i: number) {
		if (gameOver || turn !== 1 || thinking) return;
		place(i, 1);
		if (!gameOver) {
			turn = 2;
			thinking = true;
			setTimeout(() => {
				// 先尝试获胜，再堵玩家，否则选边角/中心/随机
				let mv = findWin(2);
				if (mv === null) mv = findWin(1);
				if (mv === null) {
					const empties = board.map((v, i) => (v === 0 ? i : -1)).filter((i) => i >= 0);
					const pref = [4, 0, 2, 6, 8, 1, 3, 5, 7].filter((i) => empties.includes(i));
					mv = pref[0] ?? empties[Math.floor(Math.random() * empties.length)];
				}
				if (mv !== null && !gameOver) place(mv, 2);
				thinking = false;
				turn = 1;
			}, 250);
		}
	}

	function reset() {
		board = Array(9).fill(0);
		turn = 1;
		gameOver = false;
		winner = "";
		thinking = false;
	}
</script>

<div class="tictactoe">
	<div class="tictactoe-head">
		<span class="tictactoe-status">
			{winner || (turn === 1 ? "轮到你：X" : "电脑思考中… O")}
		</span>
		<button class="tictactoe-reset" on:click={reset}>重新开始</button>
	</div>
	<div class="tictactoe-board">
		{#each board as cell, i}
			<button
				class="tictactoe-cell"
				class:x={cell === 1}
				class:o={cell === 2}
				on:click={() => handleCell(i)}
				aria-label={`格${i + 1}`}
			>
				{cell === 1 ? "X" : cell === 2 ? "O" : ""}
			</button>
		{/each}
	</div>
</div>

<style>
	.tictactoe {
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
		align-items: center;
	}
	.tictactoe-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		gap: 0.5rem;
	}
	.tictactoe-status {
		font-size: 0.85rem;
		font-weight: 600;
	}
	.tictactoe-reset {
		font-size: 0.78rem;
		padding: 0.3rem 0.8rem;
		border-radius: 0.5rem;
		border: 1px solid var(--wb-border);
		background: var(--glass-surface-soft, var(--wb-hover));
		color: inherit;
		cursor: pointer;
	}
	.tictactoe-reset:hover {
		color: var(--primary);
		border-color: color-mix(in oklch, var(--primary) 50%, var(--wb-border));
	}
	.tictactoe-board {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.4rem;
		width: min(100%, 15rem);
		aspect-ratio: 1;
	}
	.tictactoe-cell {
		font-size: 2.2rem;
		font-weight: 700;
		border-radius: 0.6rem;
		border: 1px solid var(--wb-border);
		background: var(--glass-surface-soft, var(--wb-hover));
		color: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.12s ease, border-color 0.12s ease;
	}
	.tictactoe-cell.x {
		color: var(--primary);
	}
	.tictactoe-cell.o {
		color: oklch(0.6 0.12 25);
	}
	.tictactoe-cell:hover {
		transform: scale(1.04);
		border-color: color-mix(in oklch, var(--primary) 50%, var(--wb-border));
	}
</style>
