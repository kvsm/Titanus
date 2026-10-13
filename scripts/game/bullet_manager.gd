class_name BulletManager
extends Node2D
## Pooled enemy bullets stored in packed arrays and drawn in one pass.
## Collision is circle-vs-point against the player's tiny hitbox.

var game: Game
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var kind := PackedInt32Array()

var _tex: Array[Texture2D] = []
var _half: Array[Vector2] = []


func _ready() -> void:
	for n: String in ["b_pink", "b_orange", "b_big", "b_violet"]:
		var t := Tun.tex(n)
		_tex.append(t)
		_half.append((t.get_size() / 2.0).floor())


func count() -> int:
	return pos.size()


func fire(from: Vector2, angle: float, speed: float, k: int = Tun.B.PINK) -> void:
	pos.append(from)
	vel.append(Vector2.from_angle(angle) * speed)
	kind.append(k)


func fan(from: Vector2, center_angle: float, n: int, spread_deg: float, speed: float, k: int = Tun.B.PINK) -> void:
	if n == 1:
		fire(from, center_angle, speed, k)
		return
	var spread := deg_to_rad(spread_deg)
	for i in n:
		fire(from, center_angle - spread / 2.0 + spread * i / (n - 1), speed, k)


func ring(from: Vector2, n: int, speed: float, k: int = Tun.B.PINK, offset: float = 0.0) -> void:
	for i in n:
		fire(from, offset + TAU * i / n, speed, k)


## Angle from `from` towards the player (straight down if the player is gone).
func aim(from: Vector2) -> float:
	var p := game.player
	if p == null or not p.alive:
		return PI / 2.0
	return (p.position - from).angle()


func update(dt: float) -> void:
	var player := game.player
	var can_hit := player.can_be_hit()
	var pp := player.position
	var i := 0
	while i < pos.size():
		var p := pos[i] + vel[i] * dt
		pos[i] = p
		if p.x < -16 or p.x > Tun.SCREEN.x + 16 or p.y < -16 or p.y > Tun.SCREEN.y + 16:
			_remove(i)
			continue
		if can_hit:
			var r := Tun.BULLET_R[kind[i]] + Tun.PLAYER_HITBOX_R
			if p.distance_squared_to(pp) < r * r:
				_remove(i)
				player.hit()
				can_hit = player.can_be_hit()
				continue
		i += 1
	queue_redraw()


func _remove(i: int) -> void:
	var last := pos.size() - 1
	pos[i] = pos[last]
	vel[i] = vel[last]
	kind[i] = kind[last]
	pos.resize(last)
	vel.resize(last)
	kind.resize(last)


## Cancels bullets within `radius` of `center` (all bullets if radius < 0). Returns how many.
func cancel(center: Vector2, radius: float = -1.0, cash: bool = false) -> int:
	var n := 0
	var i := 0
	while i < pos.size():
		if radius < 0.0 or pos[i].distance_to(center) <= radius:
			game.fx.spark(pos[i], Tun.C_PALE, 2)
			if cash:
				game.fx.popup(pos[i], str(Tun.BULLET_CASH), Tun.C_PALE, 0.5)
			_remove(i)
			n += 1
			continue
		i += 1
	return n


func _draw() -> void:
	for i in pos.size():
		var k := kind[i]
		draw_texture(_tex[k], (pos[i] - _half[k]).round())
