# TITANUS — Game Design Document (v0.1)

> Vertical-scrolling shoot-'em-up for Android.
> Colourful retro pixel art, synthwave aesthetic.
> Scope of this version: **one playable level** (Level 1) to tune the design before building the other four.

---

## 1. Pillars

1. **One finger, all action.** The ship goes where your finger goes, firing constantly. A second finger triggers the bomb. No other controls.
2. **Neon-on-midnight readability.** Everything glows, but enemy bullets are always the brightest, highest-contrast thing on screen.
3. **Hunt everything.** Scoring rewards killing *every* enemy: one escapee breaks your chain.
4. **Short, replayable runs.** Each level runs 2.5–3 minutes and ends with a towering **Titan** boss.

---

## 2. Platform & tech

| Item | Decision |
|---|---|
| Engine | **Godot 4** (latest stable 4.x at build time, pinned in CI), GDScript |
| Renderer | `gl_compatibility`, for the widest Android device support |
| Orientation | Portrait, locked |
| Internal resolution | **270 × 480** (9:16). Rendered to a viewport and scaled up with nearest-neighbour filtering. |
| Scaling | `stretch_mode = viewport`, `aspect = keep`. On taller phones the extra space is a letterbox filled with a dark scanline/grid frame, so the playfield is identical on every device (fair difficulty). |
| Target | Android, minSdk = Godot default (24) |
| Package id | `com.kvsm.titanus` |
| Build | GitHub Actions: headless Godot export → debug-signed APK uploaded as a workflow artifact on every push. Release signing comes later. |
| Frame rate | 60 fps target. All tuning values are per second, so the game is frame-rate independent. |

---

## 3. Controls

### 3.1 Movement: follow the finger
- While a finger is down, the ship moves **toward the touch point**, with **speed capped at the ship's current speed** (starts at `speed_base`, raised by speed power-ups up to `speed_max`).
- The ship never teleports. A touch far from the ship makes it travel there at max speed.
- Arrival is smooth: inside a small radius the speed eases off so the ship stops on the point instead of jittering.
- When the finger lifts, the ship **stays where it is** (and keeps firing).
- The ship is clamped to the playfield (a margin of half its width).
- `touch_offset_y` is a tunable, **default 0** (the ship sits directly under your finger, as chosen). If playtesting shows the finger hides too much, raising it to ~24 px puts the ship above the fingertip.

| Tunable | Start value |
|---|---|
| `speed_base` | 160 px/s at the start of a level |
| `speed_max` | 320 px/s, reached with speed power-ups (crossing the 270 px width takes ~0.85 s) |
| `arrive_radius` | 6 px |
| `touch_offset_y` | 0 px |

### 3.2 Firing
- **Always auto-fire** during gameplay. No input is needed.

### 3.3 Bomb: second-finger tap
- With the movement finger down, **any additional touch** (a second finger) fires a bomb.
- Only the *first* finger steers. Extra touches never move the ship.
- If the steering finger lifts while the second finger is still down, the second finger does **not** take over steering until it is lifted and placed again. This prevents surprise jumps.
- A 0.5 s cooldown between bombs prevents accidental double-spend.

### 3.4 Alternative scheme: tilt (added in v0.1)
Chosen with the CONTROLS button on the title screen or in the pause menu.

- **Steering:** "marble" style. Lower the right edge to move right; tip the top away to move up.
- **Speed:** proportional to the tilt angle from the neutral pose, capped at the ship's current speed. A 0.75° deadzone is ignored; full speed comes at 26° / 18° / 12° (sensitivity LOW / MED / HIGH).
- **Neutral pose:** captured when the level starts and again on every resume from pause.
- **Smoothing:** sensor readings are low-pass filtered to remove jitter.
- **Bomb:** with no steering finger, **any tap** (outside the pause button) fires a bomb.
- **Invert Y:** an option in the pause menu.

### 3.5 System
- Pause button in the top-right corner (enlarged hit area) and the Android **Back** button both pause.
- The game auto-pauses when the app loses focus.
- Vibration on taking a hit, losing a life and bombing (can be turned off in settings).

---

## 4. Player ship

