class_name Enemy
extends Target
## All regular enemies (§8). Behaviour is chosen by `behaviour` (the kind's own name unless
## Tun.ENEMIES gives it another one, e.g. the Level 2 TRAWLER flies like a carrier).
## An enemy that has entered the screen and then leaves it alive "escapes" and breaks the chain.

var kind := ""
var behaviour := ""
## Projectile-like enemies (torpedoes) give points but never count for the chain or kill %.
var chain_exempt := false
var alpha := 1.0
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
	behaviour = str(cfg.get("behaviour", k))
	chain_exempt = bool(cfg.get("exempt", false))
	match behaviour:
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
			drop = "capsule" # supply ships always carry a weapon capsule
		"prism":
			position = Vector2(float(p.get("x", 135.0)), -16)
			_home_x = position.x
			_fire_t = 0.8
			_shots_left = 3 # volleys before it retreats
		"equalizer":
			position = Vector2(float(p.get("x", 135.0)), -20)
			_home_x = position.x
		"subwoofer":
			position = Vector2(135, -30)
		"mine":
			ground = true
			position = Vector2(float(p.get("x", 135.0)), -10)
		"harpooner", "inker", "torpedo_boat", "frigate":
			position = Vector2(float(p.get("x", 135.0)), -24)
			_home_x = position.x
			_fire_t = 1.0
			_shots_left = {"harpooner": 3, "inker": 3, "torpedo_boat": 3, "frigate": 4}[behaviour]
		"torpedo":
			position = p.get("pos", Vector2(135, 60))
			_vel = Vector2(0, 40)
		"barracuda":
			position = Vector2(135, 110)
			_home_x = position.x
			alpha = 0.0
			targetable = false
		"note":
			position = p.get("pos", Vector2(135, 60))
			_vel = Vector2(randf_range(-40, 40), 60)


func update(dt: float) -> void:
	_t += dt
	flash = maxf(0.0, flash - dt)
	match behaviour:
		"glitch": _update_glitch(dt)
		"strobe": _update_strobe(dt)
		"turret": _update_turret(dt)
		"car": _update_car(dt)
		"carrier": _update_carrier(dt)
		"prism": _update_prism(dt)
		"equalizer": _update_equalizer(dt)
		"subwoofer": _update_subwoofer(dt)
		"note": _update_note(dt)
		"mine": _update_mine(dt)
		"harpooner": _update_harpooner(dt)
		"inker": _update_inker(dt)
		"torpedo_boat": _update_torpedo_boat(dt)
		"torpedo": _update_torpedo(dt)
		"frigate": _update_frigate(dt)
		"barracuda": _update_barracuda(dt)
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


## PRISM: hovers and lobs slow crystal shards that burst into rings (Tun.SPLIT_TIME).
func _update_prism(dt: float) -> void:
	var target_y := float(params.get("y", 110.0))
	match _state:
		0:
			position.y += maxf(30.0, (target_y - position.y) * 2.0) * dt
			if position.y >= target_y - 1.0:
				_state = 1
				_timer = 0.0
		1:
			_timer += dt
			position.x = _home_x + sin(_timer * 1.2) * 18.0
			_fire_t -= dt
			_glow = clampf(1.0 - _fire_t / 0.5, 0.0, 1.0) if _fire_t < 0.5 else 0.0
			if _fire_t <= 0.0:
				_fire_t = 1.7
				if _can_fire():
					var from := position + Vector2(0, 6)
					game.bullets.fan(from, game.bullets.aim(from), 3, 50.0, 55.0, Tun.B.SHARD)
					Audio.play("enemy_shot", 0.0, 0.7)
				_shots_left -= 1
				if _shots_left <= 0:
					_state = 2
		2:
			_vel.y = maxf(_vel.y - 120.0 * dt, -110.0)
			position += _vel * dt


## EQUALIZER: sweeps a fan-shaped curtain of bullets from its five EQ bars,
## always leaving a two-bar gap that walks across the pattern.
func _update_equalizer(dt: float) -> void:
	var target_y := float(params.get("y", 72.0))
	match _state:
		0:
			position.y += maxf(18.0, (target_y - position.y) * 1.2) * dt
			if position.y >= target_y - 1.0:
				_state = 1
				_timer = 0.0
		1:
			_timer += dt
			position.x = _home_x + sin(_timer * 0.7) * 40.0
			var cycle := fmod(_timer, 2.2)
			_glow = 1.0 if cycle < 1.4 else 0.0
			if cycle < 1.4:
				_fire_t -= dt
				if _fire_t <= 0.0:
					_fire_t = 0.14
					if _can_fire():
						var gap := int(_timer / 0.7) % 5
						for i in 5:
							if i == gap or i == (gap + 1) % 5:
								continue
							var from := position + Vector2((i - 2) * 6.0 - 0.5, 12)
							game.bullets.fire(from, deg_to_rad(90.0 + (i - 2) * 14.0), 110.0, Tun.B.PINK)
						Audio.play("enemy_shot", -6.0, 1.3)
			if _timer >= 9.0:
				_state = 2
		2:
			_vel.y = maxf(_vel.y - 50.0 * dt, -80.0)
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


