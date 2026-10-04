# Passenger Bus HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one ETS2 1.59 addon that provides a clearer, left-shifted windshield GPS and speed HUD for five installed passenger-bus IDs.

**Architecture:** A shared UI and drawable texture feed three separately compiled model families (Kia, Kim Long, and Thaco). Fifteen per-truck accessory definitions expose Normal, Large, and Extra Large choices through each bus's `set_lglass` slot, while a structural validator treats both the staging directory and final `.scs` as the same package interface.

**Tech Stack:** PowerShell 5.1, SII UI/accessory definitions, SCS mid-format PIM/PIT, official SCS Conversion Tools 2.21, ZIP-format `.scs` archive.

**Spec:** `docs/superpowers/specs/2026-10-04-passenger-bus-hud-trailer-fix-design.md`

## Global Constraints

- Target ETS2 version is exactly `1.59.*`.
- Treat `C:\Users\TrầnChíVỹ\Documents\Euro Truck Simulator 2\mod` as read-only.
- Do not include or modify an original vehicle archive.
- Support only `granbird.23`, `kimlong.99`, `thaco.mbh.23`, `thaco.mbh.25`, and `man.tgx.sample`.
- Translate projection geometry by exactly `-0.65 m` on X; preserve Y, Z, orientation, and UV values.
- Use `ui_drawable_size: (1024, 1024)` and full alpha for secondary white text.
- Keep separate Kia, Kim Long, and Thaco model paths.
- The workspace is not a Git repository; each task ends with fresh validation evidence and SHA-256 checkpoint output instead of a commit.

## File Structure

- `tools/Convert-PimXOffset.ps1` — translate only PIM `_POSITION` stream X components.
- `tests/validate_pim_x_offset.ps1` — compare original and transformed PIM geometry.
- `tests/validate_passenger_bus_hud.ps1` — validate a staging directory or ZIP `.scs` package.
- `_hud_model_sources/{kia,kimlong,thaco}/` — transformed PIM/PIT build inputs, excluded from the package.
- `build_passenger_bus_hud/` — complete package staging root.
- `build_passenger_bus_hud/def/vehicle/truck/<truck-id>/accessory/set_lglass/` — three definitions per bus.
- `build_passenger_bus_hud/ui/` — dashboard UI and text templates.
- `build_passenger_bus_hud/vehicle/truck/passenger_hud/` — unique drawable and compiled family models.
- `PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs` — final deliverable.

## Review Focus

- Locked Kim Long input: package assets and definitions must not depend on extracting its `AEM!` archive; Task 3 tests this by requiring only self-contained package paths.
- Unit collisions: all 15 accessory unit names must be unique and scoped to the correct truck ID; Task 3 tests the exact set.
- Geometry corruption: only X position values may change by `-0.65`; Task 2 compares every vertex and all non-position content.
- Dashboard interference: every definition must use `/vehicle/truck/passenger_hud/share/hud_ui.tobj`, never a stock or vehicle-mod GPS texture; Task 3 checks each reference.
- Windows archive separators: all final entries must use `/`, be unique, and fully decompress; Task 4 tests the archive entry table and streams.

---

### Task 1: Define Package and Geometry Acceptance Tests

**Files:**
- Create: `tests/validate_pim_x_offset.ps1`
- Create: `tests/validate_passenger_bus_hud.ps1`
- Reference: `tests/validate_grandbird_hud.ps1`

**Interfaces:**
- Consumes: an original PIM, a transformed PIM, and either a package directory or ZIP `.scs` path.
- Produces: process exit code `0` on success and nonzero with one `FAIL:` line per violated requirement.

- [ ] **Step 1: Write `validate_pim_x_offset.ps1`**

Accept `-Original`, `-Transformed`, and `-ExpectedOffset`. Parse the `_POSITION` stream as IEEE-754 float triples; assert equal vertex counts, `transformed.X - original.X == -0.65` within `0.00001`, unchanged Y/Z, and byte-identical text outside the X tokens in that stream.

- [ ] **Step 2: Write `validate_passenger_bus_hud.ps1`**

Assert the exact five truck IDs, exact three size definitions per ID, unique unit names, `1024 × 1024` drawable size, unique HUD texture path, UI IDs `1020` and `1610`, bare map material, three compiled model families, PMD/PMG pairs, converted material, `1.59.*` manifest compatibility, and absence of cargo-truck IDs or PIM/PIT package entries.

