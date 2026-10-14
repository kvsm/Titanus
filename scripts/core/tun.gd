class_name Tun
extends RefCounted
## Every gameplay tuning value lives here (docs/DESIGN.md is the reference).

const SCREEN := Vector2(270, 480)
const HUD_TOP := 18.0

# --- player movement (§3.1)
const SPEED_BASE := 128.0 # starting ship speed (px/s): 40% of SPEED_MAX
const SPEED_MAX := 320.0 # cap reachable with speed power-ups
const SPEED_PICKUP := 1.05 # each speed power-up multiplies speed by this
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
const EXTEND_FIRST := 500000 # first extra life
const EXTEND_EVERY := 1000000 # then one more every this many points (1.5M, 2.5M, ...)

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
const WEAPON_MAX := 10
const SWITCH_LEVEL := 2 # picking up a different weapon type resets to this level
const WEAPONS: Array[String] = ["vulcan", "laser", "wave"]

# --- weapons (§5). Streams are [x offset, angle in degrees from straight up].
# Tuning passes baked into these numbers: L2+ -10%; then each level keeps only 60% of its gain
# over L1, and Laser/Vulcan -15%, Wave -25% at every level.
# Vulcan "heavy" streams fly straight ahead and deal heavy_dmg (drawn as big slugs on levels
# marked "slug"); the angled "streams" give it some area coverage.
# Balance targets (measure with `--bench`): focused DPS Laser > Vulcan (~75%) > Wave (~60%);
# area (a row of enemies) Wave >> Vulcan > Laser.
const VULCAN := [
	{"interval": 0.075, "dmg": 1.27, "heavy_dmg": 1.27, "heavy": [[-4, 0], [4, 0]], "streams": []},  # L1
	{"interval": 0.075, "dmg": 0.9, "heavy_dmg": 1.35, "heavy": [[-4, 0], [4, 0]], "streams": [[-7, -10], [7, 10]]},  # L2
	{"interval": 0.075, "dmg": 0.83, "heavy_dmg": 1.58, "heavy": [[-4, 0], [4, 0]], "streams": [[-7, -10], [7, 10], [-9, -18], [9, 18]]},  # L3
	{"interval": 0.075, "dmg": 0.84, "heavy_dmg": 1.94, "slug": true, "heavy": [[-3, 0], [3, 0]], "streams": [[-8, -10], [8, 10], [-10, -16], [10, 16]], "side": [[-6, -35], [6, 35]]},  # L4
	{"interval": 0.07, "dmg": 0.8, "heavy_dmg": 1.42, "slug": true, "heavy": [[-4, 0], [0, 0], [4, 0]], "streams": [[-9, -10], [9, 10], [-11, -18], [11, 18]], "side": [[-6, -35], [6, 35]]},  # L5
	{"interval": 0.065, "dmg": 0.78, "heavy_dmg": 1.49, "slug": true, "heavy": [[-4, 0], [0, 0], [4, 0]], "streams": [[-9, -8], [9, 8], [-11, -14], [11, 14], [-12, -22], [12, 22]], "side": [[-6, -35], [6, 35], [-6, -55], [6, 55]]},  # L6
	{"interval": 0.065, "dmg": 0.78, "heavy_dmg": 1.66, "slug": true, "heavy": [[-4, 0], [0, 0], [4, 0]], "streams": [[-9, -8], [9, 8], [-11, -14], [11, 14], [-12, -22], [12, 22]], "side": [[-6, -35], [6, 35], [-6, -55], [6, 55]]},  # L7
	{"interval": 0.06, "dmg": 0.77, "heavy_dmg": 1.67, "slug": true, "heavy": [[-4, 0], [0, 0], [4, 0]], "streams": [[-9, -8], [9, 8], [-11, -14], [11, 14], [-13, -20], [13, 20], [-14, -28], [14, 28]], "side": [[-6, -35], [6, 35], [-6, -55], [6, 55]]},  # L8
	{"interval": 0.06, "dmg": 0.78, "heavy_dmg": 1.36, "slug": true, "heavy": [[-6, 0], [-2, 0], [2, 0], [6, 0]], "streams": [[-10, -8], [10, 8], [-12, -14], [12, 14], [-13, -20], [13, 20], [-14, -28], [14, 28]], "side": [[-6, -35], [6, 35], [-6, -55], [6, 55]]},  # L9
	{"interval": 0.055, "dmg": 0.77, "heavy_dmg": 1.37, "slug": true, "heavy": [[-6, 0], [-2, 0], [2, 0], [6, 0]], "streams": [[-10, -8], [10, 8], [-12, -14], [12, 14], [-13, -20], [13, 20], [-14, -28], [14, 28]], "side": [[-6, -35], [6, 35], [-6, -55], [6, 55], [-8, -75], [8, 75]]},  # L10
]
const VULCAN_SPEED := 520.0
const LASER_WIDTH: Array[float] = [4.0, 6.0, 8.0, 12.0, 15.0, 18.0, 20.0, 22.0, 24.0, 26.0]
const LASER_DPS: Array[float] = [42.5, 49.1, 58.3, 69.8, 79.0, 88.1, 97.3, 106.5, 115.7, 127.2]
const WAVE := [
	{"interval": 0.22, "dmg": 5.25, "pierce": 2, "angles": [0]},  # L1
	{"interval": 0.22, "dmg": 6.03, "pierce": 2, "angles": [0]},  # L2
	{"interval": 0.22, "dmg": 7.12, "pierce": 2, "angles": [-14, 0, 14]},  # L3
	{"interval": 0.22, "dmg": 8.58, "pierce": 2, "angles": [-16, 0, 16]},  # L4
	{"interval": 0.2, "dmg": 8.83, "pierce": 2, "angles": [-16, 0, 16]},  # L5
	{"interval": 0.2, "dmg": 9.56, "pierce": 2, "angles": [-26, -13, 0, 13, 26]},  # L6
	{"interval": 0.19, "dmg": 9.91, "pierce": 2, "angles": [-26, -13, 0, 13, 26]},  # L7
	{"interval": 0.18, "dmg": 10.1, "pierce": 2, "angles": [-26, -13, 0, 13, 26]},  # L8
	{"interval": 0.18, "dmg": 10.83, "pierce": 2, "angles": [-32, -16, 0, 16, 32]},  # L9
	{"interval": 0.17, "dmg": 11.26, "pierce": 2, "angles": [-32, -16, 0, 16, 32]},  # L10
]
const WAVE_SPEED := 300.0
# Wave: crescents in one volley share hits (a target is hit at most once per volley) and each
# crescent passes through at most "pierce" enemies. The Laser hits only the first enemy in its beam.

