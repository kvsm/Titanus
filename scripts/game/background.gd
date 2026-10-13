class_name Background
extends Node2D
## Three parallax layers (§7.1): neon grid floor, city (gameplay speed), haze.

const TILE_H := 480.0

var mode := "outskirts" # which city tile to queue next
var _tiles := {}
var _top: Texture2D
var _bottom: Texture2D
var _city_y := 0.0
var _grid_y := 0.0
var _haze_y := 0.0
var _haze: Texture2D
var _t := 0.0


func _ready() -> void:
	_tiles["outskirts"] = load("res://assets/bg/city_outskirts.png")
	_tiles["downtown"] = load("res://assets/bg/city_downtown.png")
	_haze = load("res://assets/bg/haze.png")
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
	queue_redraw()


func _draw() -> void:
	var w := Tun.SCREEN.x
	# grid floor
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
	# city (dimmed so bullets stay the brightest thing on screen)
	var dim := Color(0.52, 0.5, 0.62)
	draw_texture(_bottom, Vector2(0, roundf(_city_y)), dim)
	draw_texture(_top, Vector2(0, roundf(_city_y - TILE_H)), dim)
	# haze
	var hy := fmod(_haze_y, TILE_H)
	draw_texture(_haze, Vector2(0, roundf(hy)))
	draw_texture(_haze, Vector2(0, roundf(hy - TILE_H)))
