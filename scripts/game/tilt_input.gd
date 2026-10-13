class_name TiltInput
extends RefCounted
## Tilt steering ("marble" style): lower the right edge to move right, tip the top of the
## phone away from you to move up. Angles are measured relative to a neutral pose captured
## by calibrate(), and map to a drive vector in -1..1 (fraction of the ship's max speed).
##
## Godot reports gravity in screen-oriented device axes: x to the right, y up, z out of the
## screen. A phone held upright reads roughly (0, -9.8, 0); lying flat face-up, (0, 0, -9.8).

var _g := Vector3.ZERO # low-pass filtered gravity
var _base_roll := 0.0
var _base_pitch := 0.0
var _calibrated := false


static func sensor() -> Vector3:
	var g := Input.get_gravity()
	if g.length_squared() < 1.0:
		g = Input.get_accelerometer()
	return g


func available() -> bool:
	return sensor().length_squared() > 1.0


func calibrate() -> void:
	_g = sensor()
	if _g.length_squared() < 1.0:
		return
	_base_roll = _roll(_g)
	_base_pitch = _pitch(_g)
	_calibrated = true


func read(dt: float) -> Vector2:
	var raw := sensor()
	if raw.length_squared() < 1.0:
		return Vector2.ZERO
	if not _calibrated:
		calibrate()
	_g = _g.lerp(raw, 1.0 - exp(-Tun.TILT_SMOOTHING * dt))
	var roll := rad_to_deg(_roll(_g) - _base_roll)
	var pitch := rad_to_deg(angle_difference(_base_pitch, _pitch(_g)))
	var full: float = Tun.TILT_FULL_ANGLE[clampi(Save.tilt_sensitivity, 0, 2)]
	var x := _shape(roll, full)
	var y := -_shape(pitch, full) # top tipped away (pitch up) moves the ship up the screen
	if Save.tilt_invert_y:
		y = -y
	return Vector2(x, y)


static func _shape(angle_deg: float, full: float) -> float:
	var a := absf(angle_deg)
	if a <= Tun.TILT_DEADZONE:
		return 0.0
	return signf(angle_deg) * clampf((a - Tun.TILT_DEADZONE) / (full - Tun.TILT_DEADZONE), 0.0, 1.0)


static func _roll(g: Vector3) -> float:
	return asin(clampf(g.x / g.length(), -1.0, 1.0))


static func _pitch(g: Vector3) -> float:
	return atan2(-g.z, -g.y)
