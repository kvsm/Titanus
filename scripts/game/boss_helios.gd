class_name BossHelios
extends Node2D
## TITAN-01 HELIOS (§9). Three phases: Arms -> Sun Core -> Supernova.

class Part extends Target:
	var boss: BossHelios
	var part_name := ""
	var score_base := 0

	func take_damage(amount: float) -> void:
		if dead or not targetable:
			return
		hp -= amount
		flash = 0.05
		Audio.play("hit", -10.0)
		if hp <= 0.0:
			hp = 0.0
			dead = true
			boss.on_part_destroyed(self)

enum { ENTER, ARMS, CORE, SUPERNOVA, DYING, DONE }

const BODY_HALF := Vector2(40, 34)
const ARM_OFFSET := Vector2(52, 14)
const CORE_OFFSET := Vector2(0, -1)
const POD_OFFSET := Vector2(46, -21)

var game: Game
var state := ENTER
var arm_l: Part
var arm_r: Part
var core: Part

var _t := 0.0
var _phase_t := 0.0
var _plates_open := 0.0
var _arm_turn := 0
var _arm_t := 1.5
var _pod_t := 3.0
var _pod_side := 1
var _spiral_t := 0.0
var _spiral_a := 0.0
var _volley_t := 2.0
var _cycle_t := 0.0
var _sweep_dir := 1.0
var _beam_angle := 0.0
var _beam_state := 0 # 0 none, 1 telegraph, 2 firing
var _ring_t := 0.0
var _rain_t := 0.0
var _die_t := 0.0
var _boom_t := 0.0

var _body_tex: Texture2D
var _plate_tex: Texture2D
var _arm_tex: Texture2D
var _core_tex: Texture2D


func setup(g: Game) -> void:
	game = g
	_body_tex = Tun.tex("helios_body")
	_plate_tex = Tun.tex("helios_plate")
	_arm_tex = Tun.tex("helios_arm")
	_core_tex = Tun.tex("helios_core")
	position = Vector2(Tun.SCREEN.x / 2.0, -70)
	arm_l = _make_part("arm_l", Tun.HELIOS_ARM_HP, Vector2(11, 22), Vector2(-ARM_OFFSET.x, ARM_OFFSET.y), Tun.BOSS_PART_BONUS)
	arm_r = _make_part("arm_r", Tun.HELIOS_ARM_HP, Vector2(11, 22), ARM_OFFSET, Tun.BOSS_PART_BONUS)
	core = _make_part("core", Tun.HELIOS_CORE_HP, Vector2(13, 13), CORE_OFFSET, Tun.BOSS_KILL_BONUS)
	for p: Part in [arm_l, arm_r, core]:
		p.targetable = false


func _make_part(n: String, part_hp: float, half: Vector2, offset: Vector2, bonus: int) -> Part:
	var p := Part.new()
	p.boss = self
	p.game = game
	p.part_name = n
	p.hp = part_hp
	p.max_hp = part_hp
	p.hit_half = half
	p.position = offset
	p.score_base = bonus
	p.is_boss_part = true
	add_child(p)
	return p


func parts() -> Array[Target]:
	var out: Array[Target] = []
	for p: Part in [arm_l, arm_r, core]:
		if not p.dead and p.targetable:
			out.append(p)
	return out


func hp_fraction() -> float:
	var total := Tun.HELIOS_ARM_HP * 2.0 + Tun.HELIOS_CORE_HP
	var cur := arm_l.hp + arm_r.hp + core.hp
	return clampf(cur / total, 0.0, 1.0)


## True if a player shot at `p` hits armour (and is absorbed).
## Once the chest is open the armour stops absorbing shots: they travel up the screen,
## so the waist would otherwise shield the core from non-piercing weapons (Vulcan).
func blocks(p: Vector2) -> bool:
	if state == ENTER or state == DONE or core.targetable:
		return false
	var d := p - position
	return absf(d.x) < BODY_HALF.x and d.y > -BODY_HALF.y - 8 and d.y < BODY_HALF.y


func touches_player(p: Vector2) -> bool:
	if state == DONE:
		return false
	var d := p - position
	return absf(d.x) < BODY_HALF.x - 4 and absf(d.y) < BODY_HALF.y


