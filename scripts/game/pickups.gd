class_name Pickups
extends Node2D
## Weapon capsules (cycling colour), shield cells and bombs (§5.1).

class Item:
	var kind := ""
	var pos := Vector2.ZERO
	var vy := -60.0
	var t := 0.0
	var start_weapon := 0

var game: Game
var items: Array[Item] = []
var _cap_tex: Array[Texture2D] = []
var _shield_tex: Texture2D
var _bomb_tex: Texture2D


func _ready() -> void:
	for w: String in Tun.WEAPONS:
		_cap_tex.append(Tun.tex("cap_" + w))
	_shield_tex = Tun.tex("pick_shield")
	_bomb_tex = Tun.tex("pick_bomb")


func spawn(kind: String, at: Vector2) -> void:
	var it := Item.new()
	it.kind = kind
	it.pos = Vector2(clampf(at.x, 10, Tun.SCREEN.x - 10), at.y)
	# capsules start on the weapon after the one the player holds
	it.start_weapon = (Tun.WEAPONS.find(game.player.weapon) + 1) % Tun.WEAPONS.size()
	items.append(it)


func _weapon_index(it: Item) -> int:
	return (it.start_weapon + int(it.t / Tun.CAPSULE_CYCLE)) % Tun.WEAPONS.size()


func update(dt: float) -> void:
	var p := game.player
	var i := 0
	while i < items.size():
		var it := items[i]
		it.t += dt
		it.vy = move_toward(it.vy, Tun.PICKUP_FALL, 120.0 * dt)
		it.pos.y += it.vy * dt
		it.pos.x += sin(it.t * 2.0) * 6.0 * dt
		if p.alive and it.pos.distance_to(p.position) < Tun.PICKUP_RADIUS:
			_collect(it)
			items.remove_at(i)
			continue
		if it.pos.y > Tun.SCREEN.y + 12:
			items.remove_at(i) # lost pickups do not break the chain
			continue
		i += 1
	queue_redraw()


func _collect(it: Item) -> void:
	var p := game.player
	match it.kind:
		"capsule":
			var w: String = Tun.WEAPONS[_weapon_index(it)]
			if w == p.weapon:
				if p.level < Tun.WEAPON_MAX:
					p.level += 1
					game.fx.popup(it.pos, "POWER UP", Tun.WEAPON_COLOR[w])
				else:
					game.add_points(Tun.MAXED_CAPSULE_BONUS, it.pos)
					game.fx.popup(it.pos + Vector2(0, -8), "MAX", Tun.WEAPON_COLOR[w])
			else:
				p.weapon = w
				game.fx.popup(it.pos, w.to_upper(), Tun.WEAPON_COLOR[w])
			Audio.play("powerup")
		"shield":
			p.shield = mini(Tun.SHIELD_MAX, p.shield + 1)
			game.fx.popup(it.pos, "SHIELD", Tun.C_MINT)
			Audio.play("pickup")
		"bomb":
			p.bombs = mini(Tun.BOMBS_MAX, p.bombs + 1)
			game.fx.popup(it.pos, "BOMB", Tun.C_MAGENTA)
			Audio.play("pickup")


func _draw() -> void:
	for it in items:
		var tex: Texture2D
		match it.kind:
			"capsule": tex = _cap_tex[_weapon_index(it)]
			"shield": tex = _shield_tex
			_: tex = _bomb_tex
		var at := (it.pos - tex.get_size() / 2.0).round()
		draw_texture(tex, at)
		if it.kind == "capsule":
			# countdown arc to the next colour change
			var frac := fmod(it.t, Tun.CAPSULE_CYCLE) / Tun.CAPSULE_CYCLE
			var col: Color = Tun.WEAPON_COLOR[Tun.WEAPONS[_weapon_index(it)]]
			draw_arc(it.pos.round(), 11.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - frac), 20, col, 1.0)
