class_name InkPools
extends Node2D
## INKER ink: dark puddles that drift down the screen. While the ship is inside one it moves
## at half speed (Tun.INK_SLOW). Purely a movement hazard: ink never hides bullets.

class Pool:
	var pos: Vector2
	var r := 4.0
	var life := 0.0

var game: Game
var pools: Array[Pool] = []


func spawn(at: Vector2) -> void:
	var p := Pool.new()
	p.pos = at
	pools.append(p)


func clear() -> void:
	pools.clear()


func update(dt: float) -> void:
	var i := 0
	while i < pools.size():
		var p := pools[i]
		p.life += dt
		p.r = minf(Tun.INK_RADIUS, p.r + 60.0 * dt) * (1.0 if p.life < Tun.INK_LIFE - 1.0 else maxf(0.0, Tun.INK_LIFE - p.life))
		p.pos.y += (game.scroll_speed + 22.0) * dt
		if p.life >= Tun.INK_LIFE or p.pos.y - p.r > Tun.SCREEN.y:
			pools.remove_at(i)
			continue
		i += 1
	queue_redraw()


func slows(at: Vector2) -> bool:
	for p in pools:
		if at.distance_squared_to(p.pos) < p.r * p.r:
			return true
	return false


func _draw() -> void:
	for p in pools:
		draw_circle(p.pos.round(), p.r + 1.0, Color(Tun.C_LAVENDER, 0.5))
		draw_circle(p.pos.round(), p.r, Color(0.05, 0.0, 0.12, 0.78))
		# glossy highlights
		draw_circle((p.pos + Vector2(-p.r * 0.35, -p.r * 0.35)).round(), maxf(1.0, p.r * 0.15), Color(Tun.C_GRID, 0.9))
