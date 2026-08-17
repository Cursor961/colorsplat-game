<div align="center">

<img src="docs/img/icon.png" width="140" alt="ColorSplat! icon">

# ColorSplat!

**A twin-stick paint shooter for Android, built in Godot 4 with GDScript.**

Survive the arena, splatter everything, and don't get caught standing in someone else's paint.

[![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![GDScript](https://img.shields.io/badge/GDScript-24.7k%20lines-355570)](scripts/)
[![Platform](https://img.shields.io/badge/platform-Android-3ddc84?logo=android&logoColor=white)](#building)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<img src="docs/img/promo.png" width="720" alt="ColorSplat! promo art">

</div>

---

## What it is

A top-down arena shooter for phones: two virtual sticks, one to move, one to aim. Every
kill throws paint on the floor, and paint that isn't yours slows you to 40 % speed — so the
arena you're winning in is also the arena that's closing in on you.

Three modes:

| Mode | What it is |
|---|---|
| **Levels** | 30 hand-built levels across 6 arcs, each with wave scripting, hazards, keys and locked doors, and 1–3 stars by clear time |
| **Endless** | One arena, a 7-minute difficulty ramp, and your best time and kill count on the line |
| **Challenges** | 8 hand-designed modifier runs — *Blackout*, *Sniper*, *Miniarena*, *Horda*, *Dasher*, *Totem*, *Řezník*, *Zásobník* |

Plus a daily loot box, 31 achievements with cross-session progress tracking, 32 player
skins and 26 paint trails, and a full settings screen in 5 languages.

## Content

| | |
|---|---|
| **8 enemy types** | Grunt · Tank · Speeder · Brute (charges) · Healer (heals nearby) · Hive (spawns) · Splitter (splits twice) · Phantom (phases in and out) |
| **9 power-ups** | Cleaner, HP Boost, Triple Shot, Speed Boost, FMJ (pierces everything), Octoshoot, Shuriken orbit, Invincibility, Time Stop |
| **5 items** | Grenade (aimed throw, 60 % self-damage), Katana (3 spins, instakill), Laser (screen-wide beam), Slowpill, Heal |
| **26 level objects** | Turrets, pistons, saws, spikes, ice tiles, teleports, speed pads, breakable walls, colored keys and locked doors, pressure buttons, crates, barrels, boss, metin stones |
| **Zones** | Timed danger and time-boost zones on a 3×2 arena grid, animated dashed borders |

## Under the hood

Things in here I'd point at in a code review:

**Paint that costs nothing when idle.** The floor is a `SubViewport` used as an
accumulation buffer (`CLEAR_MODE_NEVER`): a splat is drawn by a single `UPDATE_ONCE`
render, the node is freed, the pixels stay baked. Node count stays near zero and idle
frames cost no GPU time. Paint *detection* runs on a separate CPU grid — the original
per-frame `SubViewport.get_image()` read-back stalled the GPU on mobile, so logical
coverage is tracked in a `Vector2i → Color` dictionary instead, with its own erosion
accumulator for driving paint off over time. Ice slabs are re-stamped on a throttle so an
eraser can't punch holes in the background.
→ [`scripts/game/floor_paint.gd`](scripts/game/floor_paint.gd)

**Data-driven enemies.** All 8 types are one registry of stats and behaviour flags, so a
new enemy is a dictionary entry plus its special-case hook — sine-wave strafing, charge
windups, heal pulses, split tiers with per-tier HP/speed/size multipliers.
→ [`scripts/data/monster_types.gd`](scripts/data/monster_types.gd), [`scripts/game/monster.gd`](scripts/game/monster.gd)

**Mobile performance budget, everywhere.** 500-particle hard cap, 50–60 monster caps,
three paint-quality tiers (squares → small squares → real SVG ellipses), rate-limited
paint erasure, monster-avoidance forces computed once per frame in the world instead of
per-monster.

**Crash-safe saves.** JSON written to a temp file and renamed over the live save, with the
previous save kept as a fallback — a kill mid-write can only ever destroy the temp file.
→ [`scripts/autoload/save_manager.gd`](scripts/autoload/save_manager.gd)

**Ads that can't break the game.** The AdMob plugin is optional at runtime: if the native
singleton isn't there (desktop, editor, or any build without the plugin) every rewarded-ad
request instantly succeeds instead of failing, so the game is fully playable with no ad
stack at all.
→ [`scripts/autoload/ad_manager.gd`](scripts/autoload/ad_manager.gd)

**5 languages from one table.** 173 UI strings in en/cz/es/de/fr with English fallback,
resolved through the OS locale when the player picks *system*.
→ [`scripts/utils/localization.gd`](scripts/utils/localization.gd)

**5 custom shaders** — paint smear, damage vignette, death greyscale, glow blur, sprite
greyscale. → [`assets/shaders/`](assets/shaders/)

**Five autoloads, one responsibility each** — `GameManager` (state), `SaveManager`
(persistence), `AudioManager` (music playlists + SFX voice pool + slow-motion pitch),
`AchievementManager` (unlock conditions), `AdManager` (rewarded ads).

## Numbers

| | |
|---|---|
| GDScript | **24 692 lines** across **84 files** |
| Scenes | 57 (`.tscn`) |
| Vector art | 187 SVGs, all drawn for this project |
| Levels / challenges | 30 / 8 |
| Achievements | 31 |
| Cosmetics | 32 skins, 26 trails |
| Languages | 5 |
| Target | Android, landscape, 2400×1080 reference viewport, Godot mobile renderer |

## Project structure

```
scripts/
  autoload/   5 singletons: game state, saves, audio, achievements, ads
  game/       gameplay — player, monsters, bullets, paint, items, power-ups, zones
    level/    26 level objects: turrets, pistons, keys, doors, hazards…
  ui/         menus, HUD, popups, virtual joystick
  data/       registries: enemy stats, level waves, achievements, skins, trails
  utils/      math, juice/screen-shake, localization, theming, sprite loading
scenes/
  levels/     30 levels
  challenges/ 8 challenge arenas
  game/       gameplay prefabs
assets/
  sprites/    187 SVGs
  shaders/    5 .gdshader
  fonts/      Google Fonts (OFL)
docs/
  features.md          every tweakable value, cross-referenced to its file
  level-items-todo.md  art spec for level objects
```

[`docs/features.md`](docs/features.md) is the reference I actually worked from — every
tunable in the game with its file, variable name and current value.

## Running it

```bash
git clone https://github.com/Cursor961/colorsplat-game.git
cd colorsplat-game
```

Open the folder in **Godot 4.7** (Project → Import → pick `project.godot`) and press *Play*.
First import takes a minute while the SVGs rasterize. On desktop the virtual sticks are
mouse-driven (`emulate_touch_from_mouse` is on), so it's playable in the editor.

Two things to know about a fresh clone:

- **No audio.** The music and SFX in the published build aren't my work, so they're not in
  this repo. `AudioManager` skips any file it can't find, so the game runs — just silent.
  [`assets/audio/README.md`](assets/audio/README.md) lists every filename it looks for if
  you want to drop your own in.
- **Placeholder ad IDs.** The AdMob unit IDs in `ad_manager.gd` are zeros. `USE_TEST_ADS`
  is `true`, and with no native plugin present the ad path is bypassed entirely.

### Building

Android export is configured in `export_presets.cfg` (AAB, `com.colorsplatgame`, target
API per the Godot 4.7 template). You'll need to install the Android build template
(*Project → Install Android Build Template*) and your own keystore — neither is committed.

## Origins

ColorSplat! began as a rebuild: a Flash-era arena shooter reimplemented from the ground up
in Godot 4 for touch. A handful of files still carry `converted from …` comments pointing
at the classes of that original as a design reference. Everything in this repository —
the GDScript, the 57 scenes, the 30 levels, the challenge designs, the vector art and the
UI — was written and drawn for this project.

## License

Code is [MIT](LICENSE). Third-party components (the AdMob plugin, the fonts) and the
excluded audio are covered in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
