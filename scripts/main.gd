extends Node
## Screen flow (§10.3): Title -> Level 1 -> Results -> Level 2 -> ... -> Results -> Title.
## Score, lives, bombs, weapon, weapon level and speed carry from one level into the next.
## Command-line user args (after `--`):
##   --autotest        start Level 1 immediately with an invulnerable autopilot, quit when it ends
##   --level=<n>       with --autotest: start at level n (later levels get a preset loadout)
##   --campaign        with --autotest: carry on into the following levels instead of quitting
##   --controls=tilt   with --autotest: steer through the tilt/drive path instead of touch
##   --weapon=<name>   with --autotest: play the whole level with vulcan, laser or wave
##   --shots=<dir>     with --autotest: save screenshots at fixed times into <dir>
##   --screen=results  open the results screen with sample stats (dev preview)
##   --bench[=out.md] measure every weapon/level against dummy targets and quit (dev)
##   --snap=<file>     save a screenshot after 2.5 s and quit (dev preview)

var current: Node
var _autotest := false
var _weapon := ""
var _shots_dir := ""
var _shot_times: Array[float] = [3.0, 20.0, 45.0, 62.0, 90.0, 118.0, 135.0, 150.0, 165.0]
var _frames := 0
var _snap := ""
var _start_at := 1
var _campaign := false
var _entry_carry := {} # loadout the current level was entered with (restored on retry)
var _snap_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			_autotest = true
		elif a == "--controls=tilt":
			Save.control_scheme = "tilt"
		elif a.begins_with("--level="):
			_start_at = int(a.substr(8))
		elif a == "--campaign":
			_campaign = true
		elif a.begins_with("--weapon="):
			_weapon = a.substr(9)
		elif a.begins_with("--shots="):
			_shots_dir = a.substr(8)
		elif a.begins_with("--snap="):
			_snap = a.substr(7)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench"):
			var b := WeaponBench.new()
			b.out_path = a.substr(8) if a.begins_with("--bench=") else ""
			add_child(b)
			return
	if _autotest:
		start_level(_start_at, _dev_preset(_start_at))
	elif "--screen=results" in OS.get_cmdline_user_args():
		_on_level_finished({"level": 1, "name": "NEON DRIVE", "score": 412350, "max_chain": 96,
			"kills": 160, "spawned": 176, "lives": 2, "bombs": 1, "weapon": "vulcan", "weapon_level": 5,
			"speed": 200.0})
	else:
		goto_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and current and current.has_method("on_back"):
		current.on_back()


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)


func goto_title() -> void:
	var t := TitleScreen.new()
	t.start_pressed.connect(start_level.bind(1))
	_swap(t)


func start_level(n: int, carry: Dictionary = {}) -> void:
	_entry_carry = carry.duplicate()
	var g := Game.new()
	g.level_index = n
	g.carry = carry
	g.autotest = _autotest
	g.autotest_weapon = _weapon
	g.finished.connect(_on_level_finished)
	g.retry.connect(_on_retry.bind(n))
	g.quit_to_title.connect(goto_title)
	_swap(g)


## Game over restarts the current level with the loadout it was entered with (at least 3 lives).
func _on_retry(n: int) -> void:
	var c := _entry_carry.duplicate()
	if not c.is_empty():
		c.lives = maxi(int(c.get("lives", Tun.LIVES)), Tun.LIVES)
	start_level(n, c)


static func has_level(n: int) -> bool:
	return FileAccess.file_exists("res://levels/level%d.json" % n)


## Loadout carried into the next level: everything the player had, score including end bonuses.
static func carry_from(stats: Dictionary) -> Dictionary:
	return {
		"score": ResultsScreen.total_for(stats),
		"lives": stats.lives,
		"bombs": stats.bombs,
		"weapon": stats.weapon,
		"weapon_level": stats.weapon_level,
		"speed": stats.speed,
	}


## Dev/testing only: a plausible loadout for starting directly at a later level.
func _dev_preset(n: int) -> Dictionary:
	if n <= 1:
		return {}
	return {"score": 0, "lives": Tun.LIVES, "bombs": Tun.BOMBS_START,
		"weapon": _weapon if _weapon != "" else "vulcan", "weapon_level": 5, "speed": 165.0}


func _on_level_finished(stats: Dictionary) -> void:
	var next := int(stats.level) + 1
	if _autotest:
		print("AUTOTEST LEVEL %d CLEAR " % int(stats.level), stats)
		if _campaign and has_level(next):
			start_level(next, carry_from(stats))
			return
		print("AUTOTEST COMPLETE ", stats)
		get_tree().quit(0)
		return
	var r := ResultsScreen.new()
	r.stats = stats
	if has_level(next):
		r.done.connect(func() -> void: start_level(next, carry_from(stats)))
	else:
		r.done.connect(goto_title)
	_swap(r)


func _process(delta: float) -> void:
	if _snap != "":
		_snap_t += delta
		if _snap_t > 2.5:
			get_viewport().get_texture().get_image().save_png(_snap)
			get_tree().quit(0)
	if not _autotest:
		return
	_frames += 1
	var g := current as Game
	if g == null:
		return
	if _frames % 600 == 0:
		print("t=%.0f score=%d chain=%d kills=%d/%d enemies=%d bullets=%d boss=%s weapon=%s L%d speed=%d fps=%d" % [g.time,
			g.score.score, g.score.chain, g.score.kills, g.score.spawned, g.enemies.size(), g.bullets.count(),
			str(g.boss.state) if g.boss else "-", g.player.weapon, g.player.level, roundi(g.player.speed),
			Engine.get_frames_per_second()])
	if _shots_dir != "" and not _shot_times.is_empty() and g.time >= _shot_times[0]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%03d.png" % [_shots_dir, int(_shot_times[0])])
		_shot_times.remove_at(0)
	if g.time > 400.0:
		push_error("AUTOTEST TIMEOUT")
		get_tree().quit(1)
