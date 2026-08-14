# Technical Architecture

## Approach

The initial architecture is intentionally small and organized by responsibility. AOTS-001 supplies only a runnable test scene, placeholder geometry, and telemetry. It does not introduce a gameplay framework or flight controller.

```text
game/
├── project.godot
├── actors/
│   ├── kael/
│   ├── lunaris/
│   └── enemies/
├── world/
│   ├── environments/
│   └── test/
├── systems/
├── combat/
├── ui/
├── audio/
└── tests/
```

## Directory responsibilities

### `actors/`

Contains actor-specific scenes, scripts, resources, and presentation components.

- `kael/` — the player character outside or alongside flight.
- `lunaris/` — Lunaris composition, flight behaviour, and evolution-facing components.
- `enemies/` — reusable enemy actor scenes and behaviour.

### `world/`

Contains world presentation and playable spaces.

- `environments/` — reusable environmental scenes, materials, and region components.
- `test/` — focused developer scenes such as the flight test environment.

### `systems/`

Contains cross-cutting gameplay systems only when a real requirement justifies them. Examples might eventually include progression or save handling; none are created pre-emptively.

### `combat/`

Reserved for aerial-combat-specific rules and resources. Combat is not part of Sprint 001.

### `ui/`

Contains user interface scenes and scripts. The initial debug HUD lives here so telemetry remains separate from flight logic.

### `audio/`

Contains audio resources and playback components. No production audio is included in the bootstrap.

### `tests/`

Contains automated or repeatable validation resources for the Godot project.

## Evolution

This structure is a starting point, not a permanent contract. It may evolve when implemented features reveal concrete requirements. Changes should be motivated by current code and remain small and reviewable.