- Sprite ~20 × 24 px: a sleek chrome delta-wing with magenta and cyan neon trim and a flickering exhaust.
- **Hitbox: 4 × 4 px** at the cockpit, shown as a small white core dot (it pulses when bullets are near).

### 4.1 Shield + lives
| Item | Value |
|---|---|
| Shield | **4 pips**. Each enemy bullet or collision removes 1 pip. |
| Pip lost | 1.5 s invulnerability (ship blinks), all bullets within 40 px are cancelled, short screen shake |
| Shield at 0 | The next hit costs a **life** (explosion, respawn from the bottom of the screen, 2.5 s invulnerability, full shield) |
| Lives | **3** to start. Extra lives at 500k points, then every 1M after that (1.5M, 2.5M, ...). |
| Weapon on death | Weapon type kept, **power level −1** (minimum 1) |
| Bombs on death | Reset to 2 if below 2 |
| Game over | Back to the **start of the current level**. Beaten levels stay unlocked. |

---

## 5. Weapons

Three weapon types. Each one has **power levels 1–10**. Damage for every level above L1 was cut by 10% in the v0.1 tuning pass.

| Type | Colour | Role | Description |
|---|---|---|---|
| **Vulcan** | Sun-yellow / orange | Coverage | Rapid small bullets. Its spread widens with level: L1 twin stream → L10 wide fan plus three pairs of side shots. From **L4**, the straight-ahead streams become **heavy slugs** whose focused damage sits between the Wave and the Laser. |
| **Laser** | Hot pink | Single-target | A continuous beam straight up that **stops at the first enemy in its path**. Width 4 → 26 px. The highest focused damage, but no area, and you have to line up. |
| **Wave** | Cyan | Area | Expanding crescents in a wide arc. **Each crescent passes through up to 2 enemies.** Crescents in one volley share their hits, so overlapping crescents can't stack damage on one target. The lowest focused damage (about 60% of the Laser), but by far the widest coverage. |

**Balance:** focused damage runs **Laser > Vulcan (about 75%) > Wave (about 60%)**, and area damage runs **Wave >> Vulcan > Laser**. [weapon_balance.md](weapon_balance.md) has the measured numbers for every level and scenario, from the weapon bench (`godot --headless -- --bench`). All values are tunable in `scripts/core/tun.gd`.

### 5.1 Pickups
- **Weapon capsule.** Every supply ship (carrier) **always** drops one. There are six per level. It drifts down slowly and **cycles colour (Vulcan → Laser → Wave) every 1.5 s**, so you choose your weapon by when you grab it.
  - **Same type as your current weapon:** +1 power level. At L10 it gives +5,000 points instead.
  - **Different type:** you switch to that type and **reset to L2**. Timing the colour matters.
  - Level 1 has 6 supply ships, so a single weapon can reach about **L7** within it. L8–L10 are for later levels.
- **Shield cell** (green S): restores 1 pip. A **1% random drop from any enemy kill**.
- **Bomb** (B): +1 bomb (maximum 5). A **1% random drop from any enemy kill**.
- **Speed** (orange chevrons): ship speed ×1.05, up to the 320 px/s cap. About 15 pickups take you from the starting 160 px/s to the cap. Above the cap it gives +5,000 points. A **5% random drop from any enemy kill**. Speed is kept when you lose a life.
- Only one random drop is rolled per kill. Supply ships drop their capsule instead.
- Pickups that scroll off-screen are lost, but **do not** break the chain.

### 5.2 Bomb
- Start each level with **2**. Maximum 5.
- Effect: an expanding synth shockwave ring from the ship (0.6 s). It **clears all enemy bullets**, deals 60 damage to everything on screen (bosses take 30%), and gives 1.0 s of invulnerability.
- Kills from the bomb **count toward the chain**.

---

## 6. Scoring: the chain

- Every kill adds **+1 to the chain**. The chain is **unlimited**.
- **Score per kill = base value × multiplier**, where **multiplier = 1 + chain ÷ 10** (chain 10 → ×2, chain 50 → ×6, chain 120 → ×13).
- **The chain breaks (resets to 0) when an enemy leaves the screen alive.** Nothing else breaks it: taking hits, losing a life and missing pickups all keep it alive.
  - This means **every enemy must be killable** before it can leave. Level design rule: every enemy spends at least ~2.5 s on screen within reach of an L1 weapon.
  - When the chain breaks: a "CHAIN LOST" flash and a descending synth sting. The chain counter shatters.