func update(dt: float) -> void:
	_t += dt
	_phase_t += dt
	for p: Part in [arm_l, arm_r, core]:
		p.flash = maxf(0.0, p.flash - dt)
	match state:
		ENTER:
			position.y = move_toward(position.y, 104.0, 45.0 * dt)
			if position.y >= 104.0:
				_set_state(ARMS)
				arm_l.targetable = true
				arm_r.targetable = true
		ARMS:
			_sway()
			_fire_arms(dt, 1.4)
			_launch_notes(dt)
			if (arm_l.dead and arm_r.dead) or _phase_t > Tun.HELIOS_PHASE2_TIME:
				_set_state(CORE)
		CORE:
			_sway()
			_open_plates(dt)
			_fire_arms(dt, 2.8)
			if core.targetable:
				_spiral(dt, 0.09, 80.0)
				_volley(dt)
			if core.hp < Tun.HELIOS_CORE_HP * Tun.HELIOS_PHASE3_FRACTION:
				_set_state(SUPERNOVA)
				game.shake(4.0)
		SUPERNOVA:
			_sway()
			_open_plates(dt)
			_fire_arms(dt, 3.0)
			_supernova(dt)
		DYING:
			_dying(dt)
	queue_redraw()


func _set_state(s: int) -> void:
	state = s
	_phase_t = 0.0
	_cycle_t = 0.0
	_beam_state = 0


func _sway() -> void:
	position.x = Tun.SCREEN.x / 2.0 + sin(_t * 0.5) * 22.0


func _open_plates(dt: float) -> void:
	_plates_open = minf(1.0, _plates_open + dt)
	if _plates_open > 0.6 and not core.targetable:
		core.targetable = true


func _fire_arms(dt: float, interval: float) -> void:
	_arm_t -= dt
	if _arm_t > 0.0:
		return
	_arm_t = interval / 2.0
	_arm_turn += 1
	var arm := arm_l if _arm_turn % 2 == 0 else arm_r
	if arm.dead or not game.player.alive:
		return
	var muzzle := arm.global_position + Vector2(0, 26)
	game.bullets.fan(muzzle, game.bullets.aim(muzzle), 5, 40.0, 95.0 * Tun.HELIOS_BULLET_SPEED, Tun.B.ORANGE)
	Audio.play("enemy_shot")


func _launch_notes(dt: float) -> void:
	_pod_t -= dt
	if _pod_t > 0.0:
		return
	_pod_t = 3.2
	_pod_side = -_pod_side
	game.spawn_enemy("note", {"pos": position + Vector2(POD_OFFSET.x * _pod_side, POD_OFFSET.y)})


func _spiral(dt: float, interval: float, speed: float) -> void:
	_spiral_t -= dt
	while _spiral_t <= 0.0:
		_spiral_t += interval
		_spiral_a += 0.23
		var c := core.global_position
		game.bullets.fire(c, _spiral_a, speed * Tun.HELIOS_BULLET_SPEED, Tun.B.PINK)
		game.bullets.fire(c, _spiral_a + PI, speed * Tun.HELIOS_BULLET_SPEED, Tun.B.PINK)


func _volley(dt: float) -> void:
	_volley_t -= dt
	if _volley_t <= 0.0:
		_volley_t = 2.0
		var c := core.global_position
		game.bullets.fan(c, game.bullets.aim(c), 3, 16.0, 110.0 * Tun.HELIOS_BULLET_SPEED, Tun.B.BIG)


func _supernova(dt: float) -> void:
	# 7 s cycle: telegraph (1 s), beam sweep (2.4 s), then ring bursts + bullet rain.
	_cycle_t += dt
	var c := core.global_position
	var a0 := deg_to_rad(90.0 - 55.0 * _sweep_dir)
	var a1 := deg_to_rad(90.0 + 55.0 * _sweep_dir)
	if _cycle_t < 1.0:
		if _beam_state != 1:
			_beam_state = 1
			Audio.play("telegraph")
		_beam_angle = a0
	elif _cycle_t < 3.4:
		if _beam_state != 2:
			_beam_state = 2
			Audio.play("beam")
			game.shake(2.0)
		_beam_angle = lerpf(a0, a1, (_cycle_t - 1.0) / 2.4)
		_check_beam(c)
	else:
		_beam_state = 0
		_ring_t -= dt
		if _ring_t <= 0.0:
			_ring_t = 0.8
			game.bullets.ring(c, 18, 85.0 * Tun.HELIOS_BULLET_SPEED, Tun.B.VIOLET, randf() * TAU)
			Audio.play("enemy_shot")
		_rain_t -= dt
		if _rain_t <= 0.0:
			_rain_t = 0.14
			game.bullets.fire(Vector2(randf_range(8, Tun.SCREEN.x - 8), -4), PI / 2.0 + randf_range(-0.1, 0.1), 110.0 * Tun.HELIOS_BULLET_SPEED, Tun.B.PINK)
		_spiral(dt, 0.16, 70.0)
	if _cycle_t >= 7.0:
		_cycle_t = 0.0
		_sweep_dir = -_sweep_dir


