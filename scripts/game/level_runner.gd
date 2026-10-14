class_name LevelRunner
extends RefCounted
## Plays a level timeline from JSON (levels/levelN.json). Each event has a time `t` and an action `do`:
##   spawn    enemy=<kind> (+ x / y / path / count / gap / formation / dir / drop / burst ...)
##   scroll   speed=<px/s>
##   bg       tile=outskirts|downtown
##   banner   text, sub
##   midboss  enemy=<kind>   (the timeline holds until it dies)
##   storm    on=true|false   (rain + lightning overlay)
##   warning
##   boss
## `x` and `y` may be lists to spawn several enemies at once.

var game: Game
var data := {}
var time := 0.0
var hold := false
var _events: Array = []
var _idx := 0
var _pending: Array = [] # [time, kind, params] for delayed formation members


func load_level(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	_events = data.events
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))


func update(dt: float) -> void:
	if hold:
		return
	time += dt
	while _idx < _events.size() and float(_events[_idx].t) <= time:
		_run(_events[_idx])
		_idx += 1
	var i := 0
	while i < _pending.size():
		if _pending[i][0] <= time:
			game.spawn_enemy(_pending[i][1], _pending[i][2])
			_pending.remove_at(i)
		else:
			i += 1


func finished() -> bool:
	return _idx >= _events.size() and _pending.is_empty()


func _run(e: Dictionary) -> void:
	match str(e.do):
		"spawn":
			_spawn(e)
		"scroll":
			game.target_scroll = float(e.speed)
		"bg":
			game.bg.mode = str(e.tile)
		"banner":
			game.hud.banner(str(e.get("text", "")), str(e.get("sub", "")), float(e.get("dur", 3.0)))
		"midboss":
			hold = true
			var m := game.spawn_enemy(str(e.enemy), e)
			m.tree_exited.connect(func() -> void: hold = false)
			game.hud.boss_target = m
		"warning":
			game.start_warning()
		"storm":
			game.bg.storm = bool(e.get("on", true))
		"boss":
			game.spawn_boss(str(e.get("name", "helios")))


func _spawn(e: Dictionary) -> void:
	var kind := str(e.enemy)
	var count := int(e.get("count", 1))
	var gap := float(e.get("gap", 0.3))
	var xs: Array = e.x if e.get("x") is Array else [e.get("x", 135.0)]
	var ys: Array = e.y if e.get("y") is Array else [e.get("y", null)]
	for xi in xs.size():
		for n in count:
			var p := e.duplicate()
			p.x = xs[xi]
			var yv: Variant = ys[mini(xi, ys.size() - 1)]
			if yv != null:
				p.y = yv
			else:
				p.erase("y")
			var delay := gap * n
			if str(e.get("formation", "")) == "v":
				var mid := (count - 1) / 2.0
				p.dx = float(e.get("dx", 0.0)) + (n - mid) * 18.0
				delay = absf(n - mid) * 0.18
			if delay <= 0.0:
				game.spawn_enemy(kind, p)
			else:
				_pending.append([time + delay, kind, p])
