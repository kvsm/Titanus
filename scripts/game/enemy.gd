class_name Enemy
extends Target
## All regular enemies (§8). Behaviour is chosen by `kind`.
## An enemy that has entered the screen and then leaves it alive "escapes" and breaks the chain.

var kind := ""
var params := {}
var score_value := 100
var drop := ""
var ground := false
var entered := false

var _t := 0.0
var _state := 0
var _timer := 0.0
var _tex: Texture2D
var _vel := Vector2.ZERO

# path followers
var _path := PackedVector2Array()
var _seg := 0
var _seg_t := 0.0
var _speed := 100.0

# per-kind state
var _shots_left := 0
var _fire_at := -1.0
var _fire_t := 0.0
var _home_x := 0.0
var _gun_tex: Texture2D
var _gun_angle := PI / 2.0
var _glow := 0.0
var _trail: Array[Vector2] = []
var _last_beat := -1
var _pulse := 0.0


func setup(k: String, p: Dictionary, g: Game) -> void:
	kind = k
	params = p
	game = g
	var cfg: Dictionary = Tun.ENEMIES[k]
	hp = cfg.hp
	max_hp = hp
	hit_half = cfg.half
	score_value = cfg.score
	_tex = Tun.tex(cfg.tex)
	drop = str(p.get("drop", ""))
	match kind:
		"glitch":
			_path = Paths.build(str(p.get("path", "dive_u")), bool(p.get("mirror", false)), float(p.get("dx", 0.0)))
			position = _path[0]
			_speed = float(p.get("speed", 110.0))
			if randf() < 0.2:
				_fire_at = randf_range(0.8, 2.0)
		"strobe":
			position = Vector2(float(p.get("x", 135.0)), -14)
			_home_x = position.x
			_shots_left = int(p.get("burst", 1))
		"turret":
			ground = true
			position = Vector2(float(p.get("x", 135.0)), -12)
			_gun_tex = Tun.tex("turret_gun")
			_fire_t = 1.0
		"car":
			var dir := int(p.get("dir", 1))
			position = Vector2(-14 if dir > 0 else Tun.SCREEN.x + 14, float(p.get("y", 150.0)))
			_vel = Vector2(150.0 * dir, 0)
		"carrier":
			position = Vector2(float(p.get("x", 135.0)), -20)
			_home_x = position.x
			if drop == "":
				drop = "capsule"
		"subwoofer":
			position = Vector2(135, -30)
		"note":
			position = p.get("pos", Vector2(135, 60))
			_vel = Vector2(randf_range(-40, 40), 60)


func update(dt: float) -> void:
	_t += dt
	flash = maxf(0.0, flash - dt)
	match kind:
		"glitch": _update_glitch(dt)
		"strobe": _update_strobe(dt)
		"turret": _update_turret(dt)
		"car": _update_car(dt)
		"carrier": _update_carrier(dt)
		"subwoofer": _update_subwoofer(dt)
		"note": _update_note(dt)
	if dead:
		return
	if not entered:
		entered = is_on_screen()
		if not entered and _t > 12.0:
			game.remove_enemy(self, false)
	elif _is_gone():
		game.on_enemy_escaped(self)
	queue_redraw()


func _is_gone() -> bool:
	var m := Tun.ESCAPE_MARGIN
	var g := global_position
	return g.x < -m or g.x > Tun.SCREEN.x + m or g.y < -m or g.y > Tun.SCREEN.y + m


## Enemies only shoot from a fair part of the screen.
func _can_fire() -> bool:
	return position.y > 6 and position.y < 360 and position.x > 0 and position.x < Tun.SCREEN.x \
		and game.player.alive and position.distance_to(game.player.position) > 50


# ----------------------------------------------------------------- behaviours

