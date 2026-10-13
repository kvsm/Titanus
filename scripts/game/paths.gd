class_name Paths
extends RefCounted
## Flight paths for formation enemies. Control points are smoothed with Catmull-Rom.
## `mirror` flips horizontally; `dx` shifts the whole path.

const POINTS := {
	"dive_u": [Vector2(70, -15), Vector2(70, 170), Vector2(100, 250), Vector2(170, 250), Vector2(200, 170), Vector2(200, -20)],
	"swoop": [Vector2(-15, 70), Vector2(70, 150), Vector2(135, 210), Vector2(200, 160), Vector2(285, 60)],
	"cross": [Vector2(-15, 50), Vector2(135, 170), Vector2(285, 290)],
	"loop": [Vector2(80, -15), Vector2(80, 160), Vector2(120, 220), Vector2(170, 190), Vector2(150, 130), Vector2(100, 150), Vector2(80, 250), Vector2(80, 500)],
	"down_back": [Vector2(135, -15), Vector2(135, 150), Vector2(140, 195), Vector2(150, 150), Vector2(150, -20)],
}

const SAMPLES_PER_SEGMENT := 12


static func build(path_name: String, mirror: bool, dx: float) -> PackedVector2Array:
	var src: Array = POINTS[path_name]
	var pts: Array[Vector2] = []
	for p: Vector2 in src:
		var q := Vector2(p.x + dx, p.y)
		if mirror:
			q.x = Tun.SCREEN.x - q.x
		pts.append(q)
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for s in SAMPLES_PER_SEGMENT:
			var t := float(s) / SAMPLES_PER_SEGMENT
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(pts[pts.size() - 1])
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
