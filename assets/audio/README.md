# Audio — not included in this repository

The music and sound effects used in the published build are not my own work, so they
are not distributed here. **The game runs without them:** `AudioManager` resolves every
sound by path at runtime and silently skips anything it can't find
(`scripts/autoload/audio_manager.gd`), so a fresh clone plays fine — just muted.

To add your own audio, drop files with these names into these folders. Every SFX is
looked up as `.wav`, then `.ogg`, then `.mp3`, so any of the three works.

## `music/` — streamed, looped by `AudioManager`

| File | Used for |
|---|---|
| `menu_1`, `menu_2` | main menu playlist |
| `game_1` … `game_7` | gameplay playlist (shuffled) |

## `intro/`

| File | Used for |
|---|---|
| `kompetlogosound.wav` | publisher logo splash (`scripts/ui/splash_screen.gd`) |

## `sfx/`

**Combat** — `bullet_fire`, `bullet_fire_fmj`, `bullet_hit_1` … `bullet_hit_4`,
`laser_shot`, `grenade_pin`, `grenade_explosion`, `katana_equip`,
`katana_hit_1` … `katana_hit_4`, `decoy_beep`, `decoy_explosion`

**Enemies** — `monster_death_1` … `monster_death_4`, `spawnerdead`, `metinhit`,
`metindestroy`

**Pickups & crates** — `powerup_pickup`, `heal`, `crate_break`, `lootcratehit`,
`lootcratedestroy`, `box_click`, `box_reveal`, `box_tick`

**UI & events** — `button_click`, `button_click_menu`, `achievement_complete`,
`portal`, `timestop_effect`, `level30unlock`

> Sound effects respect the global slow-motion pitch shift, so short, dry samples work
> best — see `AudioManager.set_sfx_pitch()`.