func _follow_path(dt: float) -> void:
	var step := _speed * dt
	while step > 0.0 and _seg < _path.size() - 1:
		var a := _path[_seg]
		var b := _path[_seg + 1]
		var seg_len := a.distance_to(b)
		var remaining := seg_len * (1.0 - _seg_t)
		if step < remaining:
			_seg_t += step / seg_len
			step = 0.0
		else:
			step -= remaining
			_seg += 1
			_seg_t = 0.0
	if _seg >= _path.size() - 1:
		position += (_path[_path.size() - 1] - _path[_path.size() - 2]).normalized() * _speed * dt
	else:
		position = _path[_seg].lerp(_path[_seg + 1], _seg_t)


func _update_glitch(dt: float) -> void:
	_follow_path(dt)
	if _fire_at > 0.0 and _t >= _fire_at and _can_fire():
		_fire_at = -1.0
		game.bullets.fire(position, game.bullets.aim(position), 80.0, Tun.B.PINK)
		Audio.play("enemy_shot", -6.0)


func _update_strobe(dt: float) -> void:
	var target_y := float(params.get("y", 120.0))
	match _state:
		0: # dive and brake
			position.y += maxf(40.0, (target_y - position.y) * 3.0) * dt
			if position.y >= target_y - 1.0:
				position.y = target_y
				_state = 1
				_timer = 0.0
		1: # hover and shoot
			_timer += dt
			position.x = _home_x + sin(_timer * 3.0) * 3.0
			if _timer >= 0.5 and _shots_left > 0 and _can_fire():
				_fire_t -= dt
				if _fire_t <= 0.0:
					_fire_t = 0.12
					_shots_left -= 1
					game.bullets.fire(position + Vector2(0, 6), game.bullets.aim(position), 105.0, Tun.B.PINK)
					Audio.play("enemy_shot", -4.0)
			if _timer >= 2.0:
				_state = 2
		2: # retreat
			_vel.y = maxf(_vel.y - 300.0 * dt, -140.0)
			position += _vel * dt


func _update_turret(dt: float) -> void:
	position.y += game.scroll_speed * dt
	var to_player := game.player.position - position
	_gun_angle = lerp_angle(_gun_angle, to_player.angle(), minf(1.0, 4.0 * dt))
	if position.y < 10 or position.y > 380:
		return
	_fire_t -= dt
	_glow = clampf(1.0 - _fire_t / 0.4, 0.0, 1.0) if _fire_t < 0.4 else 0.0
	if _fire_t <= 0.0 and _can_fire():
		_fire_t = 2.0
		_shots_left = 3
		_timer = 0.0
	if _shots_left > 0:
		_timer -= dt
		if _timer <= 0.0:
			_timer = 0.12
			_shots_left -= 1
			var muzzle := position + Vector2.from_angle(_gun_angle) * 9.0
			game.bullets.fire(muzzle, _gun_angle, 100.0, Tun.B.ORANGE)
			Audio.play("enemy_shot", -6.0)


func _update_car(dt: float) -> void:
	var dir := signf(_vel.x) if _vel.x != 0.0 else 1.0
	var stop_x := float(params.get("stop_x", 135.0))
	match _state:
		0:
			var dist := (stop_x - position.x) * dir
			if dist < 60.0:
				_vel.x = move_toward(_vel.x, 30.0 * dir, 260.0 * dt)
			if dist <= 0.0:
				_state = 1
				if _can_fire():
					game.bullets.fan(position + Vector2(0, 4), PI / 2.0, 3, 40.0, 90.0, Tun.B.PINK)
					Audio.play("enemy_shot", -4.0)
		1:
			_vel.x = move_toward(_vel.x, 190.0 * dir, 200.0 * dt)
	position += _vel * dt
	_trail.push_front(position)
	if _trail.size() > 10:
		_trail.pop_back()


