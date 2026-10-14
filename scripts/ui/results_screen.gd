class_name ResultsScreen
extends Node2D
## End-of-level tally and rank (§6).

signal done

var stats := {}
var _t := 0.0
var _rows: Array = []
var _total := 0
var _rank := "C"
var _new_best := false


## Final score for a cleared level: score plus the lives and bombs bonuses.
static func total_for(s: Dictionary) -> int:
	return int(s.score) + int(s.lives) * Tun.LIFE_BONUS + int(s.bombs) * Tun.BOMB_BONUS


func _ready() -> void:
	var lives_bonus := int(stats.lives) * Tun.LIFE_BONUS
	var bomb_bonus := int(stats.bombs) * Tun.BOMB_BONUS
	_total = total_for(stats)
	var kill_pct := 100.0 * int(stats.kills) / maxf(1.0, float(stats.spawned))
	_rows = [
		["SCORE", "%d" % int(stats.score)],
		["MAX CHAIN", "%d" % int(stats.max_chain)],
		["KILLS", "%d%%" % roundi(kill_pct)],
		["LIVES  %d * 20000" % int(stats.lives), "%d" % lives_bonus],
		["BOMBS  %d * 10000" % int(stats.bombs), "%d" % bomb_bonus],
	]
	_rank = _compute_rank(kill_pct, int(stats.max_chain))
	_new_best = Save.submit_score(int(stats.level), _total)
	Save.mark_cleared(int(stats.level))
	Audio.play_music("title")


static func _compute_rank(kill_pct: float, max_chain: int) -> String:
	if kill_pct >= 95.0 and max_chain >= 150:
		return "S"
	if kill_pct >= 85.0 and max_chain >= 80:
		return "A"
	if kill_pct >= 70.0:
		return "B"
	return "C"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if tapped and _t > _rows.size() * 0.5 + 1.5:
		Audio.play("menu")
		done.emit()


func on_back() -> void:
	done.emit()


func _draw() -> void:
	var w := Tun.SCREEN.x
	draw_rect(Rect2(Vector2.ZERO, Tun.SCREEN), Tun.C_MIDNIGHT)
	for i in 20:
		var y := 300.0 + pow(i / 20.0, 2.0) * 180.0
		draw_line(Vector2(0, y), Vector2(w, y), Color(Tun.C_MAGENTA, 0.35), 1.0)
	PixelFont.draw(self, "STAGE %d CLEAR" % int(stats.level), Vector2(w / 2.0, 40), Tun.C_PALE, 2, PixelFont.CENTER)
	PixelFont.draw(self, str(stats.get("name", "")), Vector2(w / 2.0, 64), Tun.C_CYAN, 1, PixelFont.CENTER)
	for i in _rows.size():
		if _t < 0.5 + i * 0.5:
			break
		var y := 100.0 + i * 22.0
		PixelFont.draw(self, _rows[i][0], Vector2(24, y), Tun.C_CHROME_L)
		PixelFont.draw(self, _rows[i][1], Vector2(w - 24, y), Tun.C_YELLOW, 1, PixelFont.RIGHT)
	var t_total := 0.5 + _rows.size() * 0.5
	if _t >= t_total:
		draw_line(Vector2(24, 210), Vector2(w - 24, 210), Tun.C_MAGENTA)
		PixelFont.draw(self, "TOTAL", Vector2(24, 220), Tun.C_PALE, 2)
		PixelFont.draw(self, "%d" % _total, Vector2(w - 24, 220), Tun.C_PALE, 2, PixelFont.RIGHT)
		if _new_best and int(_t * 3.0) % 2 == 0:
			PixelFont.draw(self, "NEW BEST!", Vector2(w / 2.0, 244), Tun.C_MINT, 1, PixelFont.CENTER)
	if _t >= t_total + 0.8:
		var col: Color = {"S": Tun.C_MAGENTA, "A": Tun.C_YELLOW, "B": Tun.C_CYAN, "C": Tun.C_CHROME_L}[_rank]
		PixelFont.draw(self, "RANK", Vector2(w / 2.0, 270), Tun.C_CHROME_L, 1, PixelFont.CENTER)
		PixelFont.draw(self, _rank, Vector2(w / 2.0, 284), col, 6, PixelFont.CENTER)
	if _t >= t_total + 1.5 and int(_t * 2.0) % 2 == 0:
		PixelFont.draw(self, "TAP TO CONTINUE", Vector2(w / 2.0, 440), Tun.C_PALE, 1, PixelFont.CENTER)