- Boss parts and the boss itself each add to the chain. The boss kill bonus (50,000) is multiplied too.
- **End-of-level results:** score, max chain, kill %, lives remaining (+20k each), bombs remaining (+10k each), rank **S / A / B / C** from kill % and max chain.
- A high score for each level is saved locally.

---

## 7. Level 1: **NEON DRIVE** (Neon Grid City)

### 7.1 Look
A top-down flight over a synthwave city at sunset. The camera points straight down. The synthwave mood comes from colour, glow and motifs rather than perspective.

Background parallax layers, back to front:
1. **Grid floor.** A deep-purple ground with a glowing magenta grid scrolling slowly (the "outrun grid" seen from above).
2. **City layer.** Rooftops, neon-lined highways with car light trails (red going one way, white the other), palm-tree tops, glowing billboards, pyramid towers with chrome caps. This layer scrolls at the gameplay speed, and ground turrets sit on it.
3. **Haze layer.** Semi-transparent pink and orange cloud wisps and holographic grid fragments drifting faster in front, for depth.

The **striped synthwave sun** appears on the title screen, in the level's intro shot (reflected in a mirrored plaza), and as the boss's core.

Base scroll speed: 30 px/s, speeding up to 60 px/s during the Highway Rush section.

### 7.2 Palette (master: all art uses only these colours)

| # | Name | Hex |
|---|---|---|
| 0 | Midnight | `#0D0221` |
| 1 | Deep purple | `#261447` |
| 2 | Grid violet | `#541388` |
| 3 | Electric violet | `#8C1EFF` |
| 4 | Lavender | `#B967FF` |
| 5 | Hot pink | `#FF2A6D` |
| 6 | Magenta | `#F222FF` |
| 7 | Sunset orange | `#FF6C11` |
| 8 | Sun yellow | `#FFD319` |
| 9 | Pale yellow | `#FFFB96` |
| 10 | Cyan | `#01CDFE` |
| 11 | Mint | `#05FFA1` |
| 12 | Chrome dark | `#3D3D5C` |
| 13 | Chrome mid | `#7A7AA8` |
| 14 | Chrome light | `#C8C8E8` |
| 15 | White | `#FFFFFF` |

**Readability rule:** enemy bullets are white-cored with a hot-pink or orange ring and a 1 px midnight outline. Player shots are cooler and partly transparent. Background layers stay in colours 0–4 and 12–13, at reduced brightness.

### 7.3 Timeline (~2:45 total)

| Time | Section | What happens |
|---|---|---|
| 0:00–0:06 | **Intro** | The ship flies up from the bottom. "STAGE 1 — NEON DRIVE" in chrome text. The sun reflects in the plaza. No enemies. |
| 0:06–0:40 | **A. Outskirts** | Teaches movement and the chain. Glitch drone V-formations from the top and sides. First Strobe divers at 0:20. Weapon carriers at 0:14 and 0:27. |
| 0:40–1:15 | **B. Downtown** | Rooftop turrets appear (they scroll with the city, so you have to kill them before they reach the bottom). Hover cars cross in lanes. Carriers at 0:45 and 1:00. **PRISMs appear from 0:55.** Density goes up. |
| 1:15–1:35 | **Mid-boss: SUBWOOFER** | An armoured tank rolls down the highway, firing beat-synced rings. The scroll slows while it's alive. |
| 1:35–2:00 | **C. Highway Rush** | The scroll speeds up and the music shifts up a gear. Fast mixed waves: hover-car convoys and Strobe divers. **EQUALIZERs appear** (1:21, 1:31), along with more PRISMs. Carriers at 1:25 and 1:36. |
| 2:00–2:06 | **Warning** | The screen tints red. "⚠ WARNING — TITAN APPROACHING ⚠" over a siren synth. Remaining bullets fade out. |
| 2:06–~2:45 | **Boss: HELIOS** | See §9. |
| End | **Results** | Score tally, then the rank. |

