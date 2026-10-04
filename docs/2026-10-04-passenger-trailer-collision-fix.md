# Passenger Trailer Collision Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one ETS2 1.59 addon that prevents the two known invisible passenger-trailer chassis families from colliding with their master bus during ordinary articulation.

**Architecture:** Two complete chassis overrides preserve the common inspected bus-mod configuration and add only `master_collision_angle: 180`. A validator compares each override with its extracted baseline after removing the one permitted property, ensuring the addon does not accidentally change model, world collision, wheels, suspension, mass, or center-of-gravity behavior.

**Tech Stack:** PowerShell 5.1, SII chassis definitions, ZIP-format `.scs` archive.

**Spec:** `docs/superpowers/specs/2026-10-04-passenger-bus-hud-trailer-fix-design.md`

## Global Constraints

- Target ETS2 version is exactly `1.59.*`.
- Treat `C:\Users\TrầnChíVỹ\Documents\Euro Truck Simulator 2\mod` as read-only.
- Cover only `passenger` and `crsthn.t_passag` trailer-owned chassis paths.
- Preserve `.pmc` collision with the world and every baseline chassis property.
- Add only `master_collision_angle: 180`; do not add a yaw limit or change mass/suspension.
- State that Kim Long coverage is conditional because its `AEM!` archive hides trailer definitions.
- The workspace is not a Git repository; each task ends with fresh validation evidence and SHA-256 checkpoint output instead of a commit.

## File Structure

- `tests/validate_passenger_trailer_fix.ps1` — baseline-diff and package validator.
- `build_passenger_trailer_fix/manifest.sii` — ETS2 1.59 metadata.
- `build_passenger_trailer_fix/description.txt` — priority, fresh-job, and Kim Long limitation notes.
- `build_passenger_trailer_fix/def/vehicle/trailer_owned/passenger/chassis/chassis.sii` — first override.
- `build_passenger_trailer_fix/def/vehicle/trailer_owned/crsthn.t_passag/chassis/chassis.sii` — second override.
- `PASSENGER_TRAILER_COLLISION_FIX_1.59.scs` — final deliverable.

## Review Focus

- Accidental world-collision removal: each override must retain the exact `trailer_invisivel.pmc` path; Task 2 checks it.
- Baseline drift: after removing `master_collision_angle`, normalized override content must equal the chosen common baseline; Task 2 performs the comparison.
- Overbroad scope: the archive must contain no truck definitions and no third trailer family; Task 3 checks exact entry paths.
- Load-order confusion: manifest/description must say to load above bus mods and spawn a fresh passenger job; Task 2 tests both instructions.
- Kim Long uncertainty: description must explicitly say coverage applies only when Kim Long uses a covered trailer family; Task 2 checks that statement.

---

### Task 1: Define the Trailer Fix Regression Test

**Files:**
- Create: `tests/validate_passenger_trailer_fix.ps1`
- Reference: `_vehicle_catalog/kia_granbird/def/vehicle/trailer_owned/passenger/chassis/chassis.sii`
- Reference: `_vehicle_catalog/kia_granbird/def/vehicle/trailer_owned/crsthn.t_passag/chassis/chassis.sii`

**Interfaces:**
- Consumes: `-Path <directory-or-zip-scs>` and `-BaselineRoot <extracted-mod-root>`.
- Produces: exit code `0` only when the package contains the exact two safe overrides and required metadata.

- [ ] **Step 1: Write the validator**

Require exact definition paths and unit names `chs.passenger.chassis` and `chs.crsthn.t_passag.chassis`. Assert exactly one `master_collision_angle: 180` in each, retained `trailer_invisivel.pmc`, retained two axle/suspension entries, retained mass and COG fields, `1.59.*` manifest compatibility, priority/fresh-job instructions, and conditional Kim Long wording.

- [ ] **Step 2: Add normalized baseline comparison**

Normalize line endings and insignificant trailing whitespace. Remove only the `master_collision_angle: 180` line from each candidate and assert the remaining text equals the corresponding common Kia baseline.

- [ ] **Step 3: Verify RED before creating the package**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_trailer_fix.ps1 -Path build_passenger_trailer_fix -BaselineRoot _vehicle_catalog\kia_granbird
```

Expected: FAIL because the staging root and both overrides do not exist.

- [ ] **Step 4: Record checkpoint evidence**

Save the expected RED output. No commit is possible because the workspace has no `.git` repository.

---

### Task 2: Assemble the Minimal Chassis Overrides

**Files:**
- Create: `build_passenger_trailer_fix/manifest.sii`
- Create: `build_passenger_trailer_fix/description.txt`
- Create: `build_passenger_trailer_fix/def/vehicle/trailer_owned/passenger/chassis/chassis.sii`
- Create: `build_passenger_trailer_fix/def/vehicle/trailer_owned/crsthn.t_passag/chassis/chassis.sii`

**Interfaces:**
- Consumes: the common Kia extracted baseline files.
- Produces: a complete staging directory accepted by `validate_passenger_trailer_fix.ps1`.

- [ ] **Step 1: Add a focused test for the one-property rule**

Copy a baseline unchanged into a temporary candidate and run the validator. Expected: FAIL only because `master_collision_angle: 180` is missing.

- [ ] **Step 2: Create the two override definitions**

Copy the common baseline content into the two staging paths and insert `master_collision_angle: 180` inside each `accessory_chassis_data` block. Make no other definition change.

- [ ] **Step 3: Create metadata**

Set package version `1.0`, display name `Passenger Trailer Self-Collision Fix`, compatibility `1.59.*`, and description instructions to load above bus mods and start a fresh passenger job. State that Kim Long is covered only if it uses `passenger` or `crsthn.t_passag`.

- [ ] **Step 4: Run staging validation and verify GREEN**

Run the Task 1 command again. Expected: PASS for exact baseline preservation, retained world collision, exact angle, exact paths, and metadata.

- [ ] **Step 5: Record staging checkpoint**

Output file count and SHA-256 for both definitions and manifest.

---

### Task 3: Package and Verify the Trailer Fix Addon

**Files:**
- Create: `PASSENGER_TRAILER_COLLISION_FIX_1.59.scs`
- Test: `tests/validate_passenger_trailer_fix.ps1`

**Interfaces:**
- Consumes: validated `build_passenger_trailer_fix/`.
- Produces: one installable `.scs` archive independent of the HUD addon.

- [ ] **Step 1: Create the archive with package-root, forward-slash paths**

Use .NET `ZipArchive`, optimal compression, and no wrapper directory.

- [ ] **Step 2: Run the validator against the final archive**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_trailer_fix.ps1 -Path PASSENGER_TRAILER_COLLISION_FIX_1.59.scs -BaselineRoot _vehicle_catalog\kia_granbird
```

Expected: PASS.

- [ ] **Step 3: Perform archive integrity and scope checks**

Read every entry stream to EOF. Assert only manifest, description, optional icon, and the exact two chassis definition paths exist; assert no truck definitions, model assets, or nested `.scs` files.

- [ ] **Step 4: Record final artifact evidence**

Output final file size and SHA-256. Report that static preservation checks passed and that tight-turn/uneven-road behavior requires an in-game test with a newly spawned passenger trailer.
