# BackroomsInfinite (Godot)

A playable first slice of [BackroomsInfinite](https://github.com/myearian/BackroomsInfinite) in **Godot 4.3** (Forward+). Infinite yellow rooms, fluorescent lights, fog, dark zones, and keyboard-only FPS controls.

This is **not** a 1:1 clone of every JS system. See [Shipped vs still JS-only](#shipped-vs-still-js-only).

## Requirements

- [Godot 4.3](https://godotengine.org/download) with the Forward+ renderer. 4.3 is the target; later 4.x may work.

## Open in Godot 4.3

1. Install Godot 4.3.
2. Launch Godot → **Import** → select `project.godot` at the repo root → Open.
3. Press **F5** (or the ▶ button) to play.
4. **Esc** quits.

No extra assets or export templates are required. Wallpaper, carpet, ceiling tiles, and the ambient hum are generated at runtime.

## Controls

| Action | Key |
|--------|-----|
| Move | WASD |
| Look | Arrow keys (no mouse) |
| Flashlight | F |
| Crouch (slide under tables) | C (hold) |
| Quit | Esc |

## What this slice is

You spawn in a lit ring of 9 m tiled rooms. Walls, doorways, and openings are deterministic; rare 5×5 blocks become big empty rooms. Occasional pillars and tables (with chairs / dead consoles) dress the space. Walk forever: chunks stream in around you. Some 3×3 clumps are dark; some fixtures flicker. Fog eats the far rooms.

## Shipped vs still JS-only

**In this Godot project**

- 3D `CharacterBody3D` player + `Camera3D` (was a blank Node2D starter)
- WASD move, arrow-key look, Esc quit
- Infinite deterministic chunked 9 m rooms (open / doorway / wall)
- Rare big empty rooms, occasional pillars, tables and chairs as set dressing
- Procedural wallpaper, stained carpet, ceiling tiles (no art packs)
- Fluorescent ceiling panels, pooled omni-lights (~30), dark zones, flicker
- Collision vs walls, doorway posts, pillars, and table tops
- Depth fog (~16–42 m), fluorescent palette, eye height 1.65 m
- Flashlight (F), crouch under tables (C), looping ambient hum

**Still JS-only (deferred)**

- Monster / creature AI and silhouette
- Poolrooms (level 2)
- Centipede
- Puzzle terminals
- Rift / no-clip
- CRT / VHS post-process
- Screen-space reflections and the three.js bloom/composer stack

## Layout

```
.
├── project.godot          # Godot 4.3 Forward+ config, input map, main scene
├── icon.svg
├── README.md
├── scenes/
│   ├── main.tscn          # Node3D run scene (WorldEnvironment, chunks, player)
│   └── player.tscn        # CharacterBody3D + Camera3D + flashlight
└── scripts/
    ├── main.gd            # Environment, streamer tick, HUD fade
    ├── player.gd          # WASD / arrows / crouch / flashlight
    ├── world_gen.gd       # Hash, edges, pillars, tables, dark zones
    ├── proc_materials.gd  # Runtime wallpaper / carpet / ceiling textures
    ├── chunk_world.gd     # Chunk streamer, collision, light pool
    └── ambient_hum.gd     # Procedural fluorescent bed loop
```

## Credits

Core Backrooms loop ported from `myearian/BackroomsInfinite` (`src/main.js` world, lighting, player feel). The live JS game is the source of truth; its README still mentions spiders — the Godot slice does not include a monster.
