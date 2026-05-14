# Stack Design — Space Xplorer

**Date:** 2026-05-14
**Status:** Approved
**Scope:** Full technology stack definition for initial development

---

## Project context

Space Xplorer is a solo-developed mobile game inspired by Star Citizen's philosophy of deep simulation and realism, adapted for mobile. It is not a 3D space sim — it is a **2D pseudo-3D space simulation** with Star Citizen's systemic depth, accessible in mobile session lengths.

Narrative influences: **Mass Effect** (authored story beats, characters with depth, meaningful choices) and **Dwarf Fortress** (emergent history generated from simulation — wars, collapses, discoveries become the story). The goal is a world that tells a directed epic while also generating its own history organically.

Key constraints:
- Solo developer, no prior game engine experience, strong TypeScript/JS background
- Android primary, iOS later
- Local-first, no real-time multiplayer
- MVP focus: ship control system and engine validation before building simulation depth

---

## 1. Engine & language

**Godot 4.3 LTS** + **GDScript (type-hinted)**

Godot's 2D pipeline is first-class, not a layer on top of a 3D engine. This matters for a game built entirely around 2D rendering with depth simulation. GDScript (Python-like, optional static typing) is the fastest on-ramp for an experienced developer with no engine background.

Type hints are used throughout:

```gdscript
var z_depth: float = 1000.0
var fuel: float = 100.0
```

C# is available as an escape hatch if a specific simulation loop proves too slow, but is not part of the default development path.

---

## 2. Pseudo-3D depth rendering

The game's visual identity. Every entity has a `z_depth: float` representing distance from the camera in world units. The renderer derives all visual properties from it:

```gdscript
screen_scale = BASE_SCALE / z_depth
screen_y     = world_y - (z_depth * PERSPECTIVE_FACTOR)
draw_order   = -z_depth   # farther entities drawn first
```

### Landing mechanic

The depth control input directly decreases `z_depth`. A planet begins as a small sprite and grows to fill the screen as the player descends. No 3D engine, no camera rig — just a float and a scale formula.

Controls during landing:
- **Left/Right/Up/Down**: X/Y position
- **Throttle**: forward thrust (momentum-based via RigidBody2D)
- **Depth control**: decreases/increases `z_depth` (approach/retreat)

### Parallax background

5–6 depth layers rendered via Godot's `ParallaxBackground`:

| Layer | Content | Parallax factor |
|-------|---------|----------------|
| 0 | Distant galaxy/nebula | 0.02 |
| 1 | Far star field | 0.05 |
| 2 | Near star field | 0.12 |
| 3 | Gas/dust clouds | 0.25 |
| 4 | Large background objects | 0.5 |
| 5 | Near debris/asteroids | 0.9 |

### Lighting

Each ship and planet sprite carries a normal map. A single directional `CanvasLight` (the star) provides surface shading. Ships appear volumetric at near-zero render cost. Normal maps are authored in Aseprite or Blender.

### Culling

Entities beyond `MAX_Z_DEPTH` threshold are hidden. Natural LOD with no additional code.

---

## 3. Simulation architecture

### Node & data structure

- **Autoloads (singletons)**: global systems that run independently of active scene — `Universe`, `Economy`, `Factions`, `SaveSystem` (+ `Chronicle` added in a future phase)
- **Resources** (`.tres`): all static data definitions — ship specs, item types, faction configs, planet templates. Tunable in the Godot inspector without code changes.
- **Node composition**: a ship is a `RigidBody2D` with child nodes (`ShipSystems`, `Cargo`, `Weapons`). No deep inheritance chains.
- **Signals**: decoupled communication between systems. Systems emit, others subscribe. No direct cross-system calls.

### Simulation tick loop

A dedicated `Timer` ticks every N seconds (configurable, default 10s), independent of the render loop. Each tick:

1. Economy recalculates supply/demand per station
2. NPC ships advance their current agenda (trade, patrol, flee)
3. Faction tensions adjust based on recent events
4. Universe events are evaluated and fired

The player participates in this loop as one actor among many — not the center of it. This produces the Star Citizen feeling of a world that exists without you.

### Core systems (MVP and beyond)

| System | MVP | Description |
|--------|-----|-------------|
| Ship control | Yes | Physics-based movement, depth simulation, fuel, hull |
| Universe | Yes | Procedural generation from seed, star map, travel |
| Economy | Yes | Supply/demand per station, commodity prices |
| Factions | Yes | Reputation per faction, affects prices and hostility |
| Missions | Yes | Dynamic job board generated from universe state |
| Chronicle | Future | History log, named NPC generation, emergent narrative |
| Story arcs | Future | Authored story templates populated by simulation state |

### Narrative pillar (future)

The Chronicle system will sit on top of the simulation, recording significant events (battles, trade collapses, faction wars, discoveries) and generating named characters from universe state. This creates a history that is both procedural (Dwarf Fortress) and a foundation for authored story beats (Mass Effect). Fully deferred until ship control and simulation loop are validated.

---

## 4. Persistence

Local-first. The universe is procedurally generated from a seed — only the **delta** from the generated baseline is stored.

### Save file structure

```
user://saves/
  slot_0/
    meta.json              ← save name, timestamp, playtime
    player.json            ← ship state, cargo, credits, z_depth position
    universe_delta.json    ← faction shifts, economy overrides, discovered locations
    chronicle.json         ← history log, named characters, events
  settings.cfg             ← Godot ConfigFile, controls + display preferences
```

- **Save triggers**: manual save + autosave on dock/land. No mid-flight saves (adds tension, simplifies state).
- **Serialization**: GDScript `JSON` + typed Resource classes. Human-readable, easy to debug.
- **Cloud save**: deferred. When ready, GodotFirebase plugin uploads/downloads `slot_0/` as a bundle. Estimated: one day of integration work.

---

## 5. Build & deployment

### Android (primary)

- Godot built-in Android export template
- Target: Android 8.0+ (API 26) — covers ~95% of active devices
- Output: signed APK or AAB for Play Store
- Dev testing: USB via `adb`, Godot remote debugger works over USB/wifi

### iOS (future)

- Same Godot project, different export template
- Exports to Xcode project
- Requires: Mac, Apple Developer account ($99/yr)
- No game code changes required

---

## 6. Dev tooling

| Tool | Role |
|------|------|
| Godot 4.3 editor | Scene editing, scripting, physics debugger, profiler, Android export |
| Git | Version control |
| VSCode + godot-tools extension | GDScript editing with better autocomplete |
| Aseprite | Pixel art sprites and normal map authoring |
| Kenney.nl assets | Prototyping placeholder art |
| Blender | Custom illustrated ships/planets if moving beyond pixel art |
| GodotFirebase (plugin) | Cloud save integration, deferred |

---

## 7. What is out of scope

- Real-time multiplayer (revisit post-launch)
- 3D rendering (pseudo-3D depth simulation is sufficient)
- Procedural narrative / Chronicle system (post-MVP)
- iOS build (post-Android validation)
- Cloud save (post-local save validation)
