class_name Tun
extends RefCounted
## Every gameplay tuning value lives here (docs/DESIGN.md is the reference).

const SCREEN := Vector2(270, 480)
const HUD_TOP := 18.0

# --- player movement (§3.1)
const MAX_SPEED := 320.0
const TOUCH_OFFSET_Y := 0.0 # raise to ~24 to keep the ship above the fingertip
const PLAYER_MIN_Y := 24.0
const PLAYER_MARGIN_X := 9.0
const PLAYER_HITBOX_R := 2.0

# --- tilt controls
const TILT_DEADZONE := 0.75 # degrees from the neutral pose that are ignored
const TILT_FULL_ANGLE: Array[float] = [26.0, 18.0, 12.0] # degrees for full speed (LOW / MED / HIGH sensitivity)
const TILT_SMOOTHING := 14.0 # low-pass filter rate; higher = snappier but jittery

# --- shield + lives (§4.1)
const SHIELD_MAX := 4
const LIVES := 3
const INVULN_HIT := 1.5
const INVULN_RESPAWN := 2.5
const HIT_CANCEL_RADIUS := 40.0
const RESPAWN_DELAY := 1.6
const EXTENDS: Array[int] = [200000, 500000]

# --- bombs (§5.2)
const BOMBS_START := 2
const BOMBS_MAX := 5
const BOMB_COOLDOWN := 0.5
const BOMB_DAMAGE := 60.0
const BOMB_BOSS_FACTOR := 0.3
const BOMB_INVULN := 1.0

# --- scoring (§6)
const CHAIN_DIV := 10.0
const BOSS_KILL_BONUS := 50000
const BOSS_PART_BONUS := 5000
const MAXED_CAPSULE_BONUS := 5000
const LIFE_BONUS := 20000
const BOMB_BONUS := 10000
const BULLET_CASH := 100

# --- pickups (§5.1)
const CAPSULE_CYCLE := 1.5
const PICKUP_FALL := 28.0
const PICKUP_RADIUS := 14.0
const WEAPON_MAX := 4
const WEAPONS: Array[String] = ["vulcan", "laser", "wave"]

# --- weapons (§5). Streams are [x offset, angle in degrees from straight up].
const VULCAN := [
	{"interval": 0.075, "dmg": 1.5, "streams": [[-4, 0], [4, 0]]},
	{"interval": 0.075, "dmg": 1.4, "streams": [[-5, -4], [0, 0], [5, 4]]},
	{"interval": 0.075, "dmg": 1.3, "streams": [[-6, -8], [-2, 0], [2, 0], [6, 8]]},
	{"interval": 0.075, "dmg": 1.35, "streams": [[-8, -14], [-4, -6], [0, 0], [4, 6], [8, 14]],
		"side": [[-6, -35], [6, 35]]},
]
const VULCAN_SPEED := 520.0
const LASER_WIDTH: Array[float] = [4.0, 6.0, 8.0, 12.0]
const LASER_DPS: Array[float] = [50.0, 70.0, 90.0, 115.0]
const WAVE := [
	{"interval": 0.22, "dmg": 7.8, "angles": [0]},
	{"interval": 0.22, "dmg": 10.8, "angles": [0]},
	{"interval": 0.22, "dmg": 13.8, "angles": [-14, 0, 14]},
	{"interval": 0.22, "dmg": 17.8, "angles": [-16, 0, 16]},
]
const WAVE_SPEED := 300.0

# --- enemies (§8)
const ESCAPE_MARGIN := 26.0
const ENEMIES := {
	"glitch": {"hp": 3.0, "half": Vector2(5, 5), "score": 100, "tex": "glitch"},
	"strobe": {"hp": 10.0, "half": Vector2(7, 7), "score": 300, "tex": "strobe"},
	"turret": {"hp": 18.0, "half": Vector2(7, 7), "score": 500, "tex": "turret_base"},
	"car": {"hp": 12.0, "half": Vector2(9, 5), "score": 400, "tex": "car"},
	"carrier": {"hp": 70.0, "half": Vector2(15, 13), "score": 2000, "tex": "carrier"},
	"subwoofer": {"hp": 450.0, "half": Vector2(21, 21), "score": 10000, "tex": "subwoofer"},
	"note": {"hp": 4.0, "half": Vector2(4, 4), "score": 150, "tex": "note"},
}

# enemy bullet kinds: radius used for collision
enum B { PINK, ORANGE, BIG, VIOLET }
const BULLET_R: Array[float] = [2.5, 2.5, 4.0, 2.5]

# --- boss HELIOS (§9)
const HELIOS_ARM_HP := 350.0
const HELIOS_CORE_HP := 1800.0
const HELIOS_PHASE2_TIME := 35.0
const HELIOS_PHASE3_FRACTION := 0.4

# --- palette (§7.2)
const C_MIDNIGHT := Color("0d0221")
const C_DEEP := Color("261447")
const C_GRID := Color("541388")
const C_VIOLET := Color("8c1eff")
const C_LAVENDER := Color("b967ff")
const C_PINK := Color("ff2a6d")
const C_MAGENTA := Color("f222ff")
const C_ORANGE := Color("ff6c11")
const C_YELLOW := Color("ffd319")
const C_PALE := Color("fffb96")
const C_CYAN := Color("01cdfe")
const C_MINT := Color("05ffa1")
const C_CHROME_D := Color("3d3d5c")
const C_CHROME_M := Color("7a7aa8")
const C_CHROME_L := Color("c8c8e8")
const C_WHITE := Color("ffffff")

const WEAPON_COLOR := {"vulcan": C_YELLOW, "laser": C_PINK, "wave": C_CYAN}


static func tex(name: String) -> Texture2D:
	return load("res://assets/sprites/%s.png" % name) as Texture2D
