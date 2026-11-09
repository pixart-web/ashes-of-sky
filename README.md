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

The current sprint integrates playable flight, the Valley of Ash traversal loop, discovery, ground exploration, and the first lightweight aerial combat prototype. RPG progression remains intentionally out of scope.

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
| Skip opening | Enter | North face button |
| Land / Take off | L | East face button |
| Ground movement | W / A / S / D | Left stick |
| Ground run | Shift | South face button |
| Ground interact / Mount | E | West face button |

Lunaris always maintains a minimum forward speed. Releasing accelerate or boost returns the creature gradually toward cruise speed. Manual camera look returns naturally to the chase view after a short delay. The current altitude telemetry uses world-space Y rather than terrain-relative height.

Flight presentation uses procedural Godot particles and placeholder geometry only. A speed-driven wind audio channel is prepared, but intentionally has no sound asset until suitable original audio is approved.

## First Flight opening

The main scene now begins with the handcrafted First Flight sequence. It moves from the Elyndra/Silence introduction through Lunaris's cliff leap and freefall into the existing flight controller without loading another scene. Set `play_opening_on_start` on `FirstFlightSequence` to `false` for a direct development start. Its optional timeline overlay reports the current opening state, elapsed sequence time, and control status, and is disabled by default.

The sequence exposes event hooks for ambient wind, distant environmental rumble, Lunaris movement, wing deployment, title reveal, and gameplay handoff. No production audio files are included yet; the opening remains fully functional when played silently.

## Sacred Ash art target

The Starting Cliff, open Central Canyon, Valley vista, and Spire use the **Sacred Ash** in-engine art target: dark ceremonial Architect stone, aged metal, restrained ash and rock tones, warm low sunlight, cool shadows, distance haze, and rare cyan active technology. A lightweight procedural kit supplies eight reusable forms: monumental arch, vertical blade, broken wall, Divided Halo, ceremonial pillar, collapsed monument, fly-through gate, and Spire module. The **Divided Halo** remains the primary Architect symbol. All geometry, materials, sky, fog, glow, and particles are Godot-native placeholders; no textures, HDRIs, plugins, or external production assets are included.

Development comparison controls are disabled from normal UI:

| Action | Key |
| --- | --- |
| Clean screenshot mode | F6 |
| Toggle `SacredAshArtTargetCamera` | F9 |
| Toggle fog | F10 |
| Toggle Starting Cliff ash particles | F11 |
| Highlight cyan emission | F12 |

The art overlay has no collision and uses shared primitive meshes/materials. Starting Cliff ash is limited to 28 small, slow, horizontal-drifting, low-opacity particles. The comparison camera never activates automatically and does not interfere with the First Flight or chase cameras.

## Lunaris visual lab

Open `res://art/lunaris/lunaris_visual_lab.tscn` to review the current creature anatomy. Use **1–5** for the standard cameras, **Z/X/C/V** for folded, glide, full-spread, and flap-test poses, **R** to toggle Kael, **B** for the single-material silhouette review, and **Space** for turntable rotation. Each wing uses four articulated structural sections and three broad membrane regions.

## Valley of Ash prototype

The world pass is organized into replaceable regions: Starting Cliff, Central Canyon, Ash Basin, Broken Plateau, Ruin Field, Ancient Gate, The Spire, and Lost Places. The Spire is intentionally unmarked so visual navigation can be tested.

The debug HUD can display the current region, world position, and distance to The Spire. Set `show_world_navigation` on the HUD telemetry node to `false` to hide those development readouts. Travelling beyond the distant natural boundary or extreme altitude resets Lunaris to the Starting Cliff; this is a temporary prototype safeguard rather than a final world boundary.

## Discovery prototype

Regions, landmarks, Lost Places, Echoes, and Anomalies use stable discovery IDs and persist for the current session. Automatic discoveries use spatial volumes; Echoes require the semantic `interact` action. The Journal lists only recovered knowledge and safely pauses flight while open.

Press **F8** during development to reset session discoveries for repeated first-discovery testing. This debug action awards no XP, loot, money, or other progression.

