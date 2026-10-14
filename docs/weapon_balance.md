# Weapon balance

Measured with the weapon bench: `godot --headless -- --bench[=file.md]`. It fires each weapon at each level for 6 s, using the real firing and collision code, against stationary dummy targets. The player is at the bottom centre. All numbers are **damage per second, summed over every target**.

## Scenarios

| Scenario | Targets |
|---|---|
| `small_far` | One small enemy straight ahead, 240 px away |
| `small_near` | One small enemy straight ahead, 90 px away |
| `large` | One large enemy (42×42) ahead, 190 px away |
| `large_far` | One large enemy ahead, 310 px away (mid-boss distance) |
| `offset_40` | One small enemy 40 px to the side |
| `swarm_27` | 27 small enemies in 3 staggered rows (area damage) |

## Intended roles

- **Laser:** the best focused damage. No area: the beam stops at the first enemy in its path.
- **Vulcan:** about 70–78% of the Laser's focused damage, plus some area from its angled streams. Area is about 2× its focused damage.
- **Wave:** about 60% of the Laser's focused damage, but wide area. Area is about 2× its focused damage at L1–L2, 6× at L3–L5 and 10× at L6–L10.

## Results

| weapon | L | small_far | small_near | large | large_far | offset_40 | swarm_27 |
|---|---|---|---|---|---|---|---|
| vulcan | 1 | 40 | 40 | 40 | 40 | 0 | 40 |
| vulcan | 2 | 44 | 44 | 44 | 44 | 15 | 73 |
| vulcan | 3 | 56 | 56 | 56 | 56 | 15 | 115 |
| vulcan | 4 | 75 | 75 | 75 | 75 | 16 | 156 |
| vulcan | 5 | 93 | 93 | 92 | 93 | 17 | 180 |
| vulcan | 6 | 109 | 108 | 108 | 108 | 19 | 239 |
| vulcan | 7 | 123 | 123 | 123 | 123 | 19 | 258 |
| vulcan | 8 | 137 | 137 | 137 | 137 | 21 | 242 |
| vulcan | 9 | 151 | 151 | 151 | 151 | 22 | 260 |
| vulcan | 10 | 168 | 168 | 168 | 168 | 24 | 286 |
| laser | 1 | 50 | 50 | 50 | 50 | 0 | 50 |
| laser | 2 | 63 | 63 | 63 | 63 | 0 | 63 |
| laser | 3 | 81 | 81 | 81 | 81 | 0 | 81 |
| laser | 4 | 104 | 104 | 104 | 104 | 0 | 104 |
| laser | 5 | 121 | 121 | 121 | 121 | 0 | 121 |
| laser | 6 | 140 | 140 | 140 | 140 | 0 | 140 |
| laser | 7 | 158 | 158 | 158 | 158 | 0 | 158 |
| laser | 8 | 175 | 175 | 175 | 175 | 0 | 175 |
| laser | 9 | 194 | 194 | 194 | 194 | 0 | 194 |
| laser | 10 | 216 | 216 | 216 | 216 | 0 | 216 |
| wave | 1 | 32 | 32 | 33 | 33 | 0 | 63 |
| wave | 2 | 39 | 39 | 41 | 41 | 0 | 80 |
| wave | 3 | 50 | 50 | 50 | 50 | 52 | 305 |
| wave | 4 | 67 | 65 | 65 | 65 | 67 | 401 |
| wave | 5 | 77 | 77 | 77 | 77 | 77 | 462 |
| wave | 6 | 85 | 85 | 85 | 85 | 85 | 850 |
| wave | 7 | 93 | 96 | 96 | 96 | 93 | 939 |
| wave | 8 | 102 | 106 | 102 | 106 | 102 | 1031 |
| wave | 9 | 111 | 111 | 111 | 111 | 115 | 1127 |
| wave | 10 | 129 | 129 | 125 | 125 | 125 | 1253 |

## What was wrong before this pass (L10 numbers)

- **Wave stacking:** overlapping crescents each hit the same target, so the Wave did 643 DPS against a small enemy nearby and 375 against a large one, against the Laser's 216. Crescents in one volley now share their hits, so a target is hit at most once per volley.
- **Wave area:** each crescent pierced everything it touched, giving 3,402 DPS against the swarm. Each crescent now passes through at most 2 enemies, and L9–L10 fire 5 wider-spread crescents instead of 7.
- **Laser area:** the beam pierced its whole column, so it out-damaged the Vulcan against swarms (864 vs 286). It now stops at the first enemy.
- **Vulcan L2–L3:** only one or two thin streams went straight ahead, so focused damage fell to 17 and 31, below L1's 40. Both levels now have proper forward streams: 44 and 56.
