class_name Game
extends Node2D
## One level of play: owns every gameplay system and runs them in a fixed order each frame.

signal finished(stats: Dictionary)
signal retry
signal quit_to_title

const PAUSE_RECT := Rect2(240, 0, 30, 22)

var level_index := 1
var autotest := false
var autotest_weapon := "" # forces this weapon during autotest
var control_scheme := "touch" # "touch" (follow the finger) or "tilt"
var tilt := TiltInput.new()

var bg: Background
var ground_layer: Node2D
var air_layer: Node2D
var pickups: Pickups
var shots: PlayerShots
var player: Player
var bullets: BulletManager
var fx: Fx
var hud: Hud
var pause_menu: PauseMenu
var runner: LevelRunner
var score := ScoreKeeper.new()
var boss: BossHelios

var scroll_speed := 30.0
var target_scroll := 30.0
var enemies: Array[Enemy] = []
var extra_targets: Array[Target] = [] # dev weapon bench dummies
var paused := false
var time := 0.0

var _camera: Camera2D
var _shake := 0.0
var _freeze := 0.0
var _steer_index := -1
var _next_extend := Tun.EXTEND_FIRST # score that awards the next extra life
var game_over := false
var game_over_t := 0.0
var level_done := false
var _done_t := 0.0
var _warning_t := 0.0


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)

	bg = Background.new()
	add_child(bg)
	ground_layer = Node2D.new()
	add_child(ground_layer)
	pickups = Pickups.new()
	pickups.game = self
	shots = PlayerShots.new()
	shots.game = self
	air_layer = Node2D.new()
	add_child(air_layer)
	add_child(shots)
	add_child(pickups)
	player = Player.new()
	player.game = self
	player.position = Vector2(Tun.SCREEN.x / 2.0, Tun.SCREEN.y + 20)
	player.fly_in()
	add_child(player)
	bullets = BulletManager.new()
	bullets.game = self
	add_child(bullets)
	fx = Fx.new()
	add_child(fx)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Hud.new()
	hud.game = self
	ui.add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	pause_menu.resumed.connect(_on_resume)
	pause_menu.quit.connect(func() -> void: quit_to_title.emit())
	ui.add_child(pause_menu)
	var scan := Scanlines.new()
	ui.add_child(scan)

	_apply_control_scheme()

	runner = LevelRunner.new()
	runner.game = self
	runner.load_level("res://levels/level%d.json" % level_index)
	Audio.play_music(str(runner.data.get("music", "neon_drive")))
	if autotest:
		player.god = true


