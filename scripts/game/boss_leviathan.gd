class_name BossLeviathan
extends Boss
## TITAN-02 LEVIATHAN, a mecha-whale (Level 2). Phases:
##   1 FINS  - pectoral fin cannons fire harpoons and fans; the blowhole erupts geysers whose
##             droplets arc up and rain back down under gravity.
##   2 MAW   - (both fins down or 35 s) the jaw opens: the reactor core sprays a sweeping krill
##             stream, geysers continue.
##   3 DIVE  - (core < 40%) it dives (untargetable) and sends tidal walls down 3 of 5 lanes,
##             then surfaces to attack again.

enum { ENTER, FINS, MAW, DIVE, DYING, DONE }

const BODY_HALF := Vector2(34, 66)
const BLOWHOLE := Vector2(0, 21)
const CORE_OFFSET := Vector2(0, 61)
const JAW_TOP := 48.0
const FIN_OFFSET := Vector2(52, 9)
const FIN_MUZZLE := Vector2(62, 26)
const LANES := 5

var state := ENTER
var fin_l: Boss.Part
var fin_r: Boss.Part
var core: Boss.Part

var _t := 0.0
var _phase_t := 0.0
var _jaw_open := 0.0
var _alpha := 1.0
var _fin_t := 1.2
var _fin_turn := 0
var _aim_l := PI / 2.0
var _aim_r := PI / 2.0
var _telegraph_l := 0.0
var _telegraph_r := 0.0
var _geyser_t := 2.5
var _krill_t := 0.0
var _krill_a := 0.0
var _dive_t := 0.0
var _dive_step := 0
var _lanes: Array[int] = []
var _wall_t := 0.0
var _die_t := 0.0
var _boom_t := 0.0

var _body_tex: Texture2D
var _jaw_tex: Texture2D
var _fin_tex: Texture2D
var _core_tex: Texture2D


func setup(g: Game) -> void:
	super.setup(g)
	_body_tex = Tun.tex("leviathan_body")
	_jaw_tex = Tun.tex("leviathan_jaw")
	_fin_tex = Tun.tex("leviathan_fin")
	_core_tex = Tun.tex("leviathan_core")
	position = Vector2(Tun.SCREEN.x / 2.0, -90)
	fin_l = make_part("fin_l", Tun.LEVIATHAN_FIN_HP, Vector2(14, 14), Vector2(-FIN_OFFSET.x, FIN_OFFSET.y), Tun.BOSS_PART_BONUS)
	fin_r = make_part("fin_r", Tun.LEVIATHAN_FIN_HP, Vector2(14, 14), FIN_OFFSET, Tun.BOSS_PART_BONUS)
	core = make_part("core", Tun.LEVIATHAN_CORE_HP, Vector2(12, 12), CORE_OFFSET, Tun.BOSS_KILL_BONUS)
	Audio.play("whale")


func is_done() -> bool:
	return state == DONE


func blocks(p: Vector2) -> bool:
	if state == ENTER or state == DONE or _alpha < 0.6:
		return false
	var d := p - position
	# the head armour shields the mouth until the jaw opens
	if core.targetable and absf(d.x) < 16.0 and d.y > JAW_TOP:
		return false
	return absf(d.x) < BODY_HALF.x and absf(d.y) < BODY_HALF.y


func touches_player(p: Vector2) -> bool:
	if state == DONE or _alpha < 0.6:
		return false
	var d := p - position
	return absf(d.x) < BODY_HALF.x - 6 and absf(d.y) < BODY_HALF.y - 4


func update(dt: float) -> void:
	_t += dt
	_phase_t += dt
	tick_flash(dt)
	match state:
		ENTER:
			position.y = move_toward(position.y, 95.0, 40.0 * dt)
			if position.y >= 95.0:
				_set_state(FINS)
				fin_l.targetable = true
				fin_r.targetable = true
		FINS:
			_sway()
			_fins(dt, 1.3)
			_geyser(dt, 4.0)
			if (fin_l.dead and fin_r.dead) or _phase_t > Tun.LEVIATHAN_PHASE2_TIME:
				_set_state(MAW)
				Audio.play("whale")
		MAW:
			_sway()
			_open_jaw(dt)
			_fins(dt, 2.6)
			_geyser(dt, 3.2)
			if core.targetable:
				_krill(dt)
			if core.hp < Tun.LEVIATHAN_CORE_HP * Tun.LEVIATHAN_PHASE3_FRACTION:
				_set_state(DIVE)
				_dive_step = 0
				_dive_t = 0.0
				Audio.play("whale")
		DIVE:
			_dive(dt)
		DYING:
			_dying(dt)
	queue_redraw()


