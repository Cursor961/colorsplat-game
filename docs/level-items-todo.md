# Level items — textures to create

Selected level objects/hazards to texture next (Doom-style corridor levels + light puzzle).
For each: a suggested sprite filename and what the art should show (incl. states where the
logic needs more than one frame). Drop finished SVGs/PNGs into `assets/sprites/levels/`.

## Hazards
1. **Turret / wall gun** — `turret.svg` — wall-mounted gun that fires at the player on
   line of sight. (Optional: separate `turret_base.svg` + rotating `turret_barrel.svg`.)
3. **Crusher / piston** — `crusher.svg` — heavy stamping block that slams down/across on a
   timer and kills if it catches the player. (Optional `crusher_rail.svg` track.)
4. **Laser gate / beam** — `lasergate_emitter.svg` (+ the beam can be drawn in code) —
   toggleable energy barrier that blocks/kills.
8. **Mine / proximity bomb** — `mine.svg` — floor mine that explodes when the player (or a
   monster) gets close. (Optional `mine_armed.svg` blinking state.)

## Puzzle / logic
9. **Pressure plate** — `plate_up.svg` + `plate_down.svg` — floor button that activates
   doors / bridges / spawns while stood on (or held by a crate).
10. **Lever / switch** — `lever_off.svg` + `lever_on.svg` — toggled by touch or a shot.
11. **Timed door** — `door_closed.svg` + `door_open.svg` — opens for N seconds after a
    trigger, then closes. (Can share art with #12.)
12. **Colored locked doors** — `door_blue.svg`, `door_green.svg`, `door_red.svg` (closed)
    — open with the matching colored key. (Optional `_open` variants.)
13. **Conveyor belt** — `conveyor.svg` (tileable strip; direction shown by arrows) —
    pushes the player/crates along its direction.
14. **Breakable wall** — `breakwall.svg` + `breakwall_cracked.svg` — shoot N times to open
    a new path.
18. **Sequence targets** — `target.svg` + `target_lit.svg` — shoot them in the right order
    to unlock something.
20. **Trampoline / bumper** — `bumper.svg` — bounces the player away (pinball feel).

## Goals / progression
22. **Collectible** — `orb.svg` (or `coin.svg`) — collect N to open the exit.
24. **Arena lock** — `arena_gate.svg` — gates that seal a room until all enemies are dead.

## Enemies / objects
25. **Metin stone / spawner totem** — `metin_stone.svg` (+ optional `metin_cracked.svg`) —
    high-HP stationary spawner; taking damage spawns enemies around it until destroyed.
27. **Ice tile** — `ice_tile.svg` (tileable) — slippery floor (low friction / sliding).
28. **Wind zone** — `wind_zone.svg` (semi-transparent, directional streaks) — constant push
    in one direction.

---
Notes:
- Square, transparent-background art works best; the component scales each to a `size` export.
- Multi-state props (doors, levers, plates, breakable wall, targets, mine) need both frames.
- Keys already exist (`key_blue/green/red.svg`); colored doors (#12) pair with them.