func _process(delta: float) -> void:
	if paused:
		return
	var dt := minf(delta, 1.0 / 30.0)
	if autotest:
		dt = 1.0 / 60.0
		_autopilot()
	_update_camera(dt)
	hud.update(dt)
	if _freeze > 0.0:
		_freeze -= dt
		return
	time += dt
	_update_drive(dt)
	runner.update(dt)
	scroll_speed = move_toward(scroll_speed, target_scroll, 20.0 * dt)
	bg.scroll(scroll_speed * dt, dt)
	player.update(dt)
	for e in enemies.duplicate():
		if not e.dead:
			e.update(dt)
	if boss:
		boss.update(dt)
		if player.can_be_hit() and boss.touches_player(player.position):
			player.hit()
	shots.update(dt, targets())
	bullets.update(dt)
	_check_body_collisions()
	pickups.update(dt)
	fx.update(dt)
	_check_extends()
	_update_warning(dt)
	_update_end_states(dt)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if paused:
			pause_menu.handle_touch(t)
			return
		if game_over or level_done:
			if not t.pressed:
				_on_end_tap()
			return
		if control_scheme == "tilt":
			# tilt steers, so every tap is free: pause button, otherwise bomb
			if t.pressed:
				if PAUSE_RECT.has_point(t.position):
					open_pause()
				else:
					player.request_bomb()
			return
		if t.pressed:
			if _steer_index == -1:
				if PAUSE_RECT.has_point(t.position):
					open_pause()
					return
				_steer_index = t.index
				player.set_target(t.position)
			elif t.index != _steer_index:
				player.request_bomb() # any extra finger = bomb (§3.3)
		elif t.index == _steer_index:
			_steer_index = -1
			player.release_target()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not paused and d.index == _steer_index:
			player.set_target(d.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_B, KEY_SPACE:
				player.request_bomb()
			KEY_P, KEY_ESCAPE:
				if paused:
					pause_menu.resume()
				else:
					open_pause()


func on_back() -> void:
	if game_over or level_done:
		quit_to_title.emit()
	elif paused:
		pause_menu.resume()
	else:
		open_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not paused and not autotest and is_inside_tree():
			open_pause()


func open_pause() -> void:
	if game_over or level_done:
		return
	paused = true
	_steer_index = -1
	player.release_target()
	pause_menu.open()
	Audio.set_music_paused(true)


func _on_resume() -> void:
	paused = false
	Audio.set_music_paused(false)
	_apply_control_scheme() # the scheme may have changed in the menu; also re-centres tilt


func _apply_control_scheme() -> void:
	control_scheme = Save.control_scheme
	_steer_index = -1
	player.release_target()
	player.use_drive = control_scheme == "tilt"
	player.drive = Vector2.ZERO
	if control_scheme == "tilt":
		tilt.calibrate() # wherever the phone is held now becomes "neutral"


## Tilt steering plus arrow keys / WASD (desktop testing) feed the player's drive vector.
func _update_drive(dt: float) -> void:
	if autotest:
		return # the autopilot steers
	var keys := Vector2(
		Input.get_axis(&"ui_left", &"ui_right") + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		Input.get_axis(&"ui_up", &"ui_down") + float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if control_scheme == "tilt":
		player.drive = tilt.read(dt) + keys
	elif keys != Vector2.ZERO:
		player.release_target()
		player.use_drive = true
		player.drive = keys
	elif player.use_drive:
		player.use_drive = false
		player.drive = Vector2.ZERO


# ------------------------------------------------------------------ world queries

## Everything the player's weapons can currently damage.
func targets() -> Array[Target]:
	var out: Array[Target] = []
	for e in enemies:
		if not e.dead and e.targetable and e.is_on_screen():
			out.append(e)
	if boss:
		out.append_array(boss.parts())
	out.append_array(extra_targets)
	return out


func blocks_shot(p: Vector2) -> bool:
	return boss != null and boss.blocks(p)


func spawn_enemy(kind: String, params: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, params, self)
	(ground_layer if e.ground else air_layer).add_child(e)
	enemies.append(e)
	score.spawned += 1
	return e


func remove_enemy(e: Enemy, _killed: bool) -> void:
	e.dead = true
	enemies.erase(e)
	e.queue_free()


func spawn_boss() -> void:
	boss = BossHelios.new()
	air_layer.add_child(boss)
	boss.setup(self)
	score.spawned += 3 # two arms + core count towards kill %
	hud.boss_target = boss
	Audio.play_music(str(runner.data.get("boss_music", "helios")))


# ------------------------------------------------------------------ events

func on_enemy_killed(e: Enemy) -> void:
	var pts := score.kill(e.score_value)
	fx.popup(e.global_position, str(pts), _popup_color())
	var big := e.kind in ["carrier", "subwoofer", "prism", "equalizer"]
	fx.explode(e.global_position, 3 if e.kind == "subwoofer" else (2 if big else 1))
	Audio.play("explode_big" if big else "explode_small")
	if big:
		shake(4.0)
		_freeze = 0.05
	if e.drop != "":
		pickups.spawn(e.drop, e.global_position)
	else:
		for kind: String in Tun.DROP_CHANCE:
			if randf() < float(Tun.DROP_CHANCE[kind]):
				pickups.spawn(kind, e.global_position)
				break
	remove_enemy(e, true)


func on_enemy_escaped(e: Enemy) -> void:
	if score.break_chain():
		hud.chain_lost()
		Audio.play("chain_lost")
	remove_enemy(e, false)


func on_boss_part_destroyed(part: Target, base: int) -> void:
	var pts := score.kill(base)
	fx.popup(part.global_position, str(pts), _popup_color(), 1.2)
	fx.explode(part.global_position, 3)
	Audio.play("part_break")
	shake(5.0)
	_freeze = 0.06


func on_boss_dying() -> void:
	# every bullet on screen turns into points
	var n := bullets.cancel(Vector2.ZERO, -1.0, true)
	score.add(n * Tun.BULLET_CASH)
	Audio.stop_music()


func on_boss_defeated() -> void:
	level_done = true
	_done_t = 0.0
	hud.banner("TITAN DOWN", "STAGE CLEAR", 4.0)


func on_player_died() -> void:
	_steer_index = -1
	if player.lives <= 0:
		game_over = true
		game_over_t = 0.0


func trigger_bomb(at: Vector2) -> void:
	bullets.cancel(Vector2.ZERO, -1.0)
	fx.ring(at, Tun.C_MAGENTA, 420.0, 0.6, 6.0)
	fx.ring(at, Tun.C_CYAN, 300.0, 0.6, 3.0)
	fx.flash(0.35)
	shake(5.0)
	Audio.play("bomb")
	Save.vibrate(90)
	for t in targets():
		t.take_damage(Tun.BOMB_DAMAGE * (Tun.BOMB_BOSS_FACTOR if t.is_boss_part else 1.0))


func add_points(n: int, at: Vector2) -> void:
	score.add(n)
	fx.popup(at, str(n), Tun.C_PALE)


func start_warning() -> void:
	_warning_t = 6.0
	hud.warning(6.0)
	Audio.stop_music()
	target_scroll = 20.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _popup_color() -> Color:
	var m := score.multiplier()
	if m >= 8.0:
		return Tun.C_MAGENTA
	if m >= 4.0:
		return Tun.C_PINK
	if m >= 2.0:
		return Tun.C_YELLOW
	return Tun.C_PALE


# ------------------------------------------------------------------ per-frame helpers

func _update_camera(dt: float) -> void:
	_shake = maxf(0.0, _shake - 20.0 * dt)
	if _shake > 0.0:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	else:
		_camera.offset = Vector2.ZERO


func _check_body_collisions() -> void:
	if not player.can_be_hit():
		return
	for e in enemies:
		if e.dead or e.ground:
			continue
		if e.hit_test(player.position, Tun.PLAYER_HITBOX_R):
			player.hit()
			e.take_damage(10.0)
			return


func _check_extends() -> void:
	if score.score >= _next_extend:
		_next_extend += Tun.EXTEND_EVERY
		player.lives += 1
		hud.banner("EXTEND", "+1 SHIP", 1.5)
		Audio.play("extend")


func _update_warning(dt: float) -> void:
	if _warning_t <= 0.0:
		return
	var before := _warning_t
	_warning_t -= dt
	if int(before) != int(_warning_t) and int(before) % 2 == 0:
		Audio.play("warning")
	if _warning_t <= 1.5:
		bullets.cancel(Vector2.ZERO, -1.0)


func _update_end_states(dt: float) -> void:
	if game_over:
		game_over_t += dt
		if autotest and game_over_t > 1.0:
			_on_end_tap()
	if level_done:
		_done_t += dt
		if _done_t > 4.0:
			_finish()


func _on_end_tap() -> void:
	if game_over and game_over_t > 1.5:
		retry.emit()
	elif level_done and _done_t > 1.5:
		_finish()


func _finish() -> void:
	if not level_done or _done_t < 0.0:
		return
	_done_t = -1000.0 # emit once
	finished.emit({
		"level": level_index,
		"name": str(runner.data.get("name", "")),
		"score": score.score,
		"max_chain": score.max_chain,
		"kills": score.kills,
		"spawned": score.spawned,
		"lives": player.lives,
		"bombs": player.bombs,
	})


# ------------------------------------------------------------------ autotest bot

func _autopilot() -> void:
	# Steers under the nearest target and grabs pickups; used by headless CI smoke tests.
	var goal := Vector2(Tun.SCREEN.x / 2.0, 400)
	var best := 1e9
	for t in targets():
		var d := absf(t.global_position.x - player.position.x)
		if d < best:
			best = d
			goal.x = t.global_position.x
	for it in pickups.items:
		if it.pos.y > 200:
			goal = it.pos
	if control_scheme == "tilt":
		player.drive = ((goal - player.position) / 24.0).limit_length(1.0)
	else:
		player.set_target(goal)
	if autotest_weapon != "":
		player.weapon = autotest_weapon