# --- enemies (§8)
const ESCAPE_MARGIN := 26.0
const ENEMIES := {
	"glitch": {"hp": 3.0, "half": Vector2(5, 5), "score": 100, "tex": "glitch"},
	"strobe": {"hp": 10.0, "half": Vector2(7, 7), "score": 300, "tex": "strobe"},
	"turret": {"hp": 18.0, "half": Vector2(7, 7), "score": 500, "tex": "turret_base"},
	"car": {"hp": 12.0, "half": Vector2(9, 5), "score": 400, "tex": "car"},
	"carrier": {"hp": 70.0, "half": Vector2(15, 13), "score": 2000, "tex": "carrier"},
	"subwoofer": {"hp": 1100.0, "half": Vector2(21, 21), "score": 10000, "tex": "subwoofer"},
	"note": {"hp": 4.0, "half": Vector2(4, 4), "score": 150, "tex": "note"},
	# stronger late-level enemies
	"prism": {"hp": 90.0, "half": Vector2(10, 11), "score": 1500, "tex": "prism"},
	"equalizer": {"hp": 260.0, "half": Vector2(21, 11), "score": 3000, "tex": "equalizer"},
	# Level 2: NEON TIDE
	"jetski": {"hp": 4.0, "half": Vector2(5, 7), "score": 120, "tex": "jetski", "behaviour": "glitch"},
	"mine": {"hp": 8.0, "half": Vector2(6, 6), "score": 400, "tex": "mine"},
	"harpooner": {"hp": 26.0, "half": Vector2(9, 12), "score": 700, "tex": "harpooner"},
	"inker": {"hp": 20.0, "half": Vector2(7, 9), "score": 600, "tex": "inker"},
	"trawler": {"hp": 80.0, "half": Vector2(14, 12), "score": 2000, "tex": "trawler", "behaviour": "carrier"},
	"torpedo_boat": {"hp": 130.0, "half": Vector2(11, 14), "score": 2500, "tex": "torpedo_boat"},
	"frigate": {"hp": 300.0, "half": Vector2(14, 22), "score": 3500, "tex": "frigate"},
	"torpedo": {"hp": 5.0, "half": Vector2(2, 6), "score": 50, "tex": "torpedo", "exempt": true},
	"barracuda": {"hp": 1300.0, "half": Vector2(12, 32), "score": 12000, "tex": "barracuda"},
}
const INK_RADIUS := 22.0
const INK_LIFE := 6.0
const INK_SLOW := 0.5 # speed multiplier while in ink

# random pickup drops from any enemy kill (each rolled independently)
const DROP_CHANCE := {"shield": 0.01, "bomb": 0.01, "speed": 0.05}
const SPLIT_TIME := 0.9 # PRISM shards burst after this many seconds

# enemy bullet kinds: radius used for collision
enum B { PINK, ORANGE, BIG, VIOLET, SHARD, HARPOON, LINK, GEYSER, SONAR }
const BULLET_R: Array[float] = [2.5, 2.5, 4.0, 2.5, 4.0, 2.5, 2.0, 3.5, 2.5]
const LINK_SPACING := 0.045 # seconds between chain links dropped by a harpoon
const LINK_LIFE := 1.1 # chain links hang in place this long
const GEYSER_GRAVITY := 150.0 # px/s^2 pulling geyser droplets back down

# --- boss HELIOS (§9)
const HELIOS_ARM_HP := 350.0
const HELIOS_CORE_HP := 1800.0
const HELIOS_PHASE2_TIME := 35.0
const HELIOS_PHASE3_FRACTION := 0.4
const HELIOS_BULLET_SPEED := 1.15 # multiplier on every HELIOS bullet speed

# --- boss LEVIATHAN (Level 2)
const LEVIATHAN_FIN_HP := 450.0
const LEVIATHAN_CORE_HP := 2400.0
const LEVIATHAN_PHASE2_TIME := 35.0
const LEVIATHAN_PHASE3_FRACTION := 0.4
const LEVIATHAN_BULLET_SPEED := 1.0 # multiplier on every LEVIATHAN bullet speed

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