func _check_beam(origin: Vector2) -> void:
	var p := game.player
	if not p.can_be_hit():
		return
	var dir := Vector2.from_angle(_beam_angle)
	var rel := p.position - origin
	var along := rel.dot(dir)
	if along < 0.0:
		return
	var dist := absf(rel.cross(dir))
	if dist < 7.0 + Tun.PLAYER_HITBOX_R:
		p.hit()


func on_part_destroyed(part: Part) -> void:
	part.targetable = false
	game.on_boss_part_destroyed(part, part.score_base)
	if part == core:
		state = DYING
		_die_t = 0.0
		_beam_state = 0
		game.on_boss_dying()


func _dying(dt: float) -> void:
	_die_t += dt
	_boom_t -= dt
	position.y += 6.0 * dt
	if _boom_t <= 0.0:
		_boom_t = 0.09
		var off := Vector2(randf_range(-55, 55), randf_range(-40, 40))
		game.fx.explode(position + off, 2)
		Audio.play("explode_small")
		game.shake(2.0)
	if _die_t >= 2.6:
		state = DONE
		game.fx.explode(position, 4)
		game.fx.flash(0.8)
		Audio.play("explode_big")
		game.shake(8.0)
		game.on_boss_defeated()


func _draw() -> void:
	if state == DONE:
		return
	var white := Color(6, 6, 6)
	# beam telegraph / beam
	if _beam_state != 0:
		var c := CORE_OFFSET
		var end := c + Vector2.from_angle(_beam_angle) * 700.0
		if _beam_state == 1:
			if int(_t * 20.0) % 2 == 0:
				draw_line(c, end, Color(Tun.C_PALE, 0.8), 1.0)
		else:
			var j := 1.0 if int(_t * 40.0) % 2 == 0 else 0.0
			draw_line(c, end, Color(Tun.C_ORANGE, 0.5), 18.0 + j * 2.0)
			draw_line(c, end, Tun.C_YELLOW, 12.0)
			draw_line(c, end, Tun.C_WHITE, 5.0 + j)
	var bt := _body_tex
	draw_texture(bt, -bt.get_size() / 2.0)
	# core (visible once the plates open)
	if _plates_open > 0.0:
		var core_mod := white if core.flash > 0.0 else Color.WHITE
		if state == SUPERNOVA and int(_t * 10.0) % 2 == 0:
			core_mod = Color(1.6, 1.3, 1.3)
		if not core.dead:
			draw_texture(_core_tex, CORE_OFFSET - _core_tex.get_size() / 2.0, core_mod)
	# chest plates slide apart
	var slide := _plates_open * 15.0
	var pt := _plate_tex
	var plate_y := -21.0
	draw_texture(pt, Vector2(-pt.get_width() - slide + 1, plate_y))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture(pt, Vector2(-pt.get_width() - slide + 1, plate_y))
	draw_set_transform(Vector2.ZERO)
	# arms
	for arm: Part in [arm_l, arm_r]:
		var mirror := arm == arm_r
		var mod := white if arm.flash > 0.0 else Color.WHITE
		var o := arm.position
		if arm.dead:
			# broken stump: sparks
			if randf() < 0.3:
				game.fx.spark(global_position + o + Vector2(randf_range(-6, 6), -10), Tun.C_ORANGE, 1)
			draw_rect(Rect2(o.x - 6, o.y - 22, 12, 8), Tun.C_CHROME_D)
			continue
		if mirror:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
			o.x = -o.x
		draw_texture(_arm_tex, o - _arm_tex.get_size() / 2.0, mod)
		draw_set_transform(Vector2.ZERO)
