class_name Background
extends Node2D
## Three parallax layers (§7.1): a procedural floor (city: neon grid; sea: rippling water with
## a reflected grid), a tile layer at gameplay speed, and a haze/spray layer. Optional storm.

const TILE_H := 480.0
const TILES := {
	"outskirts": "res://assets/bg/city_outskirts.png",
	"downtown": "res://assets/bg/city_downtown.png",
	"harbour": "res://assets/bg/sea_harbour.png",
	"open": "res://assets/bg/sea_open.png",
}

var theme := "city" # "city" or "sea"
var mode := "outskirts" # which tile to queue next
var storm := false
var _tiles := {}
var _top: Texture2D
var _bottom: Texture2D
var _city_y := 0.0
var _grid_y := 0.0
var _haze_y := 0.0
var _haze: Texture2D
var _t := 0.0
var _flash := 0.0
var _flash_t := 3.0


func _ready() -> void:
	for k: String in TILES:
		_tiles[k] = load(TILES[k])
	set_theme(theme)


func set_theme(t: String) -> void:
	theme = t
	mode = "harbour" if theme == "sea" else "outskirts"
	_haze = load("res://assets/bg/spray.png" if theme == "sea" else "res://assets/bg/haze.png")
	_top = _tiles[mode]
	_bottom = _tiles[mode]


func scroll(dy: float, dt: float) -> void:
	_t += dt
	_city_y += dy
	_grid_y += dy * 0.5
	_haze_y += dy * 1.6
	while _city_y >= TILE_H:
		_city_y -= TILE_H
		_bottom = _top
		_top = _tiles[mode]
	_flash = maxf(0.0, _flash - dt * 3.0)
	if storm:
		_flash_t -= dt
		if _flash_t <= 0.0:
			_flash_t = randf_range(2.5, 6.0)
			_flash = 1.0
			Audio.play("explode_big", -14.0, 0.5) # distant thunder
	queue_redraw()


func _draw() -> void:
	if theme == "sea":
		_draw_water()
	else:
		_draw_grid_floor()
	# tile layer (dimmed so bullets stay the brightest thing on screen)
	var dim := Color(0.52, 0.5, 0.62) if theme == "city" else Color(0.62, 0.62, 0.72)
	draw_texture(_bottom, Vector2(0, roundf(_city_y)), dim)
	draw_texture(_top, Vector2(0, roundf(_city_y - TILE_H)), dim)
	# haze / spray
	var hy := fmod(_haze_y, TILE_H)
	draw_texture(_haze, Vector2(0, roundf(hy)))
	draw_texture(_haze, Vector2(0, roundf(hy - TILE_H)))
	if storm:
		_draw_storm()


func _draw_grid_floor() -> void:
	var w := Tun.SCREEN.x
	draw_rect(Rect2(0, 0, w, TILE_H), Tun.C_MIDNIGHT)
	var cell := 24.0
	var gy := fmod(_grid_y, cell)
	var glow := 0.2 + 0.06 * sin(_t * 2.0)
	var y := gy - cell
	while y < TILE_H:
		draw_line(Vector2(0, roundf(y)), Vector2(w, roundf(y)), Color(Tun.C_MAGENTA, glow), 1.0)
		y += cell
	var x := 3.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, TILE_H), Color(Tun.C_MAGENTA, glow * 0.8), 1.0)
		x += cell


## Night ocean: deep water, a neon grid reflection that ripples, and glinting wave crests.
func _draw_water() -> void:
	var w := Tun.SCREEN.x
	draw_rect(Rect2(0, 0, w, TILE_H), Color(0.03, 0.06, 0.16))
	var cell := 24.0
	var gy := fmod(_grid_y, cell)
	var glow := 0.16 + 0.05 * sin(_t * 1.5)
	# rippling horizontal lines (reflected grid)
	var y := gy - cell
	while y < TILE_H:
		var prev := Vector2(0, y)
		for i in range(1, 19):
			var px := i * w / 18.0
			var p := Vector2(px, y + sin(px * 0.08 + _t * 2.0 + y * 0.05) * 2.0)
			draw_line(prev.round(), p.round(), Color(Tun.C_CYAN, glow), 1.0)
			prev = p
		y += cell
	# vertical lines wobble sideways
	var x := 3.0
	while x < w:
		var off := sin(_t * 1.3 + x * 0.1) * 2.0
		draw_line(Vector2(roundf(x + off), 0), Vector2(roundf(x - off), TILE_H), Color(Tun.C_VIOLET, glow * 0.7), 1.0)
		x += cell
	# wave-crest glints
	for i in 26:
		var gx := fmod(i * 71.3 + sin(_t * 0.7 + i) * 8.0, w)
		var gy2 := fmod(i * 43.9 + _grid_y * 1.2, TILE_H)
		if int(_t * 3.0 + i) % 4 != 0:
			draw_rect(Rect2(roundf(gx), roundf(gy2), 3, 1), Color(Tun.C_PALE, 0.35))


func _draw_storm() -> void:
	var w := Tun.SCREEN.x
	draw_rect(Rect2(0, 0, w, TILE_H), Color(0.02, 0.0, 0.08, 0.25))
	# slanted rain streaks
	for i in 60:
		var rx := fmod(i * 37.7 + _t * 90.0, w + 40) - 20
		var ry := fmod(i * 59.3 + _t * 520.0, TILE_H + 20) - 10
		draw_line(Vector2(rx, ry), Vector2(rx - 3, ry + 9), Color(Tun.C_LAVENDER, 0.35), 1.0)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, w, TILE_H), Color(0.8, 0.85, 1.0, _flash * 0.25))