func _set_state(s: int) -> void:
	state = s
	_phase_t = 0.0


func _sway() -> void:
	position.x = Tun.SCREEN.x / 2.0 + sin(_t * 0.45) * 18.0


func _open_jaw(dt: float) -> void:
	_jaw_open = minf(1.0, _jaw_open + dt)
	if _jaw_open > 0.6 and not core.targetable and state != DIVE:
		core.targetable = true


func _bs() -> float:
	return Tun.LEVIATHAN_BULLET_SPEED


## Fin cannons alternate: a telegraphed harpoon plus a 3-way fan.
func _fins(dt: float, interval: float) -> void:
	# a harpoon flies when its telegraph runs out
	if _telegraph_l > 0.0:
		_telegraph_l -= dt
		if _telegraph_l <= 0.0:
			_fire_harpoon(true)
	if _telegraph_r > 0.0:
		_telegraph_r -= dt
		if _telegraph_r <= 0.0:
			_fire_harpoon(false)
	_fin_t -= dt
	if _fin_t > 0.0:
		return
	_fin_t = interval / 2.0
	_fin_turn += 1
	var left := _fin_turn % 2 == 0
	var fin := fin_l if left else fin_r
	if fin.dead or not game.player.alive:
		return
	var muzzle := position + Vector2(-FIN_MUZZLE.x if left else FIN_MUZZLE.x, FIN_MUZZLE.y)
	var aim := game.bullets.aim(muzzle)
	if left:
		_aim_l = aim
		_telegraph_l = 0.45
	else:
		_aim_r = aim
		_telegraph_r = 0.45
	game.bullets.fan(muzzle, aim + PI / 7.0, 3, 24.0, 90.0 * _bs(), Tun.B.ORANGE)
	game.bullets.fan(muzzle, aim - PI / 7.0, 3, 24.0, 90.0 * _bs(), Tun.B.ORANGE)
	Audio.play("enemy_shot")


func _fire_harpoon(left: bool) -> void:
	if state == DYING or state == DONE:
		return
	var fin := fin_l if left else fin_r
	if fin.dead:
		return
	var muzzle := position + Vector2(-FIN_MUZZLE.x if left else FIN_MUZZLE.x, FIN_MUZZLE.y)
	game.bullets.fire(muzzle, _aim_l if left else _aim_r, 250.0 * _bs(), Tun.B.HARPOON)
	Audio.play("harpoon")


## Blowhole geyser: droplets launched upwards that arc over and rain down.
func _geyser(dt: float, interval: float) -> void:
	_geyser_t -= dt
	if _geyser_t > 0.0:
		return
	_geyser_t = interval
	var src := position + BLOWHOLE
	for i in 14:
		var a := deg_to_rad(-90.0 + randf_range(-38.0, 38.0))
		game.bullets.fire(src, a, randf_range(150.0, 230.0) * _bs(), Tun.B.GEYSER)
	game.fx.ring(src, Tun.C_MINT, 30.0, 0.4)
	Audio.play("geyser")


## Krill stream: a sweeping two-stream spray from the open mouth.
func _krill(dt: float) -> void:
	_krill_t -= dt
	while _krill_t <= 0.0:
		_krill_t += 0.11
		_krill_a += 0.16
		var base := PI / 2.0 + sin(_krill_a * 0.5) * 0.9
		var c := core.global_position
		game.bullets.fire(c, base - 0.12, 95.0 * _bs(), Tun.B.PINK)
		game.bullets.fire(c, base + 0.12, 95.0 * _bs(), Tun.B.PINK)


## Dive cycle: submerge -> telegraph 3 lanes -> tidal walls -> surface -> attack -> repeat.
func _dive(dt: float) -> void:
	_dive_t += dt
	match _dive_step:
		0: # submerge
			_alpha = maxf(0.15, _alpha - dt / 0.8)
			core.targetable = false
			if _dive_t >= 1.0:
				_next_dive_step()
				_lanes.clear()
				var order := range(LANES)
				order.shuffle()
				for k in 3:
					_lanes.append(order[k])
				Audio.play("telegraph")
		1: # lane warning
			if _dive_t >= 1.0:
				_next_dive_step()
				game.shake(3.0)
				Audio.play("splash")
		2: # tidal walls rush down the chosen lanes
			_wall_t -= dt
			if _wall_t <= 0.0:
				_wall_t = 0.12
				var lw := Tun.SCREEN.x / LANES
				for lane in _lanes:
					for j in 5:
						var x := lane * lw + 5.0 + j * (lw - 10.0) / 4.0
						game.bullets.fire(Vector2(x, -6), PI / 2.0, 210.0 * _bs(), Tun.B.SONAR)
			if _dive_t >= 0.9:
				_next_dive_step()
				position.x = randf_range(100.0, 170.0)
		3: # surface
			_alpha = minf(1.0, _alpha + dt / 0.8)
			if _alpha >= 1.0:
				core.targetable = true
				_next_dive_step()
				game.fx.ring(position + CORE_OFFSET, Tun.C_CYAN, 60.0, 0.5)
				Audio.play("whale")
		4: # attack while surfaced
			_krill(dt)
			_geyser(dt, 2.0)
			_fins(dt, 2.6)
			if _dive_t >= 4.0:
				_dive_step = 0
				_dive_t = 0.0


