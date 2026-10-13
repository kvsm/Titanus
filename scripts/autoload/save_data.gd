extends Node
## Persistent progress and settings (user://save.cfg).

const PATH := "user://save.cfg"

var music_vol := 0.8
var sfx_vol := 0.9
var vibration := true
var scanlines := true
var levels_cleared := 0
var best := {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music_vol = cfg.get_value("settings", "music_vol", music_vol)
		sfx_vol = cfg.get_value("settings", "sfx_vol", sfx_vol)
		vibration = cfg.get_value("settings", "vibration", vibration)
		scanlines = cfg.get_value("settings", "scanlines", scanlines)
		levels_cleared = cfg.get_value("progress", "levels_cleared", levels_cleared)
		best = cfg.get_value("progress", "best", best)


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "music_vol", music_vol)
	cfg.set_value("settings", "sfx_vol", sfx_vol)
	cfg.set_value("settings", "vibration", vibration)
	cfg.set_value("settings", "scanlines", scanlines)
	cfg.set_value("progress", "levels_cleared", levels_cleared)
	cfg.set_value("progress", "best", best)
	cfg.save(PATH)


func best_score(level: int) -> int:
	return int(best.get(level, 0))


## Returns true when the score is a new best.
func submit_score(level: int, score: int) -> bool:
	if score > best_score(level):
		best[level] = score
		save_data()
		return true
	return false


func mark_cleared(level: int) -> void:
	if level > levels_cleared:
		levels_cleared = level
		save_data()


func vibrate(ms: int) -> void:
	if vibration:
		Input.vibrate_handheld(ms)
