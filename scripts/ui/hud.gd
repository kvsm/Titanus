class_name Hud
extends Node2D
## In-game HUD (§10.1): score, chain, pause button, shield, weapon, bombs, lives,
## boss HP bar, plus banners (stage title, warning, chain lost, game over).

var game: Game
var boss_target: Node = null

var _t := 0.0
var _banner := ""
var _banner_sub := ""
var _banner_t := 0.0
var _warning_t := 0.0
var _chain_lost_t := 0.0
var _chain_pulse := 0.0
var _last_chain := 0
var _icons := {}


func _ready() -> void:
	for n: String in ["icon_life", "icon_bomb", "cap_vulcan", "cap_laser", "cap_wave"]:
		_icons[n] = Tun.tex(n)


func banner(text: String, sub: String = "", duration: float = 3.0) -> void:
	_banner = text
	_banner_sub = sub
	_banner_t = duration


func warning(duration: float) -> void:
	_warning_t = duration


func chain_lost() -> void:
	_chain_lost_t = 1.0


func update(dt: float) -> void:
	_t += dt
	_banner_t = maxf(0.0, _banner_t - dt)
	_warning_t = maxf(0.0, _warning_t - dt)
	_chain_lost_t = maxf(0.0, _chain_lost_t - dt)
	_chain_pulse = maxf(0.0, _chain_pulse - dt * 4.0)
	var c := game.score.chain
	if c > _last_chain:
		_chain_pulse = 1.0
	_last_chain = c
	queue_redraw()


func _draw() -> void:
	var w := Tun.SCREEN.x
	var h := Tun.SCREEN.y
	var sc := game.score
	var p := game.player

	if _warning_t > 0.0:
		var a := 0.18 + 0.12 * sin(_t * 8.0)
		draw_rect(Rect2(0, 0, w, h), Color(Tun.C_PINK, a))

	# top strip
	draw_rect(Rect2(0, 0, w, Tun.HUD_TOP), Color(Tun.C_MIDNIGHT, 0.75))
	draw_line(Vector2(0, Tun.HUD_TOP), Vector2(w, Tun.HUD_TOP), Color(Tun.C_MAGENTA, 0.6))
	PixelFont.draw(self, "%08d" % sc.score, Vector2(4, 6), Tun.C_CHROME_L)
	# chain
	var chain_col := Tun.C_PALE
	if _chain_pulse > 0.5:
		chain_col = Tun.C_WHITE
	elif sc.multiplier() >= 4.0:
		chain_col = Tun.C_PINK
	elif sc.multiplier() >= 2.0:
		chain_col = Tun.C_YELLOW
	if sc.chain > 0:
		PixelFont.draw(self, "%d *%.1f" % [sc.chain, sc.multiplier()], Vector2(150, 6), chain_col, 1, PixelFont.CENTER)
	# pause button
	draw_rect(Rect2(252, 5, 3, 9), Tun.C_CHROME_L)
	draw_rect(Rect2(258, 5, 3, 9), Tun.C_CHROME_L)

	# boss / mid-boss HP bar
	var frac := -1.0
	if is_instance_valid(boss_target):
		if boss_target is BossHelios:
			var b := boss_target as BossHelios
			if b.state != BossHelios.DONE:
				frac = b.hp_fraction()
		elif boss_target is Enemy:
			var e := boss_target as Enemy
			if not e.dead:
				frac = e.hp / e.max_hp
	if frac >= 0.0:
		draw_rect(Rect2(34, 22, 202, 5), Tun.C_MIDNIGHT)
		draw_rect(Rect2(35, 23, 200 * frac, 3), Tun.C_PINK if int(_t * 6.0) % 2 == 0 or frac > 0.25 else Tun.C_YELLOW)
		PixelFont.draw(self, "TITAN", Vector2(4, 21), Tun.C_PINK)

	# bottom left: shield pips + weapon
	for i in Tun.SHIELD_MAX:
		var filled := i < p.shield
		var col := Tun.C_MINT if filled else Tun.C_CHROME_D
		if filled and p.shield == 1 and int(_t * 6.0) % 2 == 0:
			col = Tun.C_PINK
		draw_rect(Rect2(4 + i * 9, h - 8, 7, 4), Tun.C_MIDNIGHT)
		draw_rect(Rect2(5 + i * 9, h - 7, 5, 2), col)
	var wi: Texture2D = _icons["cap_" + p.weapon]
	draw_texture(wi, Vector2(4, h - 26))
	PixelFont.draw(self, "L%d" % p.level, Vector2(19, h - 21), Tun.WEAPON_COLOR[p.weapon])

	# bottom right: bombs and lives
	var bt: Texture2D = _icons["icon_bomb"]
	for i in p.bombs:
		draw_texture(bt, Vector2(w - 10 - i * 9, h - 11))
	var lt: Texture2D = _icons["icon_life"]
	for i in maxi(0, p.lives - 1):
		draw_texture(lt, Vector2(w - 12 - i * 11, h - 22))

	# banners
	if _banner_t > 0.0:
		var y := 170.0
		PixelFont.draw(self, _banner, Vector2(w / 2.0, y), Tun.C_PALE, 3, PixelFont.CENTER)
		if _banner_sub != "":
			PixelFont.draw(self, _banner_sub, Vector2(w / 2.0, y + 30), Tun.C_CYAN, 2, PixelFont.CENTER)
	if _warning_t > 0.0 and int(_t * 3.0) % 2 == 0:
		draw_rect(Rect2(0, 196, w, 44), Color(Tun.C_MIDNIGHT, 0.8))
		PixelFont.draw(self, "WARNING", Vector2(w / 2.0, 202), Tun.C_PINK, 3, PixelFont.CENTER)
		PixelFont.draw(self, "TITAN APPROACHING", Vector2(w / 2.0, 228), Tun.C_YELLOW, 1, PixelFont.CENTER)
	if _chain_lost_t > 0.0 and int(_t * 10.0) % 2 == 0:
		PixelFont.draw(self, "CHAIN LOST", Vector2(150, 30), Tun.C_PINK, 1, PixelFont.CENTER)
	if game.game_over:
		draw_rect(Rect2(0, 180, w, 70), Color(Tun.C_MIDNIGHT, 0.85))
		PixelFont.draw(self, "GAME OVER", Vector2(w / 2.0, 192), Tun.C_PINK, 3, PixelFont.CENTER)
		if int(_t * 2.0) % 2 == 0:
			PixelFont.draw(self, "TAP TO RETRY", Vector2(w / 2.0, 226), Tun.C_PALE, 1, PixelFont.CENTER)
