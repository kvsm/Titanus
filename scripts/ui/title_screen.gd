class_name TitleScreen
extends Node2D
## Title (§10.3): striped sun over an outrun grid, chrome logo, START button and
## a CONTROLS toggle (touch / tilt). Buttons fire on release inside the same button.

signal start_pressed

var _t := 0.0
var _logo: Texture2D
var _sun: Texture2D
var _ship: Texture2D
var _leaving := -1.0

const HORIZON := 250.0
const START_RECT := Rect2(65, 392, 140, 30)
const CONTROLS_RECT := Rect2(45, 430, 180, 18)

var _pressed := "" # button currently held down


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
	if _leaving != -1.0 or _t < 0.3:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var hit := _button_at(t.position)
		if t.pressed:
			_pressed = hit
		else:
			if hit != "" and hit == _pressed:
				_activate(hit)
			_pressed = ""
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate("start")
			KEY_C:
				_activate("controls")


func _button_at(p: Vector2) -> String:
	if START_RECT.grow(4).has_point(p):
		return "start"
	if CONTROLS_RECT.grow(4).has_point(p):
		return "controls"
	return ""


func _activate(button: String) -> void:
	match button:
		"start":
			_leaving = 0.0
			Audio.play("powerup")
		"controls":
			Save.control_scheme = "tilt" if Save.control_scheme == "touch" else "touch"
			Save.save_data()
			Audio.play("menu")


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
	var ship_y := 318.0 - (_leaving * 900.0 if _leaving > 0.0 else 0.0)
	draw_set_transform(Vector2(w / 2.0, ship_y), 0.0, Vector2(2, 2))
	draw_texture(_ship, Vector2(-11, -6))
	draw_set_transform(Vector2.ZERO)
	# START button (pulses; flashes while launching)
	var held := _pressed == "start" or _leaving >= 0.0
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	_draw_button(START_RECT, held, Color(Tun.C_PINK, 0.6 + 0.4 * glow))
	PixelFont.draw(self, "START", Vector2(w / 2.0, START_RECT.position.y + 8), Tun.C_WHITE if held else Tun.C_PALE, 2, PixelFont.CENTER)
	# CONTROLS toggle
	_draw_button(CONTROLS_RECT, _pressed == "controls", Tun.C_CYAN)
	PixelFont.draw(self, "CONTROLS: " + Save.control_scheme.to_upper(), Vector2(w / 2.0, CONTROLS_RECT.position.y + 6), Tun.C_CYAN, 1, PixelFont.CENTER)
	var hint := "STEER WITH ONE FINGER - 2ND FINGER BOMBS" if Save.control_scheme == "touch" \
		else "TILT TO STEER - TAP TO BOMB"
	PixelFont.draw(self, hint, Vector2(w / 2.0, 455), Tun.C_LAVENDER, 1, PixelFont.CENTER)
	var best := Save.best_score(1)
	if best > 0:
		PixelFont.draw(self, "BEST %08d" % best, Vector2(w / 2.0, 372), Tun.C_YELLOW, 1, PixelFont.CENTER)
	PixelFont.draw(self, "V" + str(ProjectSettings.get_setting("application/config/version")), Vector2(w - 3, h - 10), Tun.C_GRID, 1, PixelFont.RIGHT)


func _draw_button(r: Rect2, held: bool, border: Color) -> void:
	draw_rect(r, Tun.C_GRID if held else Color(Tun.C_MIDNIGHT, 0.85))
	draw_rect(r, border, false, 1.0)
	draw_rect(r.grow(-2), Color(border, 0.35), false, 1.0)
