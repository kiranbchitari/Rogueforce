# ROGUEFORCE

A multi-world 2D run-and-gun built in **Godot 4.7**. Worlds, enemies, bosses and
missions are data (`.tres` resources plus ASCII layouts), so new content
rarely needs new code. The jungle is one world among many.

## Run it

```bash
godot --path .
```

Or open `project.godot` in the Godot editor and press F5.

| Action | Keyboard | Gamepad |
|---|---|---|
| Move / aim (8 directions) | A D W S or arrow keys | Left stick / d-pad |
| Jump (hold for higher) | Space, K, Z | A |
| Shoot (hold) | J, X | X, RB |
| Crouch / drop through platform | Down / Down + Jump | |
| Pause | Esc, P | Start |
| Fullscreen (use this on a 4K TV) | F11, Alt+Enter | |
| Toggle placeholder asset labels | F3 | |

## Tests

```bash
godot --headless --path . -s res://tests/compile_all.gd              # every script and resource loads
godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn # plays every mission end to end
godot --path . --fixed-fps 60 res://tests/capture.tscn               # screenshots to user://captures (opens a window)
```

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): how the systems fit together.
- [docs/ADDING_CONTENT.md](docs/ADDING_CONTENT.md): add a world, an enemy, a boss, a mission.
- [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md): bring in Gemini-generated art.
- [docs/STATUS.md](docs/STATUS.md): what is implemented and what is planned.
