class_name Fx
extends Node2D
## Pixel-shard explosions, rings, sparks, score popups and screen flashes.

class Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var color: Color
	var size: float

class Ring:
	var pos: Vector2
	var r: float
	var speed: float
	var life: float
	var max_life: float
	var color: Color
	var width: float

class ScorePopup:
	var pos: Vector2
	var text: String
	var color: Color
	var life: float

const SHARD_COLORS := [Color("ffffff"), Color("fffb96"), Color("ffd319"), Color("ff6c11"), Color("ff2a6d"), Color("f222ff")]
const MAX_PARTICLES := 700
const MAX_POPUPS := 40

var particles: Array[Particle] = []
var rings: Array[Ring] = []
var popups: Array[ScorePopup] = []
var _flash := 0.0


func explode(at: Vector2, size: int = 1) -> void:
	var n: int = [6, 14, 26, 40, 70][clampi(size, 0, 4)]
	var spd: float = [50.0, 80.0, 110.0, 140.0, 180.0][clampi(size, 0, 4)]
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			break
		var p := Particle.new()
		p.pos = at
		p.vel = Vector2.from_angle(randf() * TAU) * randf_range(0.2, 1.0) * spd
		p.max_life = randf_range(0.25, 0.6) + size * 0.08
		p.life = p.max_life
		p.color = SHARD_COLORS[randi() % SHARD_COLORS.size()]
		p.size = float(1 + randi() % (2 if size < 2 else 3))
		particles.append(p)
	ring(at, Tun.C_PALE, 12.0 + size * 14.0, 0.25 + size * 0.05)


func spark(at: Vector2, color: Color, n: int = 2) -> void:
	for i in n:
		if particles.size() >= MAX_PARTICLES:
			return
		var p := Particle.new()
		p.pos = at
		p.vel = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
		p.max_life = randf_range(0.08, 0.2)
		p.life = p.max_life
		p.color = color
		p.size = 1.0
		particles.append(p)


func ring(at: Vector2, color: Color, radius: float, duration: float, width: float = 2.0) -> void:
	var r := Ring.new()
	r.pos = at
	r.r = 2.0
	r.speed = radius / duration
	r.life = duration
	r.max_life = duration
	r.color = color
	r.width = width
	rings.append(r)


func popup(at: Vector2, text: String, color: Color, life: float = 0.8) -> void:
	if popups.size() >= MAX_POPUPS:
		popups.remove_at(0)
	var p := ScorePopup.new()
	p.pos = at
	p.text = text
	p.color = color
	p.life = life
	popups.append(p)


func flash(strength: float) -> void:
	_flash = maxf(_flash, strength)


func update(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt * 1.5)
	var i := 0
	while i < particles.size():
		var p := particles[i]
		p.life -= dt
		if p.life <= 0.0:
			particles.remove_at(i)
			continue
		p.pos += p.vel * dt
		p.vel *= 1.0 - 2.5 * dt
		i += 1
	i = 0
	while i < rings.size():
		var r := rings[i]
		r.life -= dt
		if r.life <= 0.0:
			rings.remove_at(i)
			continue
		r.r += r.speed * dt
		i += 1
	i = 0
	while i < popups.size():
		var p := popups[i]
		p.life -= dt
		if p.life <= 0.0:
			popups.remove_at(i)
			continue
		p.pos.y -= 18.0 * dt
		i += 1
	queue_redraw()


func _draw() -> void:
	for r in rings:
		draw_arc(r.pos, r.r, 0.0, TAU, 32, Color(r.color, r.life / r.max_life), r.width)
	for p in particles:
		var c := p.color
		if p.life < p.max_life * 0.4:
			c = Tun.C_PINK if c.v > 0.8 else Tun.C_GRID
		draw_rect(Rect2(p.pos.round(), Vector2(p.size, p.size)), c)
	for p in popups:
		if p.life > 0.15 or int(p.life * 40.0) % 2 == 0:
			PixelFont.draw(self, p.text, p.pos, p.color, 1, PixelFont.CENTER)
	if _flash > 0.0:
		draw_rect(Rect2(-20, -20, Tun.SCREEN.x + 40, Tun.SCREEN.y + 40), Color(1, 1, 1, minf(1.0, _flash)))
