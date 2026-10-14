extends Node
## Pooled SFX playback plus a single looping music channel.

const SFX := ["shot_vulcan", "shot_wave", "shot_laser", "enemy_shot", "hit", "explode_small", "explode_big",
	"player_hit", "player_die", "pickup", "powerup", "extend", "menu", "menu_back", "bomb", "chain_lost",
	"warning", "part_break", "telegraph", "beam",
	"sonar", "mine_arm", "splash", "harpoon", "torpedo", "whale", "geyser"]
## Minimum seconds between repeats of very frequent sounds.
const THROTTLE := {"shot_vulcan": 0.1, "shot_wave": 0.12, "shot_laser": 0.3, "hit": 0.06, "enemy_shot": 0.06,
	"explode_small": 0.04, "pickup": 0.05,
	"sonar": 0.3, "torpedo": 0.15, "harpoon": 0.1, "splash": 0.1, "geyser": 0.3}
const VOICES := 16

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n: String in SFX:
		_streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus_volume("Music", Save.music_vol)
	_set_bus_volume("SFX", Save.sfx_vol)


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func play(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if THROTTLE.has(sfx_name) and now - float(_last.get(sfx_name, -10.0)) < float(THROTTLE[sfx_name]):
		return
	_last[sfx_name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	var s := load("res://assets/audio/%s.ogg" % track) as AudioStreamOggVorbis
	s.loop = true
	_music.stream = s
	_music.stream_paused = false
	_music.play()
	_music_name = track


func stop_music() -> void:
	_music.stop()
	_music_name = ""


func set_music_paused(paused: bool) -> void:
	_music.stream_paused = paused


## Playback position in seconds, compensated for mix latency (used for beat sync).
func music_time() -> float:
	if not _music.playing:
		return -1.0
	return _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
