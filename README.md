# Titanus

A vertical-scrolling synthwave shmup for Android, built with Godot 4.7 (GDScript).
Design: [docs/DESIGN.md](docs/DESIGN.md).

## Play

Press **START** on the title screen. The **CONTROLS** button below it switches between two schemes (also in the pause menu):

| | Touch | Tilt |
|---|---|---|
| Steer | Drag one finger; the ship chases it (speed-capped) | Tilt the phone like rolling a marble: lower the right edge to go right, tip the top away to go up |
| Bomb | Tap with a second finger | Tap anywhere |

- **Fire:** automatic in both schemes.
- **Pause:** the top-right button or the Android Back button.
- **Tilt neutral:** whatever angle you hold the phone at when you press START (or resume from pause) counts as neutral.
- **Tilt settings** (pause menu): sensitivity (LOW / MED / HIGH) and invert Y.

Desktop testing:

- The mouse acts as the steering finger, and arrow keys / WASD move the ship.
- `Enter` starts the game and `C` toggles the control scheme on the title screen.
- `B`/`Space` bombs and `P`/`Esc` pauses.

## Get the APK

Every push runs the **Android build** workflow (`.github/workflows/android.yml`). It:

1. imports the project,
2. runs a headless smoke test in which an invulnerable autopilot plays all of Level 1,
3. exports a debug-signed APK.

Download it from the run's **Artifacts** (`titanus-debug-apk`). Pushing a `v*` tag also attaches the APK to a GitHub release.

## Develop

| Task | Command |
|---|---|
| Regenerate sprites, font, backgrounds and icons | `python3 tools/gen_sprites.py` (needs Pillow) |
| Regenerate SFX and music | `python3 tools/gen_audio.py` (needs numpy and ffmpeg with libvorbis) |
| Smoke test | `godot --headless --fixed-fps 60 -- --autotest [--weapon=vulcan\|laser\|wave] [--controls=tilt]` |
| Screenshots of a full run | `godot --fixed-fps 60 -- --autotest --shots=/some/dir` |

Where to change things:

- Gameplay constants: `scripts/core/tun.gd`.
- Level timeline (what spawns, when and where): `levels/level1.json`.
- Art: any generated PNG can be replaced with hand-drawn art of the same name and size.