The level is data-driven (a timeline file listing time, enemy type, formation, path and drop), so timings can be tweaked without code changes.

---

## 8. Level 1 enemies

| Enemy | Size | HP | Base pts | Movement | Attack |
|---|---|---|---|---|---|
| **Glitch** (drone) | 12×12 | 3 | 100 | Arrives in V and snake formations, curves through the screen, loops back up | Rarely fires (1 slow aimed shot, 20% chance) |
| **Strobe** (interceptor) | 16×16 | 10 | 300 | Dives from the top, brakes, hovers 2 s, retreats upward | Single aimed shot while hovering; at 1:35+ a 3-shot burst |
| **Rooftop turret** | 16×16 (ground) | 18 | 500 | Fixed to the city layer and scrolls with it | Aimed 3-shot burst every 2 s, telegraphed by a muzzle glow |
| **Hover car** | 20×12 | 12 | 400 | Crosses horizontally in lanes, leaves a light trail; slows mid-screen | Drops a 3-way downward fan mid-crossing |
| **Carrier "Bassline"** (gunship) | 32×28 | 70 | 2,000 | Slow descent to the upper third, strafes, leaves after 8 s | Rotating 6-way rings; **drops a weapon capsule** |
| **PRISM** (crystal gunship, late) | 22×24 | 90 | 1,500 | Descends, hovers with a slow sway, retreats after 3 volleys | Telegraphed glow, then 3 slow crystal shards that **burst into 6-bullet rings** after 0.9 s |
| **EQUALIZER** (heavy gunship, late) | 46×26 | 260 | 3,000 | Slow descent, wide sway, leaves after 9 s | Fan-shaped curtain from its five EQ bars, firing for 1.4 s in every 2.2 s. **A two-bar gap walks across the curtain**, and that's where you dodge. |
| **Mid-boss SUBWOOFER** (tank) | 48×48 | 1,100 | 10,000 | Rolls down the highway, stops, pulses | Expanding 16-bullet rings **on the music's beat**, with aimed shots between them |

Escape rule: enemies that leave (Strobe retreating, carrier leaving, hover cars exiting) must have enough time on screen to be killed, and leaving breaks the chain.

---

## 9. Boss: **TITAN-01 HELIOS**

A colossal chrome mech rising from behind the skyline. It fills the top ~40% of the screen (≈ 150 × 110 px), with a **striped synthwave sun as its chest core**. Its armour plating glows with neon circuitry.

**Parts:** left arm cannon (350 HP), right arm cannon (350 HP), core (1,800 HP; can only be hit once the chest opens). Destroying an arm adds to the chain and gives 5,000 × multiplier. All HELIOS bullets fly at 1.15× the base enemy bullet speeds (`HELIOS_BULLET_SPEED`).

| Phase | Trigger | Pattern |
|---|---|---|
| **1 — Arms** | Start | The arms take turns firing aimed 5-way fans. Shoulder pods launch slow homing "notes" (destructible, 4 HP, +1 chain each). The body slowly sways side to side. |
| **2 — Sun Core** | Both arms destroyed (or 35 s pass) | The chest plates open to reveal the sun core. A **double spiral** of bullets (two arms, rotating) with an aimed 3-shot volley every 2 s. |
| **3 — Supernova** | Core below 40% | The core overheats (the stripes flash). A **sweeping sun beam**: a thin 1 s telegraph line, then a thick beam sweeping across the screen. Between sweeps, alternating ring bursts and a rain of falling bullets. |
| **Death** | Core at 0 | Chain-reaction explosions, a screen flash, all bullets turn into bonus points, and the music cuts to a reverb tail. Then results. |

Expected fight length is ~40–50 s at weapon level 2–3. There is no timeout.

---

## 10. Presentation

### 10.1 HUD (top strip, ~18 px, over the playfield)
- Left: **score** (chrome digits).
- Centre: **CHAIN 47 ×5.7**, which pulses on each kill and shatters when broken.
- Right: pause button.
- Bottom-left (small): **shield pips**, plus the **weapon icon with its level**.
- Bottom-right (small): **bomb icons** and **lives**.
- Boss HP bar slides in under the top strip during boss fights.