func _update_carrier(dt: float) -> void:
	var target_y := float(params.get("y", 90.0))
	match _state:
		0:
			position.y += maxf(20.0, (target_y - position.y) * 1.5) * dt
			if position.y >= target_y - 1.0:
				_state = 1
				_timer = 0.0
				_fire_t = 0.6
		1:
			_timer += dt
			position.x = _home_x + sin(_timer * 0.8) * 60.0
			_fire_t -= dt
			if _fire_t <= 0.0 and _can_fire():
				_fire_t = 0.9
				game.bullets.ring(position + Vector2(0, 6), 6, 70.0, Tun.B.VIOLET, deg_to_rad(_timer * 40.0))
				Audio.play("enemy_shot", -4.0)
			if _timer >= 8.0:
				_state = 2
		2:
			_vel.y = maxf(_vel.y - 60.0 * dt, -90.0)
			position += _vel * dt


func _update_subwoofer(dt: float) -> void:
	_pulse = maxf(0.0, _pulse - dt * 4.0)
	match _state:
		0:
			position.y += maxf(25.0, (110.0 - position.y) * 1.2) * dt
			if position.y >= 109.0:
				_state = 1
				_timer = 0.0
		1:
			_timer += dt
			position.x = 135.0 + sin(_timer * 0.6) * 30.0
			# fire on the beat of the stage music (110 BPM)
			var beat_len := 60.0 / 110.0
			var mt := Audio.music_time()
			var beat := int(floor(mt / beat_len)) if mt >= 0.0 else int(floor(_timer / beat_len))
			if beat != _last_beat:
				_last_beat = beat
				if not _can_fire():
					return
				if beat % 2 == 0:
					_pulse = 1.0
					var offset := PI / 16.0 if (beat / 2) % 2 == 0 else 0.0
					game.bullets.ring(position, 16, 75.0, Tun.B.PINK, offset)
					Audio.play("enemy_shot")
				else:
					game.bullets.fan(position + Vector2(0, 16), game.bullets.aim(position), 3, 24.0, 110.0, Tun.B.ORANGE)


func _update_note(dt: float) -> void:
	if _t < 3.0 and game.player.alive:
		var desired := (game.player.position - position).normalized() * 60.0
		_vel = _vel.lerp(desired, minf(1.0, 1.5 * dt))
	position += _vel * dt


# ----------------------------------------------------------------- damage

func take_damage(amount: float) -> void:
	if dead or not targetable:
		return
	hp -= amount
	flash = 0.05
	Audio.play("hit", -10.0)
	if hp <= 0.0:
		game.on_enemy_killed(self)


func _draw() -> void:
	var mod := Color(6, 6, 6) if flash > 0.0 else Color.WHITE
	match kind:
		"turret":
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			draw_set_transform(Vector2.ZERO, _gun_angle - PI / 2.0)
			draw_texture(_gun_tex, Vector2(-4, -4), mod)
			draw_set_transform(Vector2.ZERO)
			if _glow > 0.0:
				var muzzle := Vector2.from_angle(_gun_angle) * 9.0
				draw_circle(muzzle, 1.0 + _glow * 2.0, Color(Tun.C_ORANGE, _glow))
		"car":
			for i in _trail.size():
				var p := _trail[i] - position
				var a := 1.0 - float(i) / _trail.size()
				var back := -signf(_vel.x) * 9.0
				draw_rect(Rect2(p.x + back - 1, p.y - 3, 2, 1), Color(Tun.C_PINK, a * 0.8))
				draw_rect(Rect2(p.x + back - 1, p.y + 2, 2, 1), Color(Tun.C_PINK, a * 0.8))
			var flip := _vel.x < 0.0
			if flip:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			draw_set_transform(Vector2.ZERO)
		"subwoofer":
			var s := 1.0 + _pulse * 0.06
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			draw_set_transform(Vector2.ZERO)
		"glitch", "note":
			var bob := Vector2(0, roundf(sin(_t * 8.0)))
			draw_texture(_tex, -_tex.get_size() / 2.0 + bob, mod)
		_:
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
