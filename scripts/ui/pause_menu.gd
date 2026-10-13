class_name PauseMenu
extends Node2D
## Pause menu (§10.3): resume, music/SFX volume, vibration, scanlines, quit.

signal resumed
signal quit

const ROW_H := 30.0
const TOP := 150.0
const ROWS := ["resume", "music", "sfx", "vibration", "scanlines", "quit"]


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
	PixelFont.draw(self, "PAUSED", Vector2(Tun.SCREEN.x / 2.0, 100), Tun.C_PALE, 3, PixelFont.CENTER)
	for i in ROWS.size():
		var r := _row_rect(i)
		draw_rect(r, Color(Tun.C_DEEP, 0.9))
		draw_rect(r, Tun.C_GRID, false, 1.0)
		var label := ""
		var value := ""
		match ROWS[i]:
			"resume": label = "RESUME"
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
	PixelFont.draw(self, "TAP LEFT/RIGHT HALF TO ADJUST", Vector2(Tun.SCREEN.x / 2.0, TOP + ROWS.size() * ROW_H + 8), Tun.C_LAVENDER, 1, PixelFont.CENTER)
