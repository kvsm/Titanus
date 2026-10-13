# Titanus

A vertical-scrolling synthwave shmup for Android, built with Godot 4.7 (GDScript).
Design: [docs/DESIGN.md](docs/DESIGN.md).

## Play

- **Steer:** drag one finger; the ship chases it (speed-capped).
- **Fire:** automatic.
- **Bomb:** tap with a second finger while steering.
- **Pause:** top-right button or the Android back button.

Desktop testing: the mouse acts as the steering finger. `B`/`Space` bombs, `P`/`Esc` pauses.

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
| Smoke test | `godot --headless --fixed-fps 60 -- --autotest` |
| Screenshots of a full run | `godot --fixed-fps 60 -- --autotest --shots=/some/dir` |

Where to change things:

- Gameplay constants: `scripts/core/tun.gd`.
- Level timeline (what spawns, when and where): `levels/level1.json`.
- Art: any generated PNG can be replaced with hand-drawn art of the same name and size.
