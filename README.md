# Ashes of the Sky

**Ashes of the Sky** is an original story-driven aerial RPG set in a mysterious ancient world.

The core experience combines:

- aerial exploration;
- discovery-driven storytelling;
- strategic aerial combat;
- a relationship with Lunaris, an evolving flying creature.

## Technology

- Godot 4.x
- GDScript
- Git / GitHub
- PC as the first target platform

## Current phase

Pre-production / Valley of Ash World Prototype.

The current sprint combines playable flight, a comfortable chase camera, lightweight speed presentation, and the first explorable Valley of Ash world-layout prototype. Combat is intentionally out of scope.

## Development principle

> Build one system, test it, improve it, then integrate it.

Do not build multiple major gameplay systems simultaneously.

## Requirements

- A stable Godot 4.x release
- A desktop system capable of running Godot's Compatibility renderer

No third-party plugins or external production assets are required.

## Open and run

1. Open Godot Project Manager.
2. Select **Import** and choose `game/project.godot`.
3. Open the project.
4. Press **F6** while `flight_test.tscn` is open, or **F5** to run the configured main scene.

The scene contains the 1.5–2 km Valley of Ash prototype, a playable Lunaris placeholder, and optional live flight/world telemetry.

From a terminal with Godot available on `PATH`, the project can also be started with:

```text
godot --path game
```

## Flight controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Accelerate | W | Right trigger |
| Decelerate | S | Left trigger |
| Yaw | A / D | Left stick X |
| Pitch | Up / Down arrows | Left stick Y |
| Boost | Shift | South face button |
| Camera look | Hold right mouse button and move | Right stick |
| Recenter camera | C | Right stick click |
| Exploration Journal | J | Back / Select button |

Lunaris always maintains a minimum forward speed. Releasing accelerate or boost returns the creature gradually toward cruise speed. Manual camera look returns naturally to the chase view after a short delay. The current altitude telemetry uses world-space Y rather than terrain-relative height.

Flight presentation uses procedural Godot particles and placeholder geometry only. A speed-driven wind audio channel is prepared, but intentionally has no sound asset until suitable original audio is approved.

## Valley of Ash prototype

The world pass is organized into replaceable regions: Starting Cliff, Central Canyon, Ash Basin, Broken Plateau, Ruin Field, Ancient Gate, The Spire, and Lost Places. The Spire is intentionally unmarked so visual navigation can be tested.

The debug HUD can display the current region, world position, and distance to The Spire. Set `show_world_navigation` on the HUD telemetry node to `false` to hide those development readouts. Travelling beyond the distant natural boundary or extreme altitude resets Lunaris to the Starting Cliff; this is a temporary prototype safeguard rather than a final world boundary.

## Discovery prototype

Regions, landmarks, Lost Places, Echoes, and Anomalies use stable discovery IDs and persist for the current session. Automatic discoveries use spatial volumes; Echoes require the semantic `interact` action. The Journal lists only recovered knowledge and safely pauses flight while open.

Press **F8** during development to reset session discoveries for repeated first-discovery testing. This debug action awards no XP, loot, money, or other progression.

## Repository layout

- `game/` — Godot project and game resources
- `docs/gdd/` — canonical game-design documentation
- `docs/technical/` — architecture and contributor rules
- `docs/production/` — sprint planning

## Originality

Ashes of the Sky is an original IP. Inspirations may inform broad emotional or gameplay goals, but no third-party characters, lore, designs, levels, symbols, music, dialogue, textures, models, code, story elements, or copyrighted assets may be reproduced.