# ----------------------------------------------------------------- Level 2: NEON TIDE

## Shared by the gunboats: sail down to a station, sway, and leave after their volleys.
func _station(dt: float, target_y: float, sway: float) -> bool:
	match _state:
		0:
			position.y += maxf(26.0, (target_y - position.y) * 1.6) * dt
			if position.y >= target_y - 1.0:
				_state = 1
				_timer = 0.0
		1:
			_timer += dt
			position.x = _home_x + sin(_timer * 0.8) * sway
			return true
		2:
			_vel.y = maxf(_vel.y - 70.0 * dt, -100.0)
			position += _vel * dt
	return false


## MINE: floats with the water. Arms when the player comes close, blinks, then bursts.
func _update_mine(dt: float) -> void:
	position.y += game.scroll_speed * dt
	match _state:
		0:
			if position.y > 20.0 and game.player.alive and position.distance_to(game.player.position) < 70.0:
				_state = 1
				_timer = 0.6
				Audio.play("mine_arm")
		1:
			_timer -= dt
			if _timer <= 0.0:
				game.bullets.ring(position, 12, 85.0, Tun.B.ORANGE, randf() * TAU)
				game.fx.explode(position, 1)
				Audio.play("explode_small")
				game.remove_enemy(self, false) # detonated: no kill, no chain break


## HARPOONER: aims (telegraph line), then fires a harpoon that leaves a hanging chain.
func _update_harpooner(dt: float) -> void:
	if not _station(dt, float(params.get("y", 90.0)), 30.0):
		return
	_fire_t -= dt
	if _fire_t <= 0.8 and _fire_t > 0.0 and _glow == 0.0 and _can_fire():
		_glow = 1.0 # start the telegraph and lock the aim
		_gun_angle = game.bullets.aim(position)
	if _fire_t <= 0.0:
		_fire_t = 2.4
		if _glow > 0.0:
			game.bullets.fire(position + Vector2(0, 12), _gun_angle, 260.0, Tun.B.HARPOON)
			Audio.play("harpoon")
			_shots_left -= 1
		_glow = 0.0
		if _shots_left <= 0:
			_state = 2


## INKER: squid drone. Pulses down, squirts slowing ink puddles plus a slow pellet fan.
func _update_inker(dt: float) -> void:
	var target_y := float(params.get("y", 130.0))
	if _state == 0:
		# jet-propulsion: bursts of speed
		position.y += (40.0 + 90.0 * maxf(0.0, sin(_t * 5.0))) * dt
		if position.y >= target_y:
			_state = 1
			_timer = 0.0
		return
	if _state == 2:
		_vel.y = maxf(_vel.y - 80.0 * dt, -110.0)
		position += _vel * dt
		return
	_timer += dt
	position.x = _home_x + sin(_timer * 1.4) * 14.0
	_fire_t -= dt
	if _fire_t <= 0.0:
		_fire_t = 2.0
		if _can_fire():
			game.ink.spawn(position + Vector2(0, 16))
			game.bullets.fan(position + Vector2(0, 10), game.bullets.aim(position), 5, 50.0, 60.0, Tun.B.VIOLET)
			Audio.play("splash")
		_shots_left -= 1
		if _shots_left <= 0:
			_state = 2


## TORPEDO BOAT: launches pairs of shootable torpedoes that steer towards the player's column.
func _update_torpedo_boat(dt: float) -> void:
	if not _station(dt, float(params.get("y", 80.0)), 40.0):
		return
	_fire_t -= dt
	if _fire_t <= 0.0:
		_fire_t = 2.2
		if _can_fire():
			for x in [-6.0, 6.0]:
				game.spawn_enemy("torpedo", {"pos": position + Vector2(x, 14)})
			Audio.play("torpedo")
		_shots_left -= 1
		if _shots_left <= 0:
			_state = 2


func _update_torpedo(dt: float) -> void:
	var p := game.player
	if _t < 1.6 and p.alive:
		_vel.x = move_toward(_vel.x, clampf((p.position.x - position.x) * 2.0, -70.0, 70.0), 160.0 * dt)
	_vel.y = minf(_vel.y + 150.0 * dt, 180.0)
	position += _vel * dt
	if randf() < 0.4:
		game.fx.spark(position + Vector2(0, -7), Tun.C_CYAN, 1) # bubble wake


