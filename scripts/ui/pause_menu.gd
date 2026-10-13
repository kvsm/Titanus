class_name PauseMenu
extends Node2D
## Pause menu (§10.3): resume, music/SFX volume, vibration, scanlines, quit.

signal resumed
signal quit

const ROW_H := 26.0
const TOP := 92.0
const ROWS := ["resume", "controls", "tilt_sens", "tilt_invert", "music", "sfx", "vibration", "scanlines", "quit"]
const SENS_NAMES := ["LOW", "MED", "HIGH"]


func open() -> void:
	visible = true
	queue_redraw()


func resume() -> void:
	visible = false
	Save.save_data()
	Audio.play("menu_back")
	resumed.emit()


func _row_rect(i: int) -> Rect2:
	return Rect2(35, TOP + i * ROW_H, 200, ROW_H - 4)


func handle_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		return
	for i in ROWS.size():
		var r := _row_rect(i)
		if not r.has_point(t.position):
			continue
		var right_half := t.position.x > r.position.x + r.size.x / 2.0
		match ROWS[i]:
			"resume":
				resume()
				return
			"controls":
				Save.control_scheme = "tilt" if Save.control_scheme == "touch" else "touch"
			"tilt_sens":
				Save.tilt_sensitivity = clampi(Save.tilt_sensitivity + (1 if right_half else -1), 0, 2)
			"tilt_invert":
				Save.tilt_invert_y = not Save.tilt_invert_y
			"music":
				Save.music_vol = _step(Save.music_vol, right_half)
				Audio.apply_volumes()
			"sfx":
				Save.sfx_vol = _step(Save.sfx_vol, right_half)
				Audio.apply_volumes()
			"vibration":
				Save.vibration = not Save.vibration
				Save.vibrate(40)
			"scanlines":
				Save.scanlines = not Save.scanlines
			"quit":
				Save.save_data()
				quit.emit()
				return
		Audio.play("menu")
		queue_redraw()
		return


func _step(v: float, up: bool) -> float:
	return clampf(snappedf(v + (0.1 if up else -0.1), 0.1), 0.0, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Tun.SCREEN), Color(Tun.C_MIDNIGHT, 0.8))
	PixelFont.draw(self, "PAUSED", Vector2(Tun.SCREEN.x / 2.0, 52), Tun.C_PALE, 3, PixelFont.CENTER)
	for i in ROWS.size():
		var r := _row_rect(i)
		draw_rect(r, Color(Tun.C_DEEP, 0.9))
		draw_rect(r, Tun.C_GRID, false, 1.0)
		var label := ""
		var value := ""
		match ROWS[i]:
			"resume": label = "RESUME"
			"controls":
				label = "CONTROLS"
				value = Save.control_scheme.to_upper()
			"tilt_sens":
				label = "TILT SPEED"
				value = "< %s >" % SENS_NAMES[Save.tilt_sensitivity]
			"tilt_invert":
				label = "TILT INVERT Y"
				value = "ON" if Save.tilt_invert_y else "OFF"
			"music":
				label = "MUSIC"
				value = "< %3d%% >" % roundi(Save.music_vol * 100)
			"sfx":
				label = "SFX"
				value = "< %3d%% >" % roundi(Save.sfx_vol * 100)
			"vibration":
				label = "VIBRATION"
				value = "ON" if Save.vibration else "OFF"
			"scanlines":
				label = "SCANLINES"
				value = "ON" if Save.scanlines else "OFF"
			"quit": label = "QUIT TO TITLE"
		var y := r.position.y + (r.size.y - 7) / 2.0
		if value == "":
			PixelFont.draw(self, label, Vector2(r.get_center().x, y), Tun.C_CYAN, 1, PixelFont.CENTER)
		else:
			PixelFont.draw(self, label, Vector2(r.position.x + 8, y), Tun.C_CHROME_L)
			PixelFont.draw(self, value, Vector2(r.end.x - 8, y), Tun.C_YELLOW, 1, PixelFont.RIGHT)
	var hint_y := TOP + ROWS.size() * ROW_H + 6
	PixelFont.draw(self, "TAP LEFT/RIGHT HALF TO ADJUST", Vector2(Tun.SCREEN.x / 2.0, hint_y), Tun.C_LAVENDER, 1, PixelFont.CENTER)
	if Save.control_scheme == "tilt":
		PixelFont.draw(self, "TILT RE-CENTRES ON RESUME", Vector2(Tun.SCREEN.x / 2.0, hint_y + 12), Tun.C_LAVENDER, 1, PixelFont.CENTER)