## Silent Chamber ground prototype

The Silent Chamber supports the complete flight-to-ground loop. Landing is available only over its sheltered western platform when Lunaris is below 18 m/s, low, and aligned toward the entrance. After the procedural landing and dismount, Kael uses the existing interaction and Journal systems. Return to the left side of Lunaris and press **E** to mount, then **L** or **E** to take off.

For rapid development, press **F7** to start directly at `SILENT CHAMBER — GROUND`. Press **F5** to recover Kael to the chamber entrance if the ground prototype becomes invalid. These shortcuts do not alter normal game startup.

## Aerial combat prototype

The Ash Basin contains the Ash Warden, initially dormant until The Last Signal changes the Valley. Combat preserves normal Lunaris flight. Use **Tab** to lock the target, **Left Mouse** for Pulse, hold/release **F** for Focus, and **Q/E** to evade left/right. On gamepad, use **L3**, **R1**, **L1**, and **D-pad left/right** respectively. Open `res://combat/test/aerial_combat_lab.tscn` for direct iteration without replaying First Flight. Combat adds no progression, loot, equipment, or ground attacks.

## Prologue gameplay loop

The main scene now connects First Flight, free discovery, the Silent Chamber, The Last Signal, the awakened Ash Warden, and the Spire aftermath without changing scenes. Guidance remains environmental: there are no objective arrows, mission checklists, XP, loot, or equipment rewards. The Journal gains a concise **Threads** section only after The Last Signal is recovered.

Development-only shortcuts are intentionally absent from normal UI:

| Shortcut | Prologue state |
| --- | --- |
| Ctrl+0 | Reset Prologue state |
| Ctrl+1 | Start after First Flight |
| Ctrl+2 | Start at Silent Chamber |
| Ctrl+3 | Start after Last Signal |
| Ctrl+4 | Start at Warden |
| Ctrl+5 | Start after Warden |

## Master Build 01 — Chapter I

The approved Prologue now continues into one uninterrupted Chapter I: First Resonance, a Stage 1 Lunaris tendency, the aerial approach and landing at the Spire, its open ground sanctum, a three-resonator light-path puzzle, the Resonance Vault, the Pale Reach, two Ash Skimmer encounters, and the three-phase Veiled Sentinel. The aftermath introduces **THE SKY BELOW** and leaves the player in control. The chapter contains no quest arrows, loot, economy, inventory, ground combat, or scene transition during normal play.

First Resonance offers four non-exclusive long-term tendencies: **Predator** (Pulse momentum), **Guardian** (defensive stability), **Oracle** (Focus efficiency), and **Wraith** (mobility). MB01 stores four independent affinity values so later hybrid evolution remains possible.

The front end provides **Continue**, **New Journey**, **Settings**, and **Quit**. `Esc` opens the pause menu. Saves are versioned JSON in the Godot user-data directory and autosave only after meaningful discoveries, world transitions, evolution choice, boss defeat, and chapter completion. Continue restores discoveries, Threads, evolution, world reactions, defeated bosses, settings, and a safe flight position.

Development-only navigation remains outside production UI:

| Shortcut | Chapter checkpoint |
| --- | --- |
| Ctrl+6 | First Resonance |
| Ctrl+7 | Spire exterior |
| Ctrl+8 | Spire ground |
| Ctrl+9 | Resonance Vault |
| Alt+1 | Pale Reach |
| Alt+2 | Veiled Sentinel |
| Alt+3 | Chapter complete |
| Ctrl+Shift+0 | Reset Chapter I state |
| Ctrl+Shift+9 | Delete local save |

The full primary playtest must start through **New Journey** and must not use these shortcuts.

## Repository layout

- `game/` — Godot project and game resources
- `docs/gdd/` — canonical game-design documentation
- `docs/technical/` — architecture and contributor rules
- `docs/production/` — sprint planning

## Originality

Ashes of the Sky is an original IP. Inspirations may inform broad emotional or gameplay goals, but no third-party characters, lore, designs, levels, symbols, music, dialogue, textures, models, code, story elements, or copyrighted assets may be reproduced.

