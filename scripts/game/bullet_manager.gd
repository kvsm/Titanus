class_name BulletManager
extends Node2D
## Pooled enemy bullets stored in packed arrays and drawn in one pass.
## Collision is circle-vs-point against the player's tiny hitbox.

var game: Game
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var kind := PackedInt32Array()
var age := PackedFloat32Array()

var _tex: Array[Texture2D] = []
var _half: Array[Vector2] = []


func _ready() -> void:
	for n: String in ["b_pink", "b_orange", "b_big", "b_violet", "b_prism", "b_harpoon", "b_link", "b_geyser", "b_sonar"]:
		var t := Tun.tex(n)
		_tex.append(t)
		_half.append((t.get_size() / 2.0).floor())


func count() -> int:
	return pos.size()


func fire(from: Vector2, angle: float, speed: float, k: int = Tun.B.PINK) -> void:
	pos.append(from)
	vel.append(Vector2.from_angle(angle) * speed)
	kind.append(k)
	age.append(0.0)


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
	var splits: Array[Vector2] = []
	var links: Array[Vector2] = []
	var i := 0
	while i < pos.size():
		var k := kind[i]
		if k == Tun.B.GEYSER:
			var v := vel[i]
			v.y += Tun.GEYSER_GRAVITY * dt
			vel[i] = v
		var p := pos[i] + vel[i] * dt
		pos[i] = p
		var before := age[i]
		age[i] += dt
		if k == Tun.B.SHARD and age[i] >= Tun.SPLIT_TIME:
			# PRISM shard bursts into a ring of small bullets
			splits.append(p)
			_remove(i)
			continue
		if k == Tun.B.HARPOON and int(age[i] / Tun.LINK_SPACING) != int(before / Tun.LINK_SPACING):
			links.append(p) # harpoons leave a chain hanging in their wake
		if k == Tun.B.LINK and age[i] >= Tun.LINK_LIFE:
			_remove(i)
			continue
		var top := -240.0 if k == Tun.B.GEYSER else -16.0 # geyser droplets arc up and fall back
		if p.x < -16 or p.x > Tun.SCREEN.x + 16 or p.y < top or p.y > Tun.SCREEN.y + 16:
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
	for s in splits:
		game.fx.spark(s, Tun.C_CYAN, 3)
		ring(s, 6, 70.0, Tun.B.VIOLET, randf() * TAU)
	for l in links:
		fire(l, 0.0, 0.0, Tun.B.LINK)
	queue_redraw()


func _remove(i: int) -> void:
	var last := pos.size() - 1
	pos[i] = pos[last]
	vel[i] = vel[last]
	kind[i] = kind[last]
	age[i] = age[last]
	pos.resize(last)
	vel.resize(last)
	kind.resize(last)
	age.resize(last)


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
		if k == Tun.B.HARPOON:
			draw_set_transform(pos[i].round(), vel[i].angle() - PI / 2.0)
			draw_texture(_tex[k], -_half[k])
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture(_tex[k], (pos[i] - _half[k]).round())
