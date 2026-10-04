# Passenger Bus HUD and Trailer Collision Fix — Design

Date: 2026-10-04  
Target game: Euro Truck Simulator 2 1.59

## Context

The existing Grandbird Optical HUD addon works, but its display needs to move toward the driver's side and become slightly clearer. The same HUD experience is also wanted on the installed Kim Long 99 and Thaco Mobihome bus mods. Passenger jobs use invisible trailers which can intermittently collide with their master bus during sharp articulation.

The installed vehicle archives under `C:\Users\TrầnChíVỹ\Documents\Euro Truck Simulator 2\mod` are read-only inputs. No file in that directory will be edited, deleted, renamed, or used as an output target. Inspection data and generated packages remain under `C:\Users\TrầnChíVỹ\Desktop\ets`.

## Goals

Produce two independent `.scs` packages:

1. `PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs`
2. `PASSENGER_TRAILER_COLLISION_FIX_1.59.scs`

The HUD package provides a windshield-projected navigation display with current speed for the selected passenger buses. The trailer package prevents the two known invisible passenger-trailer families from colliding with their master bus at normal articulation angles.

## Non-goals

- Do not modify or repackage any original vehicle mod.
- Do not support cargo trucks, including Hino, Hyundai Trago, or Isuzu.
- Do not replace the buses' original dashboard or infotainment GPS.
- Do not remove trailer collision with roads, scenery, or traffic.
- Do not claim guaranteed Kim Long trailer compatibility while its locked archive prevents identification of its trailer definition.

## Supported HUD vehicles

| Vehicle family | Internal truck ID | Accessory slot | Model family |
| --- | --- | --- | --- |
| Kia Grandbird | `granbird.23` | `set_lglass` | Kia |
| Kim Long 99 | `kimlong.99` | `set_lglass` | Kim Long |
| Thaco Mobihome 2024 | `thaco.mbh.23` | `set_lglass` | Thaco |
| Thaco Mobihome 2025 | `thaco.mbh.25` | `set_lglass` | Thaco |
| Thaco Mobihome 2015–2016 | `man.tgx.sample` | `set_lglass` | Thaco |

The Kim Long internal ID and `set_lglass` slot were recovered from readable index strings in its locked `AEM!` archive. Its full definitions and model geometry cannot be extracted with the available official SCS tool.

## HUD package design

### Contents

The package is self-contained and supplies:

- shared Optical HUD UI definitions;
- shared drawable texture and menu icon assets;
- compiled PMD/PMG projection surfaces;
- one set of accessory definitions per supported internal truck ID;
- Normal, Large, and Extra Large choices for every supported bus.

### Placement and rendering

The existing projection geometry is translated `0.65 m` along model-space `-X`, moving it toward the driver's side. Its Y and Z coordinates, orientation, and UV layout remain unchanged. The UI drawable increases from `512 × 512` to `1024 × 1024`. Secondary white text changes from partial alpha to full alpha, while the route map and primary colors retain their existing design.

Kia, Kim Long, and Thaco use separate internal model paths even when their initial geometry is identical. This permits later per-family placement correction without changing the other buses.

### UI data

The projected UI includes:

- navigation map;
- current speed (`1020`);
- cruise-control speed;
- speed limit (`1610`);
- rest time;
- estimated remaining trip time.

The package uses a unique drawable texture path so it does not overwrite a bus mod's original dashboard or GPS drawable.

### Loading behavior

The addon must have higher Mod Manager priority than the supported bus mods. A player installs one HUD size through the `set_lglass` interior accessory point. Existing trucks do not need to be repurchased.

If a vehicle update removes or renames `set_lglass`, only that vehicle's HUD item will disappear; other supported buses and their stock screens remain unaffected.

## Trailer collision-fix package design

### Covered definitions

The package overrides the two shared chassis definition paths found across the inspected Kia and Thaco bus archives:

- `/def/vehicle/trailer_owned/passenger/chassis/chassis.sii`
- `/def/vehicle/trailer_owned/crsthn.t_passag/chassis/chassis.sii`

Both definitions retain their invisible model, `.pmc` collision, wheels, suspension, mass, center-of-gravity values, sounds, and incompatibility includes. The fix adds only:

```sii
master_collision_angle: 180
```

The package uses the common definition variant present in the majority of the inspected bus archives. This includes the existing `crsthn_pneu.sii` default tire entry; the older Thaco 2015–2016 copy omits that one default but is otherwise equivalent.

### Expected effect

The invisible trailer continues colliding with the world, but collision with its master vehicle is not enabled during ordinary articulation. No yaw constraint is introduced in the first release, keeping the change limited to the suspected self-collision mechanism.

The fix applies to Kim Long only if that locked mod uses one of the two covered definition paths. A different private trailer definition will require separate evidence before another override is added.

### Loading behavior

The fix addon must have higher Mod Manager priority than the bus mods. Testing should use a newly spawned passenger job or trailer so the corrected chassis definition is loaded into a fresh vehicle chain.

## Validation strategy

### Automated checks

Before production changes, tests must fail against the current package for the new requirements. After implementation they must verify:

- all five supported truck IDs have three HUD definitions under `set_lglass`;
- all unit names are unique and valid;
- HUD drawable size is exactly `1024 × 1024`;
- UI contains map, current-speed ID `1020`, and speed-limit ID `1610`;
- compiled PMD/PMG files and converted materials exist for all three model families and sizes;
- model-space X coordinates are translated by `-0.65 m`, with Y and Z unchanged;
- trailer override files preserve the baseline chassis fields and add `master_collision_angle: 180`;
- manifests declare `1.59.*` compatibility;
- final archives contain forward-slash paths, no duplicate entries, no intermediate PIM/PIT sources, and can be fully decompressed;
- neither package contains an original vehicle archive or cargo-truck compatibility definition.

### In-game acceptance

Because ETS2 is not available in the build environment, the user performs the final visual and physics checks:

1. On each supported bus, verify that all three HUD sizes appear and the chosen HUD is visible toward the driver's side.
2. Verify that map, current speed, and speed limit remain legible at night and in rain.
3. Start a new passenger job, drive over uneven roads, and make tight turns without the invisible trailer striking the bus.
4. If one bus has a different cabin origin, provide a screenshot so only that family model is repositioned.

## Deliverables

Only these two installable artifacts are deliverables:

- `PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs`
- `PASSENGER_TRAILER_COLLISION_FIX_1.59.scs`

Build folders, extracted inspection data, tests, and conversion tools remain outside the game's mod directory.
