# Passenger Trailer Collision Fix v1.1

Target: Euro Truck Simulator 2 1.59

## Change

Version 1.0 set `master_collision_angle: 180`, which prevents the invisible
passenger trailer from colliding with its master bus during normal articulation.
The trailer's own `trailer_invisivel.pmc` still collided with the road and could
produce repeated impact sounds.

Version 1.1 keeps the existing model, wheels, suspension, mass, center of gravity,
and `master_collision_angle: 180`, but sets the chassis `collision` path to an
empty string for these two trailer families:

- `passenger`
- `crsthn.t_passag`

The original bus archives and the game's `mod` directory remain read-only inputs.

## Installation test

Load the addon above the supported bus mod, cancel any active passenger job, and
start a new passenger job so ETS2 spawns a fresh invisible trailer using v1.1.
Automated validation proves the package differs from its chassis baselines only
in `collision` and `master_collision_angle`; the final sound check must be made in
game.
