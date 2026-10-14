class_name Boss
extends Node2D
## Shared plumbing for the Titans (HELIOS, LEVIATHAN): damageable parts, HUD hooks, collision.

## A damageable piece of a boss (arm, fin, core...). Reports its destruction to the boss.
class Part extends Target:
	var boss: Boss
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

var game: Game
var all_parts: Array[Part] = []


func setup(g: Game) -> void:
	game = g


func make_part(n: String, part_hp: float, half: Vector2, offset: Vector2, bonus: int) -> Part:
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
	p.targetable = false
	add_child(p)
	all_parts.append(p)
	return p


## Parts the player can currently damage.
func parts() -> Array[Target]:
	var out: Array[Target] = []
	for p in all_parts:
		if not p.dead and p.targetable:
			out.append(p)
	return out


func hp_fraction() -> float:
	var total := 0.0
	var cur := 0.0
	for p in all_parts:
		total += p.max_hp
		cur += p.hp
	return 0.0 if total <= 0.0 else clampf(cur / total, 0.0, 1.0)


func tick_flash(dt: float) -> void:
	for p in all_parts:
		p.flash = maxf(0.0, p.flash - dt)


# --- overridden by each Titan
func update(_dt: float) -> void:
	pass


func is_done() -> bool:
	return false


## True if a player shot at `p` hits armour (and is absorbed).
func blocks(_p: Vector2) -> bool:
	return false


func touches_player(_p: Vector2) -> bool:
	return false


func on_part_destroyed(_part: Part) -> void:
	pass
