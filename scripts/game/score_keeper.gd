class_name ScoreKeeper
extends RefCounted
## Score and the unlimited kill chain (§6). Only an escaping enemy breaks the chain.

var score := 0
var chain := 0
var max_chain := 0
var kills := 0
var spawned := 0
var escaped := 0


func multiplier() -> float:
	return 1.0 + chain / Tun.CHAIN_DIV


## Registers a kill and returns the points it earned.
func kill(base: int) -> int:
	chain += 1
	max_chain = maxi(max_chain, chain)
	kills += 1
	return add(int(roundf(base * multiplier())))


func add(points: int) -> int:
	score += points
	return points


## Returns true if there was a chain to lose.
func break_chain() -> bool:
	escaped += 1
	var had := chain > 0
	chain = 0
	return had


func kill_percent() -> float:
	return 100.0 if spawned == 0 else 100.0 * kills / spawned
