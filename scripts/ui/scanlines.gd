class_name Scanlines
extends Node2D
## Optional CRT scanline overlay (§10.2).


func _process(_delta: float) -> void:
	if visible != Save.scanlines:
		visible = Save.scanlines


func _draw() -> void:
	var c := Color(0, 0, 0, 0.16)
	var y := 1.0
	while y < Tun.SCREEN.y:
		draw_line(Vector2(0, y + 0.5), Vector2(Tun.SCREEN.x, y + 0.5), c, 1.0)
		y += 2.0