### 10.2 Juice
- Hit flash (an enemy turns white for 1 frame) and pixel-shard explosions in palette colours.
- Small screen shake on big kills and hits. A brief freeze frame (60 ms) on boss part destruction.
- Optional CRT scanline overlay (on by default, can be turned off).
- Score popups at the kill location, tinted by multiplier.

### 10.3 Screen flow (first build)
**Title** (logo, striped sun, START button, CONTROLS toggle) → **Level 1** → **Results** → back to Title.
**Pause menu:** Resume / Music volume / SFX volume / Vibration on/off / Scanlines on/off / Quit to title.
Save data (`user://save.cfg`): unlocked levels, best score per level, settings.

---

## 11. Art & audio pipeline (placeholder, generated)

All placeholder assets are **generated by scripts in the repo**, so anyone can regenerate or tweak them:

- **Sprites:** `tools/gen_sprites.py` draws each sprite from ASCII pixel maps using the §7.2 palette and writes PNGs plus sprite sheets (animation frames: ship exhaust, enemy blink, explosions). Hand-drawn art can later replace any PNG with the same name and size.
- **Backgrounds:** procedurally generated tileable layers (grid floor, city blocks, haze).
- **SFX:** a sfxr-style synth script renders `.wav` files: player shot (per weapon), enemy shot, hit, explosion (small/large), pickup, bomb, chain-lost sting, warning siren.
- **Music:** a script renders looping synthwave tracks to `.ogg`: arpeggiated bass, gated pads, gated-reverb snare.
  - *Neon Drive* (stage, ~110 BPM)
  - *Helios* (boss, ~124 BPM)
  - Title jingle

  These are placeholder quality, but on-style. SUBWOOFER's bullet rings sync to the stage track's BPM.

---

## 12. Architecture sketch (Godot)

```
project.godot            270x480, viewport stretch, nearest filter, portrait
scenes/
  main.tscn              state machine: Title → Game → Results
  game/game.tscn         playfield, parallax, spawner, HUD, pause
  player/player.tscn
  enemies/*.tscn         one scene per enemy type, sharing Enemy base script
  bosses/helios.tscn     multi-part boss with phase state machine
  ui/*.tscn              title, hud, pause, results
scripts/
  tuning.gd              ALL gameplay constants in one autoload
  bullet_manager.gd      pooled bullets drawn in batches; circle-vs-hitbox collision (no per-bullet nodes)
  patterns.gd            fan, ring, spiral, aimed burst, sweep emitters
  level_runner.gd        reads levels/level1.json timeline, spawns waves, controls scroll speed
  score.gd               chain/multiplier/score/rank
  input_router.gd        primary finger → steering; extra touches → bomb
  save.gd
levels/level1.json       the level timeline (data, not code)
tools/                   asset generator scripts (Python)
.github/workflows/android.yml   export debug APK → artifact
```

---

## 13. Open questions (for after the first playtest)

1. **Finger occlusion.** The ship sits directly under the finger (offset 0). Keep it there, or move to a ~24 px offset?
2. **Chain strictness.** Is "any escapee breaks the chain" fun at this density, or should we add a short grace (e.g. 1 escape forgiven per section)?
3. **Capsule colour cycling.** Does it work as the way to choose a weapon, or would fixed-colour drops be better?
4. **Difficulty.** There's a single difficulty for now. Should we add Easy/Hard later (bullet speed and density scaling)?
5. **Levels 2–5 themes** (to decide later), e.g. Synth Ocean, Chrome Desert, Orbital Highway, the Titan Forge.

---

## 14. Build status (v0.1, Level 1 prototype)

Level 1 is fully implemented as described above. Known differences from this document:

- **Letterbox:** the bars on phones taller than 9:16 are plain black for now (no scanline/grid frame yet).
- **Intro:** no mirrored-plaza sun reflection. The striped sun appears on the title screen and as HELIOS's core.
- **Highway Rush music:** the music does not shift up a gear yet. The section speeds up the scroll and announces itself with a banner.
- **Audio:** all SFX and music are synthesised placeholders (`tools/gen_audio.py`).
- **Art:** all sprites are generated placeholders (`tools/gen_sprites.py`).