- [ ] **Step 3: Run both validators against current inputs and verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_pim_x_offset.ps1 -Original _optical_hud_source\ETS2-Optical-HUD-master\mod-files\vehicle\truck\upgrade\interior_set\scania_2016\optical_hud.pim -Transformed _optical_hud_source\ETS2-Optical-HUD-master\mod-files\vehicle\truck\upgrade\interior_set\scania_2016\optical_hud.pim -ExpectedOffset -0.65
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_bus_hud.ps1 -Path GRANBIRD_OPTICAL_HUD_GPS_SPEED_1.59.scs
```

Expected: first command fails because X offset is `0`; second fails because four truck IDs, three family paths, and `1024 × 1024` are absent.

- [ ] **Step 4: Record checkpoint evidence**

Save the RED command output in the execution notes. No commit is possible because the workspace has no `.git` repository.

---

### Task 2: Create and Compile Three HUD Model Families

**Files:**
- Create: `tools/Convert-PimXOffset.ps1`
- Create: `_hud_model_sources/kia/optical_hud{,_large,_extra_large}.{pim,pit}`
- Create: `_hud_model_sources/kimlong/optical_hud{,_large,_extra_large}.{pim,pit}`
- Create: `_hud_model_sources/thaco/optical_hud{,_large,_extra_large}.{pim,pit}`
- Create: `build_passenger_bus_hud/vehicle/truck/passenger_hud/{kia,kimlong,thaco}/*.{pmd,pmg}`
- Create: `build_passenger_bus_hud/vehicle/truck/passenger_hud/share/hud_ui.{dds,tobj}`
- Create: `build_passenger_bus_hud/automat/<hash>.mat`

**Interfaces:**
- Consumes: `Convert-PimXOffset.ps1 -Source <pim> -Destination <pim> -Offset -0.65` and upstream Optical HUD PIM/PIT files.
- Produces: nine transformed PIM/PIT pairs for validation and nine compiled PMD/PMG pairs for packaging.

- [ ] **Step 1: Add a focused failing utility test**

Extend `validate_pim_x_offset.ps1` usage with a temporary destination that does not exist. Run it and verify failure reports the missing transformed PIM, not a parser error.

- [ ] **Step 2: Implement `Convert-PimXOffset.ps1`**

Expose parameters `Source: string`, `Destination: string`, and `Offset: double`. Restrict rewriting to the first float in every `_POSITION` triple, preserve line endings and all other tokens, and encode the new float back to the eight-digit hexadecimal bit form used by PIM.

- [ ] **Step 3: Generate three family source trees**

For Normal, Large, and Extra Large, run the converter once per family. Copy the matching PIT and replace its texture value with `/vehicle/truck/passenger_hud/share/hud_ui`. Keep identical initial geometry across families so later placement tuning is isolated by path.

- [ ] **Step 4: Run geometry tests and verify GREEN**

Run `validate_pim_x_offset.ps1` for all nine generated PIM files. Expected: nine passes with exactly `-0.65` X offset and unchanged Y/Z/non-position data.

- [ ] **Step 5: Compile with official Conversion Tools 2.21**

Copy only the dedicated `passenger_hud` model and share subtrees into `conversion_tools_2_21/base`, run `convert.cmd`, require exit code `0`, and copy the corresponding `@cache` PMD/PMG, TOBJ/DDS, and automat material into `build_passenger_bus_hud`.

- [ ] **Step 6: Verify compilation output**

Assert each of the nine PMD files has a matching nonempty PMG, the conversion log contains `Conversion finished`, and contains no `ERROR` line.

- [ ] **Step 7: Record checkpoint hashes**

Output SHA-256 for the nine PMD/PMG pairs and the converted material.

---

### Task 3: Assemble Multi-Bus Definitions and Clearer UI

**Files:**
- Create: `build_passenger_bus_hud/manifest.sii`
- Create: `build_passenger_bus_hud/description.txt`
- Create: `build_passenger_bus_hud/cover.jpg`
- Create: `build_passenger_bus_hud/ui/dashboard/optical_hud.sii`
- Create: `build_passenger_bus_hud/ui/template/dashboard_text.optical_hud.sii`
- Create: `build_passenger_bus_hud/material/ui/accessory/optical_hud.{dds,mat,tobj}`
- Create: 15 files under `build_passenger_bus_hud/def/vehicle/truck/<truck-id>/accessory/set_lglass/`

**Interfaces:**
- Consumes: family PMD paths from Task 2 and shared UI paths fixed by the spec.
- Produces: a complete staging directory accepted by `validate_passenger_bus_hud.ps1`.

- [ ] **Step 1: Add exact definition expectations to the validator and verify RED**

Expected units are `optical_hud`, `ohud_l`, and `ohud_xl` scoped to each exact truck ID and `set_lglass`. Require Kia path for `granbird.23`, Kim Long path for `kimlong.99`, and Thaco path for all three Thaco IDs. Run against the incomplete staging directory; expected failure names all missing definitions.

- [ ] **Step 2: Add manifest, description, icon, UI, and templates**

Set package version `1.1`, display name `Passenger Bus Optical HUD - GPS + Speed`, compatibility `1.59.*`, and instructions to load above bus mods. Copy the upstream UI, keep primary map/colors, and change every secondary `CCFFFFFF` text color to `FFFFFFFF`.

- [ ] **Step 3: Add all 15 accessory definitions**

Each definition references its family model, `/ui/dashboard/optical_hud.sii`, `/vehicle/truck/passenger_hud/share/hud_ui.tobj`, and `ui_drawable_size: (1024, 1024)`. Do not reference any asset inside the locked Kim Long archive.

- [ ] **Step 4: Run staging validation and verify GREEN**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_bus_hud.ps1 -Path build_passenger_bus_hud
```

Expected: PASS with five truck IDs, 15 unique accessory units, three model families, and all UI requirements.

- [ ] **Step 5: Record staging checkpoint**

Output file count, total uncompressed bytes, and SHA-256 for `manifest.sii`, UI files, and all definitions.

---

### Task 4: Package and Verify the HUD Addon

**Files:**
- Create: `PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs`
- Test: `tests/validate_passenger_bus_hud.ps1`

**Interfaces:**
- Consumes: validated `build_passenger_bus_hud/`.
- Produces: one installable `.scs` archive with package-root entries.

- [ ] **Step 1: Create the archive with forward-slash entry paths**

Use .NET `ZipArchive` and derive each entry relative to the staging root, replacing `\` with `/`. Use optimal compression and do not add a wrapper directory.

- [ ] **Step 2: Run the same validator against the final archive**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_bus_hud.ps1 -Path PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs
```

Expected: PASS.

- [ ] **Step 3: Perform archive integrity and review-focus checks**

Read every entry stream to EOF; assert unique forward-slash paths, no PIM/PIT, no nested `.scs`, no truck ID beyond the approved five, and no reference to a stock or vehicle-mod GPS drawable.

- [ ] **Step 4: Record final artifact evidence**

Output final file size and SHA-256. Report that structural/build checks passed but in-game placement remains a user acceptance test for each cabin family.

