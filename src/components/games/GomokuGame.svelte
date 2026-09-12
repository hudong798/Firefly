<script lang="ts">
	// 五子棋：玩家(●黑) vs 电脑(○白)，15×15，电脑先堵再攻
	const N = 15;
	let board: (0 | 1 | 2)[][] = Array.from({ length: N }, () => Array(N).fill(0));
	let turn: 1 | 2 = 1; // 1 玩家, 2 电脑
	let gameOver = false;
	let winner = "";
	let moveCount = 0;
	let thinking = false;

	function checkWin(r: number, c: number, p: 1 | 2): boolean {
		const dirs = [
			[0, 1],
			[1, 0],
			[1, 1],
			[1, -1],
		];
		for (const [dr, dc] of dirs) {
			let count = 1;
			for (let s = 1; s < 5; s++) {
				const nr = r + dr * s,
					nc = c + dc * s;
				if (nr < 0 || nr >= N || nc < 0 || nc >= N || board[nr][nc] !== p) break;
				count++;
			}
			for (let s = 1; s < 5; s++) {
				const nr = r - dr * s,
					nc = c - dc * s;
				if (nr < 0 || nr >= N || nc < 0 || nc >= N || board[nr][nc] !== p) break;
				count++;
			}
			if (count >= 5) return true;
		}
		return false;
	}

	function findWin(p: 1 | 2): [number, number] | null {
		for (let r = 0; r < N; r++)
			for (let c = 0; c < N; c++) {
				if (board[r][c] !== 0) continue;
				board[r][c] = p;
				const w = checkWin(r, c, p);
				board[r][c] = 0;
				if (w) return [r, c];
			}
		return null;
	}

	function place(r: number, c: number, p: 1 | 2) {
		if (board[r][c] !== 0 || gameOver) return;
		board = board.map((row, ri) => (ri === r ? row.map((v, ci) => (ci === c ? p : v)) : row));
		moveCount++;
		if (checkWin(r, c, p)) {
			gameOver = true;
			winner = p === 1 ? "🎉 你赢了！" : "😅 电脑赢了，再来一局？";
			return;
		}
		if (moveCount === N * N) {
			gameOver = true;
			winner = "🤝 平局";
		}
	}

	function handleCell(r: number, c: number) {
		if (gameOver || turn !== 1 || thinking) return;
		place(r, c, 1);
		if (!gameOver) {
			turn = 2;
			thinking = true;
			setTimeout(() => {
				const mv = findWin(2) || findWin(1);
				if (mv) place(mv[0], mv[1], 2);
				else {
					const empties: [number, number][] = [];
					for (let r = 0; r < N; r++)
						for (let c = 0; c < N; c++) if (board[r][c] === 0) empties.push([r, c]);
					if (empties.length) {
						const near = empties.filter(([r, c]) => Math.abs(r - 7) <= 6 && Math.abs(c - 7) <= 6);
						const pool = near.length ? near : empties;
						const pick = pool[Math.floor(Math.random() * pool.length)];
						place(pick[0], pick[1], 2);
					}
				}
				thinking = false;
				turn = 1;
			}, 250);
		}
	}

	function reset() {
		board = Array.from({ length: N }, () => Array(N).fill(0));
		turn = 1;
		gameOver = false;
		winner = "";
		moveCount = 0;
		thinking = false;
	}
</script>

<div class="gomoku">
	<div class="gomoku-head">
		<span class="gomoku-status">
			{winner || (turn === 1 ? "轮到你：黑子 ●" : "电脑思考中… ○")}
		</span>
		<button class="gomoku-reset" on:click={reset}>重新开始</button>
	</div>
	<div class="gomoku-board" style={`--n: ${N}`}>
		{#each board as row, r}
			{#each row as cell, c}
				<button
					class="gomoku-cell"
					class:stone-black={cell === 1}
					class:stone-white={cell === 2}
					on:click={() => handleCell(r, c)}
					aria-label={`第${r + 1}行第${c + 1}列`}
				></button>
			{/each}
		{/each}
	</div>
</div>

<style>
	.gomoku {
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
		align-items: center;
	}
	.gomoku-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		gap: 0.5rem;
	}
	.gomoku-status {
		font-size: 0.85rem;
		font-weight: 600;
	}
	.gomoku-reset {
		font-size: 0.78rem;
		padding: 0.3rem 0.8rem;
		border-radius: 0.5rem;
		border: 1px solid var(--wb-border);
		background: var(--glass-surface-soft, var(--wb-hover));
		color: inherit;
		cursor: pointer;
	}
	.gomoku-reset:hover {
		color: var(--primary);
		border-color: color-mix(in oklch, var(--primary) 50%, var(--wb-border));
	}
	.gomoku-board {
		display: grid;
		grid-template-columns: repeat(var(--n), 1fr);
		width: min(100%, 26rem);
		aspect-ratio: 1;
		border: 2px solid var(--wb-border-strong);
		border-radius: 0.5rem;
		overflow: hidden;
		background: color-mix(in oklch, var(--primary) 8%, var(--page-bg));
	}
	.gomoku-cell {
		position: relative;
		border: none;
		padding: 0;
		background: transparent;
		cursor: pointer;
	}
	.gomoku-cell::after {
		content: "";
		position: absolute;
		inset: 12%;
		border-radius: 50%;
		transition: transform 0.12s ease, background 0.12s ease;
	}
	.gomoku-cell.stone-black::after {
		background: radial-gradient(circle at 35% 30%, #555, #000 70%);
		box-shadow: 0 1px 3px rgb(0 0 0 / 0.5);
	}
	.gomoku-cell.stone-white::after {
		background: radial-gradient(circle at 35% 30%, #fff, #bbb 70%);
		box-shadow: 0 1px 3px rgb(0 0 0 / 0.35);
	}
	.gomoku-cell:hover::after {
		transform: scale(0.55);
		background: color-mix(in oklch, var(--primary) 40%, transparent);
	}
</style>
