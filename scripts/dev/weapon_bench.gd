class_name WeaponBench
extends Node
## Dev tool: measures every weapon at every level against stationary dummy targets using the
## real firing and collision code. Run: godot --headless -- --bench[=out.md]
## Reports damage per second in several target layouts (player at the bottom centre).

class Dummy extends Target:
	var taken := 0.0

	func take_damage(amount: float) -> void:
		taken += amount

const WARMUP := 1.0
const MEASURE := 6.0
const DT := 1.0 / 60.0
const PLAYER_POS := Vector2(135, 420)

## name -> list of [position, half extents]. Distances are from the ship at y=420.
var scenarios := {
	"small_far": [[Vector2(135, 180), Vector2(5, 5)]],
	"small_near": [[Vector2(135, 330), Vector2(5, 5)]],
	"large": [[Vector2(135, 230), Vector2(21, 21)]],
	"large_far": [[Vector2(135, 110), Vector2(21, 21)]],
	"offset_40": [[Vector2(175, 230), Vector2(5, 5)]],
	"swarm_27": [], # filled in _ready: 3 staggered rows of 9 small enemies
}

var out_path := ""


func _ready() -> void:
	var swarm := []
	for row in 3:
		for i in 9:
			swarm.append([Vector2(15 + i * 30 + (row % 2) * 15, 160 + row * 40), Vector2(5, 5)])
	scenarios["swarm_27"] = swarm
	var game := Game.new()
	add_child(game)
	await get_tree().process_frame
	game.paused = true # the bench drives the systems itself
	Audio.stop_music()
	var p := game.player
	p.god = true
	var rows := []
	for w: String in Tun.WEAPONS:
		for lvl in range(1, Tun.WEAPON_MAX + 1):
			var row := {"weapon": w, "level": lvl}
			for sname: String in scenarios:
				row[sname] = _measure(game, w, lvl, scenarios[sname])
			rows.append(row)
	_report(rows)
	get_tree().quit(0)


func _measure(game: Game, w: String, lvl: int, layout: Array) -> float:
	var p := game.player
	p.weapon = w
	p.level = lvl
	p.position = PLAYER_POS
	p.release_target()
	game.shots.clear()
	for t in game.extra_targets:
		t.queue_free()
	game.extra_targets.clear()
	for spec: Array in layout:
		var d := Dummy.new()
		d.game = game
		d.position = spec[0]
		d.hit_half = spec[1]
		game.add_child(d)
		game.extra_targets.append(d)
	var steps := int((WARMUP + MEASURE) / DT)
	for i in steps:
		if i == int(WARMUP / DT):
			for t: Dummy in game.extra_targets:
				t.taken = 0.0
		p.update(DT)
		game.shots.update(DT, game.targets())
		game.fx.update(DT)
	var total := 0.0
	for t: Dummy in game.extra_targets:
		total += t.taken
	return total / MEASURE


func _report(rows: Array) -> void:
	var cols: Array = scenarios.keys()
	var lines := PackedStringArray()
	lines.append("| weapon | L | " + " | ".join(cols) + " |")
	lines.append("|---|---|" + "---|".repeat(cols.size()))
	for r: Dictionary in rows:
		var cells := PackedStringArray()
		for c: String in cols:
			cells.append("%d" % roundi(r[c]))
		lines.append("| %s | %d | %s |" % [r.weapon, r.level, " | ".join(cells)])
	var text := "\n".join(lines)
	print(text)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text + "\n")
