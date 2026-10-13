extends Node
## Screen flow (§10.3): Title -> Level -> Results -> Title.
## Command-line user args (after `--`):
##   --autotest        start Level 1 immediately with an invulnerable autopilot, quit when it ends
##   --controls=tilt   with --autotest: steer through the tilt/drive path instead of touch
##   --weapon=<name>   with --autotest: play the whole level with vulcan, laser or wave
##   --shots=<dir>     with --autotest: save screenshots at fixed times into <dir>
##   --screen=results  open the results screen with sample stats (dev preview)
##   --snap=<file>     save a screenshot after 2.5 s and quit (dev preview)

var current: Node
var _autotest := false
var _weapon := ""
var _shots_dir := ""
var _shot_times: Array[float] = [3.0, 20.0, 45.0, 62.0, 90.0, 118.0, 135.0, 150.0, 165.0]
var _frames := 0
var _snap := ""
var _snap_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			_autotest = true
		elif a == "--controls=tilt":
			Save.control_scheme = "tilt"
		elif a.begins_with("--weapon="):
			_weapon = a.substr(9)
		elif a.begins_with("--shots="):
			_shots_dir = a.substr(8)
		elif a.begins_with("--snap="):
			_snap = a.substr(7)
	if _autotest:
		start_level(1)
	elif "--screen=results" in OS.get_cmdline_user_args():
		_on_level_finished({"level": 1, "name": "NEON DRIVE", "score": 412350, "max_chain": 96,
			"kills": 160, "spawned": 176, "lives": 2, "bombs": 1})
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


func start_level(n: int) -> void:
	var g := Game.new()
	g.level_index = n
	g.autotest = _autotest
	g.autotest_weapon = _weapon
	g.finished.connect(_on_level_finished)
	g.retry.connect(start_level.bind(n))
	g.quit_to_title.connect(goto_title)
	_swap(g)


func _on_level_finished(stats: Dictionary) -> void:
	if _autotest:
		print("AUTOTEST COMPLETE ", stats)
		get_tree().quit(0)
		return
	var r := ResultsScreen.new()
	r.stats = stats
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
		print("t=%.0f score=%d chain=%d kills=%d/%d enemies=%d bullets=%d boss=%s fps=%d" % [g.time, g.score.score,
			g.score.chain, g.score.kills, g.score.spawned, g.enemies.size(), g.bullets.count(),
			str(g.boss.state) if g.boss else "-", Engine.get_frames_per_second()])
	if _shots_dir != "" and not _shot_times.is_empty() and g.time >= _shot_times[0]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%03d.png" % [_shots_dir, int(_shot_times[0])])
		_shot_times.remove_at(0)
	if g.time > 400.0:
		push_error("AUTOTEST TIMEOUT")
		get_tree().quit(1)
