class_name Player
extends Node2D
## The player's ship: follows the steering finger (capped speed), always fires,
## has a shield + lives (§4) and the three weapon types (§5).

var game: Game

var target := Vector2.ZERO
var has_target := false
## Current top speed: starts at SPEED_BASE, raised by speed power-ups up to SPEED_MAX.
var speed := Tun.SPEED_BASE
## Tilt / keyboard steering: when use_drive is set the ship moves at drive * speed.
var use_drive := false
var drive := Vector2.ZERO

var weapon := "vulcan"
var level := 1
var shield := Tun.SHIELD_MAX
var lives := Tun.LIVES
var bombs := Tun.BOMBS_START
var alive := true
var invuln := 0.0
var god := false # autotest only

var _fire_t := 0.0
var _volley := 0
var _respawn_t := 0.0
var _control_lock := 0.0
var _bomb_cd := 0.0
var _bomb_requested := false
var _t := 0.0
var laser_on := false
var _tex: Texture2D


func _ready() -> void:
	_tex = Tun.tex("player")


func set_target(p: Vector2) -> void:
	target = p
	has_target = true


func release_target() -> void:
	has_target = false


## Level start: fly up onto the screen before control is handed over.
func fly_in() -> void:
	_control_lock = 0.8


func request_bomb() -> void:
	_bomb_requested = true


func can_be_hit() -> bool:
	return alive and invuln <= 0.0 and not god


func update(dt: float) -> void:
	_t += dt
	invuln = maxf(0.0, invuln - dt)
	_bomb_cd = maxf(0.0, _bomb_cd - dt)
	laser_on = false
	if not alive:
		_bomb_requested = false
		_respawn_t -= dt
		if _respawn_t <= 0.0 and lives > 0:
			_respawn()
		queue_redraw()
		return

	_move(dt)

	if _bomb_requested:
		_bomb_requested = false
		if bombs > 0 and _bomb_cd <= 0.0:
			bombs -= 1
			_bomb_cd = Tun.BOMB_COOLDOWN
			invuln = maxf(invuln, Tun.BOMB_INVULN)
			game.trigger_bomb(position)

	_fire(dt)
	queue_redraw()


func _move(dt: float) -> void:
	if _control_lock > 0.0:
		# respawn fly-in
		_control_lock -= dt
		position = position.move_toward(Vector2(position.x, 400), Tun.SPEED_MAX * 0.6 * dt)
		return
	if use_drive:
		position += drive.limit_length(1.0) * speed * dt
		position.x = clampf(position.x, Tun.PLAYER_MARGIN_X, Tun.SCREEN.x - Tun.PLAYER_MARGIN_X)
		position.y = clampf(position.y, Tun.PLAYER_MIN_Y, Tun.SCREEN.y - 10)
		return
	if not has_target:
		return
	var goal := target + Vector2(0, -Tun.TOUCH_OFFSET_Y)
	goal.x = clampf(goal.x, Tun.PLAYER_MARGIN_X, Tun.SCREEN.x - Tun.PLAYER_MARGIN_X)
	goal.y = clampf(goal.y, Tun.PLAYER_MIN_Y, Tun.SCREEN.y - 10)
	# move_toward never overshoots, so the ship settles exactly on the finger
	position = position.move_toward(goal, speed * dt)


