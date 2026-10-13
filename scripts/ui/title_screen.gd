class_name TitleScreen
extends Node2D
## Title (§10.3): striped sun over an outrun grid, chrome logo, tap to start.

signal start_pressed

var _t := 0.0
var _logo: Texture2D
var _sun: Texture2D
var _ship: Texture2D
var _leaving := -1.0

const HORIZON := 250.0


func _ready() -> void:
	_logo = Tun.tex("logo")
	_sun = Tun.tex("sun_big")
	_ship = Tun.tex("player")
	Audio.play_music("title")


func _process(delta: float) -> void:
	_t += delta
	if _leaving >= 0.0:
		_leaving += delta
		if _leaving > 0.5:
			_leaving = -100.0
			start_pressed.emit()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if tapped and _t > 0.4 and _leaving == -1.0:
		_leaving = 0.0
		Audio.play("powerup")


func on_back() -> void:
	get_tree().quit()


func _draw() -> void:
	var w := Tun.SCREEN.x
	var h := Tun.SCREEN.y
	# sky bands
	var bands := [Tun.C_MIDNIGHT, Tun.C_DEEP, Tun.C_GRID, Tun.C_VIOLET, Tun.C_MAGENTA, Tun.C_PINK, Tun.C_ORANGE]
	var band_h := HORIZON / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0, i * band_h, w, band_h + 1), bands[i])
	# stars
	for i in 40:
		var sx := fmod(i * 97.13, w)
		var sy := fmod(i * 53.7, HORIZON * 0.45)
		if int(_t * 2.0 + i) % 5 != 0:
			draw_rect(Rect2(sx, sy, 1, 1), Tun.C_PALE)
	# sun
	var sun_pos := Vector2((w - _sun.get_width()) / 2.0, HORIZON - _sun.get_height() + 2)
	draw_texture(_sun, sun_pos)
	# ground + perspective grid
	draw_rect(Rect2(0, HORIZON, w, h - HORIZON), Tun.C_MIDNIGHT)
	var vp := Vector2(w / 2.0, HORIZON)
	for k in range(-14, 15):
		draw_line(vp + Vector2(k * 8, 0), Vector2(w / 2.0 + k * 40, h), Tun.C_MAGENTA, 1.0)
	var n := 12
	for i in n:
		var z := fmod(i + _t * 1.5, n) / n
		var y := HORIZON + (h - HORIZON) * z * z
		draw_line(Vector2(0, roundf(y)), Vector2(w, roundf(y)), Tun.C_MAGENTA, 1.0)
	draw_line(Vector2(0, HORIZON), Vector2(w, HORIZON), Tun.C_PALE, 1.0)
	# logo
	var bob := roundf(sin(_t * 1.5) * 2.0)
	draw_texture(_logo, Vector2((w - _logo.get_width()) / 2.0, 52 + bob))
	PixelFont.draw(self, "A NEON DRIVE SHMUP", Vector2(w / 2.0, 104), Tun.C_CYAN, 1, PixelFont.CENTER)
	# ship flying over the grid
	var ship_y := 380.0 - (_leaving * 900.0 if _leaving > 0.0 else 0.0)
	draw_set_transform(Vector2(w / 2.0, ship_y), 0.0, Vector2(2, 2))
	draw_texture(_ship, Vector2(-11, -6))
	draw_set_transform(Vector2.ZERO)
	if int(_t * 2.0) % 2 == 0 or _leaving >= 0.0:
		PixelFont.draw(self, "TAP TO START", Vector2(w / 2.0, 430), Tun.C_PALE, 2, PixelFont.CENTER)
	var best := Save.best_score(1)
	if best > 0:
		PixelFont.draw(self, "BEST %08d" % best, Vector2(w / 2.0, 456), Tun.C_YELLOW, 1, PixelFont.CENTER)
	PixelFont.draw(self, "V" + str(ProjectSettings.get_setting("application/config/version")), Vector2(w - 3, h - 10), Tun.C_GRID, 1, PixelFont.RIGHT)