## SONAR FRIGATE: sonar pings are bullet rings with a gap; an echo ring follows.
func _update_frigate(dt: float) -> void:
	if not _station(dt, float(params.get("y", 70.0)), 36.0):
		return
	_fire_t -= dt
	if _fire_t <= 0.0:
		_fire_t = 2.6
		if _can_fire():
			_ping(0.0)
			_pulse = 0.5 # schedules the echo
			Audio.play("sonar")
		_shots_left -= 1
	if _pulse > 0.0:
		_pulse -= dt
		if _pulse <= 0.0 and _can_fire():
			_ping(PI / 28.0 * 3.0)
	if _shots_left <= 0 and _pulse <= 0.0:
		_state = 2


func _ping(extra: float) -> void:
	var n := 28
	var gap_center := _gun_angle + extra
	_gun_angle += deg_to_rad(40.0)
	for i in n:
		var a := TAU * i / n
		if absf(angle_difference(a, gap_center)) < TAU * 2.6 / n:
			continue # the gap you dodge through
		game.bullets.fire(position, a, 70.0, Tun.B.SONAR)
	game.fx.ring(position, Tun.C_CYAN, 60.0, 0.5, 1.0)


## BARRACUDA (mid-boss submarine): surfaces, fires torpedo salvos and sonar rings, then dives
## (untargetable) and resurfaces elsewhere.
func _update_barracuda(dt: float) -> void:
	_timer += dt
	match _state:
		0: # surfacing
			alpha = minf(1.0, alpha + dt / 1.2)
			if alpha >= 1.0:
				_state = 1
				_timer = 0.0
				targetable = true
				game.fx.ring(position, Tun.C_CYAN, 50.0, 0.5)
				Audio.play("splash")
		1: # attack
			_fire_t -= dt
			if _fire_t <= 0.0:
				_fire_t = 1.6
				if _can_fire():
					for x in [-8.0, 0.0, 8.0]:
						game.spawn_enemy("torpedo", {"pos": position + Vector2(x, 30)})
					Audio.play("torpedo")
			if int(_timer / 1.2) != int((_timer - dt) / 1.2) and _can_fire():
				game.bullets.ring(position, 14, 75.0, Tun.B.SONAR, randf() * TAU)
			if _timer >= 5.5:
				_state = 2
				_timer = 0.0
				targetable = false
				_vel = Vector2(randf_range(60, 210), randf_range(90, 160)) # next surfacing point
				game.fx.ring(position, Tun.C_CYAN, 50.0, 0.5)
				Audio.play("splash")
		2: # diving: fade and move underwater
			alpha = maxf(0.2, alpha - dt / 0.6)
			position = position.move_toward(_vel, 90.0 * dt)
			if _timer >= 2.0 and position.distance_to(_vel) < 1.0:
				_state = 0


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
	mod.a = alpha
	match behaviour:
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
		"prism":
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			if _glow > 0.0:
				draw_circle(Vector2(0, 2), 1.5 + _glow * 3.0, Color(Tun.C_CYAN, 0.4 + _glow * 0.5))
		"equalizer":
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			if _glow > 0.0 and int(_t * 12.0) % 2 == 0:
				for i in 5:
					draw_rect(Rect2((i - 2) * 6.0 - 1.5, 12, 2, 2), Tun.C_PALE)
		"mine":
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			if _state == 1 and int(_t * 16.0) % 2 == 0:
				draw_circle(Vector2.ZERO, 9.0, Color(Tun.C_PINK, 0.5))
		"harpooner":
			if _glow > 0.0 and int(_t * 20.0) % 2 == 0:
				var from := Vector2(0, 12)
				draw_line(from, from + Vector2.from_angle(_gun_angle) * 600.0, Color(Tun.C_PINK, 0.6), 1.0)
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
		"torpedo":
			draw_set_transform(Vector2.ZERO, _vel.angle() - PI / 2.0)
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
			draw_set_transform(Vector2.ZERO)
		"barracuda":
			if _state != 1:
				for i in 3:
					var r := fmod(_t * 20.0 + i * 8.0, 24.0) + 10.0
					draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(Tun.C_CYAN, 0.35 * (1.0 - r / 34.0)), 1.0)
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
		"glitch", "note":
			var bob := Vector2(0, roundf(sin(_t * 8.0)))
			draw_texture(_tex, -_tex.get_size() / 2.0 + bob, mod)
		_:
			draw_texture(_tex, -_tex.get_size() / 2.0, mod)