func _fire(dt: float) -> void:
	match weapon:
		"vulcan":
			_fire_t -= dt
			while _fire_t <= 0.0:
				var cfg: Dictionary = Tun.VULCAN[level - 1]
				_fire_t += float(cfg.interval)
				_volley += 1
				for s: Array in cfg.get("heavy", []):
					game.shots.fire_vulcan(position + Vector2(s[0], -12), s[1], cfg.heavy_dmg, true)
				for s: Array in cfg.streams:
					game.shots.fire_vulcan(position + Vector2(s[0], -10), s[1], cfg.dmg)
				if cfg.has("side") and _volley % 2 == 0:
					for s: Array in cfg.side:
						game.shots.fire_vulcan(position + Vector2(s[0], -4), s[1], cfg.dmg)
				Audio.play("shot_vulcan", -14.0)
		"wave":
			_fire_t -= dt
			while _fire_t <= 0.0:
				var cfg: Dictionary = Tun.WAVE[level - 1]
				_fire_t += float(cfg.interval)
				for a in cfg.angles:
					game.shots.fire_wave(position + Vector2(0, -12), float(a), cfg.dmg, level)
				Audio.play("shot_wave", -12.0)
		"laser":
			laser_on = true
			var half_w := Tun.LASER_WIDTH[level - 1] / 2.0
			var dmg := Tun.LASER_DPS[level - 1] * dt
			for t in game.targets():
				if t.in_column(position.x, half_w, position.y - 8):
					t.take_damage(dmg)
					if randf() < 0.3:
						game.fx.spark(Vector2(position.x + randf_range(-half_w, half_w), t.global_position.y + t.hit_half.y), Tun.C_PINK, 1)
			Audio.play("shot_laser", -16.0)


func hit() -> void:
	if not can_be_hit():
		return
	game.bullets.cancel(position, Tun.HIT_CANCEL_RADIUS)
	if shield > 0:
		shield -= 1
		invuln = Tun.INVULN_HIT
		game.shake(3.0)
		game.fx.ring(position, Tun.C_MINT, 30.0, 0.25)
		Audio.play("player_hit")
		Save.vibrate(60)
	else:
		_die()


func _die() -> void:
	alive = false
	lives -= 1
	level = maxi(1, level - 1)
	_respawn_t = Tun.RESPAWN_DELAY
	has_target = false
	game.fx.explode(position, 3)
	game.shake(6.0)
	Audio.play("player_die")
	Save.vibrate(200)
	game.on_player_died()


func _respawn() -> void:
	alive = true
	shield = Tun.SHIELD_MAX
	bombs = maxi(bombs, Tun.BOMBS_START)
	invuln = Tun.INVULN_RESPAWN
	position = Vector2(Tun.SCREEN.x / 2.0, Tun.SCREEN.y + 20)
	_control_lock = 0.6
	_fire_t = 0.0


func _draw() -> void:
	if laser_on:
		_draw_laser()
	if not alive:
		return
	if invuln > 0.0 and fmod(_t, 0.12) < 0.06:
		return
	# exhaust flicker
	var f := int(_t * 30.0) % 3
	var flame_cols := [Tun.C_PALE, Tun.C_YELLOW, Tun.C_ORANGE]
	draw_rect(Rect2(-1, 13, 2, 2 + f), flame_cols[0])
	draw_rect(Rect2(-1, 15 + f, 2, 2), flame_cols[1 + f % 2])
	draw_rect(Rect2(-1, 17 + f, 2, 1), Tun.C_PINK)
	draw_texture(_tex, Vector2(-11, -6))
	# hitbox core
	var pulse := 0.6 + 0.4 * sin(_t * 12.0)
	draw_rect(Rect2(-1, -1, 2, 2), Color(1, 1, 1, pulse))


func _draw_laser() -> void:
	var w := Tun.LASER_WIDTH[level - 1]
	var top := -position.y
	var jitter := 1.0 if int(_t * 40.0) % 2 == 0 else 0.0
	var beam_len := -10.0 - top
	draw_rect(Rect2(-w / 2.0 - 2 - jitter, top, w + 4 + jitter * 2, beam_len), Color(Tun.C_MAGENTA, 0.35))
	draw_rect(Rect2(-w / 2.0, top, w, beam_len), Tun.C_PINK)
	draw_rect(Rect2(-maxf(1.0, w / 4.0), top, maxf(2.0, w / 2.0), beam_len), Tun.C_WHITE)
	# muzzle
	draw_circle(Vector2(0, -10), w / 2.0 + 2 + jitter, Color(Tun.C_PINK, 0.8))
	draw_circle(Vector2(0, -10), w / 3.0 + 1, Tun.C_WHITE)
