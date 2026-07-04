# godot-demo

A blank **Godot 4.x** starter project.

## Requirements

- [Godot 4.3](https://godotengine.org/download) or newer (Forward+ renderer).

## Open the project

1. Launch Godot 4.x.
2. Click **Import**, select `project.godot` at the repo root, and open it.
3. Press **F5** (or the ▶ button) to run. You should see a centered label
   confirming the starter is running. **Esc** quits.

## Layout

```
.
├── project.godot        # Project configuration (main scene, input map, display)
├── icon.svg             # Project/window icon
├── scenes/
│   └── main.tscn        # Main scene (set as run/main_scene)
└── scripts/
    └── main.gd          # Script attached to the Main node
```

## Input map

Pre-wired actions in `project.godot` so you can start building movement right away:

| Action         | Key |
|----------------|-----|
| `move_forward` | W   |
| `move_back`    | S   |
| `move_left`    | A   |
| `move_right`   | D   |
| `ui_cancel`    | Esc |

## Next steps

Build your game out from `scenes/main.tscn` and `scripts/main.gd`.
