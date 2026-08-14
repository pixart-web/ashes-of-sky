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

Pre-production / Flight Prototype.

The current sprint is focused on preparing a small, readable test space for the first playable flight controller. Combat is intentionally out of scope.

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

The scene is intentionally static during AOTS-001. It contains a primitive test environment, a placeholder Lunaris, and debug telemetry ready for the flight prototype.

From a terminal with Godot available on `PATH`, the project can also be started with:

```text
godot --path game
```

## Repository layout

- `game/` — Godot project and game resources
- `docs/gdd/` — canonical game-design documentation
- `docs/technical/` — architecture and contributor rules
- `docs/production/` — sprint planning

## Originality

Ashes of the Sky is an original IP. Inspirations may inform broad emotional or gameplay goals, but no third-party characters, lore, designs, levels, symbols, music, dialogue, textures, models, code, story elements, or copyrighted assets may be reproduced.

