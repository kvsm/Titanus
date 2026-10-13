class_name PlayerShots
extends Node2D
## Vulcan bullets (single hit) and Wave crescents (piercing, each target hit once).
## The Laser is a continuous beam handled by Player.

class Shot:
	var pos: Vector2
	var vel: Vector2
	var dmg: float
	var wave_level := 0 # 0 = vulcan, 1..4 = wave crescent
	var half := Vector2(1.5, 4)
	var hits := {}

var game: Game
var shots: Array[Shot] = []

var _vulcan_tex: Texture2D
var _wave_tex: Array[Texture2D] = []


func _ready() -> void:
	_vulcan_tex = Tun.tex("shot_vulcan")
	for l in range(1, 5):
		_wave_tex.append(Tun.tex("shot_wave_%d" % l))


func clear() -> void:
	shots.clear()


func fire_vulcan(from: Vector2, angle_deg: float, dmg: float) -> void:
	var s := Shot.new()
	s.pos = from
	s.vel = Vector2.UP.rotated(deg_to_rad(angle_deg)) * Tun.VULCAN_SPEED
	s.dmg = dmg
	shots.append(s)


func fire_wave(from: Vector2, angle_deg: float, dmg: float, level: int) -> void:
	var s := Shot.new()
	s.pos = from
	s.vel = Vector2.UP.rotated(deg_to_rad(angle_deg)) * Tun.WAVE_SPEED
	s.dmg = dmg
	s.wave_level = level
	s.half = Vector2(_wave_tex[level - 1].get_width() / 2.0, 3)
	shots.append(s)


func update(dt: float, targets: Array[Target]) -> void:
	var i := 0
	while i < shots.size():
		var s := shots[i]
		s.pos += s.vel * dt
		if s.pos.y < -12 or s.pos.x < -20 or s.pos.x > Tun.SCREEN.x + 20:
			shots.remove_at(i)
			continue
		var consumed := false
		if s.wave_level == 0:
			for t in targets:
				if not t.dead and t.hit_test(s.pos, 2.0):
					t.take_damage(s.dmg)
					game.fx.spark(s.pos + Vector2(0, -2), Tun.C_PALE, 2)
					consumed = true
					break
			if not consumed and game.blocks_shot(s.pos):
				game.fx.spark(s.pos, Tun.C_CHROME_L, 2)
				consumed = true
		else:
			for t in targets:
				var id := t.get_instance_id()
				if not t.dead and not s.hits.has(id) and t.hit_rect(s.pos, s.half):
					s.hits[id] = true
					t.take_damage(s.dmg)
					game.fx.spark(t.global_position.lerp(s.pos, 0.5), Tun.C_MINT, 2)
		if consumed:
			shots.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	for s in shots:
		if s.wave_level == 0:
			draw_texture(_vulcan_tex, (s.pos - Vector2(1, 4)).round())
		else:
			var t := _wave_tex[s.wave_level - 1]
			draw_texture(t, (s.pos - t.get_size() / 2.0).round())
