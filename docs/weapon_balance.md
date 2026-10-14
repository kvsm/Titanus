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
| vulcan | 1 | 34 | 34 | 34 | 34 | 0 | 34 |
| vulcan | 2 | 36 | 36 | 36 | 36 | 12 | 60 |
| vulcan | 3 | 42 | 42 | 42 | 42 | 11 | 86 |
| vulcan | 4 | 52 | 52 | 52 | 52 | 11 | 108 |
| vulcan | 5 | 61 | 61 | 60 | 61 | 11 | 118 |
| vulcan | 6 | 69 | 69 | 69 | 69 | 12 | 153 |
| vulcan | 7 | 76 | 76 | 76 | 76 | 12 | 160 |
| vulcan | 8 | 84 | 84 | 84 | 84 | 13 | 148 |
| vulcan | 9 | 91 | 91 | 91 | 91 | 13 | 156 |
| vulcan | 10 | 100 | 100 | 100 | 100 | 14 | 170 |
| laser | 1 | 43 | 43 | 43 | 43 | 0 | 43 |
| laser | 2 | 49 | 49 | 49 | 49 | 0 | 49 |
| laser | 3 | 58 | 58 | 58 | 58 | 0 | 58 |
| laser | 4 | 70 | 70 | 70 | 70 | 0 | 70 |
| laser | 5 | 79 | 79 | 79 | 79 | 0 | 79 |
| laser | 6 | 88 | 88 | 88 | 88 | 0 | 88 |
| laser | 7 | 97 | 97 | 97 | 97 | 0 | 97 |
| laser | 8 | 106 | 106 | 106 | 106 | 0 | 106 |
| laser | 9 | 116 | 116 | 116 | 116 | 0 | 116 |
| laser | 10 | 127 | 127 | 127 | 127 | 0 | 127 |
| wave | 1 | 24 | 24 | 25 | 25 | 0 | 47 |
| wave | 2 | 27 | 27 | 28 | 28 | 0 | 55 |
| wave | 3 | 32 | 32 | 32 | 32 | 33 | 195 |
| wave | 4 | 40 | 39 | 39 | 39 | 40 | 239 |
| wave | 5 | 44 | 44 | 44 | 44 | 44 | 265 |
| wave | 6 | 48 | 48 | 48 | 48 | 48 | 478 |
| wave | 7 | 51 | 53 | 53 | 53 | 51 | 517 |
| wave | 8 | 56 | 57 | 56 | 57 | 56 | 559 |
| wave | 9 | 60 | 60 | 60 | 60 | 61 | 603 |
| wave | 10 | 68 | 68 | 66 | 66 | 66 | 659 |

## Later tuning
- **v0.1 difficulty pass:** each level now keeps only 60% of its gain over L1. On top of that, Laser and Vulcan do 15% less damage and the Wave 25% less, at every level. At L10, focused damage is 127 (Laser) / 100 (Vulcan) / 66 (Wave), down from 216 / 168 / 129.

## What was wrong before the balance pass (L10 numbers)

- **Wave stacking:** overlapping crescents each hit the same target, so the Wave did 643 DPS against a small enemy nearby and 375 against a large one, against the Laser's 216. Crescents in one volley now share their hits, so a target is hit at most once per volley.
- **Wave area:** each crescent pierced everything it touched, giving 3,402 DPS against the swarm. Each crescent now passes through at most 2 enemies, and L9–L10 fire 5 wider-spread crescents instead of 7.
- **Laser area:** the beam pierced its whole column, so it out-damaged the Vulcan against swarms (864 vs 286). It now stops at the first enemy.
- **Vulcan L2–L3:** only one or two thin streams went straight ahead, so focused damage fell to 17 and 31, below L1's 40. Both levels now have proper forward streams: 44 and 56.
