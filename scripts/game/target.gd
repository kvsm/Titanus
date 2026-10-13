class_name Target
extends Node2D
## Anything the player's weapons can damage: enemies and boss parts.
## Hitboxes are axis-aligned rectangles (half extents) around global_position.

var game: Game
var hp := 1.0
var max_hp := 1.0
var hit_half := Vector2(6, 6)
var targetable := true
var dead := false
var flash := 0.0
var is_boss_part := false


func hit_test(p: Vector2, r: float) -> bool:
	var g := global_position
	return absf(p.x - g.x) <= hit_half.x + r and absf(p.y - g.y) <= hit_half.y + r


func hit_rect(c: Vector2, half: Vector2) -> bool:
	var g := global_position
	return absf(c.x - g.x) <= hit_half.x + half.x and absf(c.y - g.y) <= hit_half.y + half.y


## Laser beam: a vertical column of half width `half_w` from the top of the screen down to `y_bottom`.
func in_column(x: float, half_w: float, y_bottom: float) -> bool:
	var g := global_position
	return absf(x - g.x) <= hit_half.x + half_w and g.y - hit_half.y < y_bottom


func is_on_screen() -> bool:
	var g := global_position
	return g.x + hit_half.x > 0 and g.x - hit_half.x < Tun.SCREEN.x \
		and g.y + hit_half.y > 0 and g.y - hit_half.y < Tun.SCREEN.y


func take_damage(_amount: float) -> void:
	pass