func _next_dive_step() -> void:
	_dive_step += 1
	_dive_t = 0.0


func on_part_destroyed(part: Boss.Part) -> void:
	part.targetable = false
	game.on_boss_part_destroyed(part, part.score_base)
	if part == core:
		state = DYING
		_alpha = 1.0
		_die_t = 0.0
		game.on_boss_dying()
		Audio.play("whale")


func _dying(dt: float) -> void:
	_die_t += dt
	_boom_t -= dt
	position.y += 8.0 * dt
	if _boom_t <= 0.0:
		_boom_t = 0.09
		game.fx.explode(position + Vector2(randf_range(-40, 40), randf_range(-60, 60)), 2)
		Audio.play("explode_small")
		game.shake(2.0)
	if _die_t >= 2.8:
		state = DONE
		game.fx.explode(position, 4)
		game.fx.explode(position + Vector2(0, 50), 4)
		game.fx.flash(0.8)
		Audio.play("explode_big")
		game.shake(8.0)
		game.on_boss_defeated()


func _draw() -> void:
	if state == DONE:
		return
	# lane warnings are drawn in screen space
	if state == DIVE and _dive_step == 1 and int(_t * 10.0) % 2 == 0:
		var lw := Tun.SCREEN.x / LANES
		for lane in _lanes:
			var r := Rect2(lane * lw, Tun.HUD_TOP, lw, Tun.SCREEN.y - Tun.HUD_TOP)
			r.position -= position
			draw_rect(r, Color(Tun.C_CYAN, 0.18))
			draw_rect(r, Color(Tun.C_CYAN, 0.6), false, 1.0)
	var white := Color(6, 6, 6)
	var base := Color(1, 1, 1, _alpha)
	# harpoon telegraph lines
	for side in [-1, 1]:
		var tel := _telegraph_l if side < 0 else _telegraph_r
		if tel > 0.0 and int(_t * 20.0) % 2 == 0:
			var m := Vector2(FIN_MUZZLE.x * side, FIN_MUZZLE.y)
			draw_line(m, m + Vector2.from_angle(_aim_l if side < 0 else _aim_r) * 600.0, Color(Tun.C_PINK, 0.6), 1.0)
	# fins (behind the body)
	for fin: Boss.Part in [fin_l, fin_r]:
		var right := fin == fin_r
		if fin.dead:
			draw_rect(Rect2((32 if right else -40), 0, 8, 10), Color(Tun.C_CHROME_D, _alpha))
			continue
		var mod := white if fin.flash > 0.0 else base
		if right:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture(_fin_tex, Vector2(-36 - _fin_tex.get_width(), -10), mod)
		draw_set_transform(Vector2.ZERO)
	draw_texture(_body_tex, -_body_tex.get_size() / 2.0, base)
	# core behind the jaw
	if _jaw_open > 0.0 and not core.dead:
		var cm := white if core.flash > 0.0 else base
		var pulse := 1.0 + 0.08 * sin(_t * 8.0)
		draw_set_transform(CORE_OFFSET, 0.0, Vector2(pulse, pulse))
		draw_texture(_core_tex, -_core_tex.get_size() / 2.0, cm)
		draw_set_transform(Vector2.ZERO)
	# jaw plates slide apart
	var slide := _jaw_open * 14.0
	var jw := _jaw_tex.get_width()
	draw_texture(_jaw_tex, Vector2(-jw - slide + 1, JAW_TOP), base)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture(_jaw_tex, Vector2(-jw - slide + 1, JAW_TOP), base)
	draw_set_transform(Vector2.ZERO)
	# blowhole spray glow
	if _geyser_t > 3.5 or (state == DIVE and _dive_step == 4 and _geyser_t > 1.6):
		draw_circle(BLOWHOLE, 4.0, Color(Tun.C_MINT, 0.6))
