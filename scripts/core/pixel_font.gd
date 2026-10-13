class_name PixelFont
extends RefCounted
## Draws text with the generated 5x7 pixel font (assets/font/font.png).
## Use '*' for the small multiplication sign.

const ORDER := " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!?.,:-+*%/<>()'=#"
const TEX := preload("res://assets/font/font.png")
const ADV := 6
const GLYPH_W := 5
const GLYPH_H := 7

enum { LEFT, CENTER, RIGHT }


static func width(text: String, scale: int = 1) -> int:
	return maxi(0, text.length() * ADV * scale - scale)


static func draw(ci: CanvasItem, text: String, pos: Vector2, color: Color = Color.WHITE, scale: int = 1,
		align: int = LEFT, outline: Color = Tun.C_MIDNIGHT) -> void:
	text = text.to_upper()
	var w := width(text, scale)
	var x := pos.x
	if align == CENTER:
		x -= w / 2.0
	elif align == RIGHT:
		x -= w
	var origin := Vector2(floorf(x), floorf(pos.y))
	if outline.a > 0.0:
		var o := float(maxi(1, scale / 2))
		for d: Vector2 in [Vector2(-o, 0), Vector2(o, 0), Vector2(0, -o), Vector2(0, o)]:
			_run(ci, text, origin + d, outline, scale)
	_run(ci, text, origin, color, scale)


static func _run(ci: CanvasItem, text: String, origin: Vector2, color: Color, scale: int) -> void:
	for i in text.length():
		var ch := text[i]
		if ch == " ":
			continue
		var idx := ORDER.find(ch)
		if idx < 0:
			idx = ORDER.find("?")
		ci.draw_texture_rect_region(TEX,
			Rect2(origin.x + i * ADV * scale, origin.y, GLYPH_W * scale, GLYPH_H * scale),
			Rect2(idx * ADV, 0, GLYPH_W, GLYPH_H), color)
