# ColorSplat! - Features & Tweakable Values Reference

Tento dokument obsahuje VSECHNY tweakovatelne hodnoty a featury hry.
Kazda sekce odkazuje na presny soubor a promennou.

> **Aktualizovano:** 2026-05-28 — hodnoty overeny primo z kodu.

---

## 1. PLAYER (scripts/game/player.gd)

### Pohyb
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Max rychlost | `max_speed` | 500.0 | Maximalni rychlost hrace v px/s |
| Akcelerace | `acceleration` | 1700.0 | Zrychleni v px/s^2 |
| Speed multiplier | `speed_multiplier` | 1.0 (1.5 s powerupem) | Nasobek pri Speed Boost |
| Paint slow | `_current_slow` | 0.4 | Nasobek rychlosti na cizim paintu |

### Boj
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Max zivoty | `max_health` | 500.0 | HP hrace |
| Damage strely | `bullet_damage` | 100.0 | Poskozeni za strely |
| Kadence | `fire_rate` | 5.0 | Strel za sekundu |
| Rychlost strely | `bullet_speed` | 500.0 | px/s |
| Polomer strely | `bullet_radius` | 5.0 | Kolizni polomer |
| Kontaktni damage | viz MonsterTypes | per-type % max HP | Procento max HP hrace |

---

## 2. MONSTERS (scripts/data/monster_types.gd)

### Spolecne (v monster.gd)
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Hladkost otaceni | `TURN_SMOOTHING` | 10.0 | Vyssi = pomalejsi otaceni |
| Polomer vyhybani | `AVOIDANCE_RADIUS` | 40.0 | Monster-monster repulze |
| Sila vyhybani | `AVOIDANCE_STRENGTH` | 200.0 | Intenzita repulze |
| Spawn animace | `SPAWN_DURATION` | 1.0s | Doba pred aktivaci |

### TYP 1: BASIC (Grunt)
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 60.0 | Nizke |
| Damage | 50.0 | Stredni |
| Speed | 210.0 | Stredni |
| Radius | 16.0 | Standardni |
| Score | 10 | |
| Contact HP% | 10% | 10% max HP hrace |
| Barva | Red (0.85, 0.0, 0.047) | Odpovidajici SVG |
| Chovani | Chase player | Smooth steering |

### TYP 2: TANK
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 250.0 | Velmi vysoke |
| Damage | 40.0 | Nizsi |
| Speed | 105.0 | Pomaly |
| Radius | 32.0 | 2x velikost |
| Score | 25 | |
| Contact HP% | 50% | Hodne boli! |
| Paint scale | 1.5x | Vetsi splat pri smrti |
| Barva | Blue (0.0, 0.27, 1.0) | |

### TYP 3: SPEEDER
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 35.0 | Nizke |
| Damage | 30.0 | Nizky |
| Speed | 315.0 | Velmi vysoka |
| Radius | 22.0 | Mensi |
| Score | 15 | |
| Contact HP% | 20% | |
| Paint scale | 1.2x | |
| Barva | Cyan (0.0, 1.0, 0.878) | |
| **sine_amplitude** | 80.0 | Max bocni vychylka |
| **sine_frequency** | 2.5 | Kmity za sekundu |
| **sine_fade_distance** | 120.0 | Sinusoida se splosti na blizko |

### TYP 4: BRUTE
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 180.0 | Vysoke |
| Damage | 120.0 | Velmi vysoky |
| Speed | 150.0 | Stredni (3x pri charge) |
| Radius | 25.0 | 1.25x |
| Score | 30 | |
| Contact HP% | 40% | |
| Paint scale | 1.5x | |
| Barva | Orange (1.0, 0.549, 0.0) | |
| **charge_range** | 150.0 | Vzdalenost pro spusteni charge |
| **charge_speed_mult** | 3.0 | Nasobek rychlosti pri charge |
| **charge_warning_time** | 0.4s | Doba pred charge (TODO: vizualni warning) |

### TYP 5: HEALER
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 200.0 | 2x HP |
| Damage | 25.0 | Nizky |
| Speed | 165.0 | Stredni |
| Radius | 32.0 | 2x velikost |
| Score | 35 | Vyssi (prioritni cil) |
| Contact HP% | 25% | |
| Barva | Lime (0.557, 1.0, 0.0) | |
| **heal_interval** | 3.0s | Jak casto healuje |
| **heal_percent** | 0.20 | 20% max HP lecenych |
| **heal_radius** | 165.0 | Dosah healu |

### TYP 6: SPAWNER (Hive)
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 400.0 | 2x HP |
| Damage | 20.0 | Nizky |
| Speed | 90.0 | Pomaly |
| Radius | 55.0 | 2.5x vetsi |
| Score | 40 | Vyssi (prioritni cil) |
| Contact HP% | 40% | |
| Paint scale | 2.0x | |
| Barva | White (1.0, 1.0, 1.0) | |
| **spawn_interval** | 5.0s | Generace gruntu |
| **spawn_count** | 4 | Pocet gruntu za cyklus |
| **spawn_spread** | 40.0 | Rozptyl uvnitr tela |
| **spawn_max_monsters** | 60 | Performance cap |
| **spawn_warning_time** | 1.0s | Pulzovani pred spawnem (TODO: vizual) |

### TYP 7: SPLITTER
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 120.0 | Stredni |
| Damage | 45.0 | Stredni |
| Speed | 128.0 | Pomalejsi |
| Radius | 40.0 | 2x vetsi |
| Score | 20 | |
| Contact HP% | 10% | |
| Paint scale | 2.0x | |
| Barva | Purple (0.631, 0.196, 1.0) | |
| **split_count** | 3 | Potomku pri rozdeleni |
| **max_split_tier** | 2 | Max 2 deleni (tier 0->1->2) |
| **split_hp_mult** | 0.5 | HP potomka = rodic * 0.5 |
| **split_speed_mult** | 1.3 | Potomek je rychlejsi |
| **split_radius_mult** | 0.65 | Potomek je mensi |
| **split_damage_mult** | 0.6 | Potomek dava mene dmg |
| Katana/Grenade | `prevent_split` | Zabiti explozi/katanou nerozdeluje |

### TYP 8: GHOST (Phantom)
| Stat | Hodnota | Popis |
|---|---|---|
| HP | 50.0 | Nizke |
| Damage | 45.0 | Stredni |
| Speed | 360.0 | 2x rychlost! |
| Radius | 32.0 | 2x velikost |
| Score | 20 | |
| Contact HP% | 50% | Hodne boli! |
| Paint scale | 0.8x | Mensi splat |
| Barva | Pink (1.0, 0.4, 0.7) | Death paint barva |
| **visible_duration** | 3.0s | Jak dlouho je viditelny (zasazitelny) |
| **invisible_duration** | 3.0s | Jak dlouho je neviditelny (nezasazitelny) |
| **ignores_paint** | true | Nezpomaluje ho barva |

### Time-Based Scaling (Endless mode)
| Hodnota | Promenna | Default | Popis |
|---|---|---|---|
| Doba ramp | `SCALE_DURATION` | 420.0s (7 min) | Linearni ramp |
| HP multiplier | `SCALE_HP_MAX` | 2.0 (200%) | HP na konci rampy |
| Speed multiplier | `SCALE_SPEED_MAX` | 1.3 (130%) | Speed na konci rampy |

---

## 3. POWERUPS (scripts/game/powerup.gd + powerup_manager.gd)

### Typy a Trvani
| Powerup | Enum | Trvani | Efekt |
|---|---|---|---|
| Cleaner | CLEANER | 15s | Strely mazou paint |
| HP Boost | HP_BOOST | 15s | +100 max HP |
| Triple Shot | SHOOT_BOOST | 15s | 3 strely za vystrel |
| Speed Boost | SPEED_BOOST | 15s | 1.5x pohyb |
| FMJ | FMJ | 15s | Strely prochazi vším, cervena stopa |
| Octoshoot | OCTOSHOOT | 30s | 8 smerova strelba |
| Shuriken | SHURIKEN | 60s | Rotujici damage kruh |
| Invincibility | HPBOOSTMAX | 5s | Nezranitelnost |
| Time Stop | STOPPILL | 10s | Zmrazi monstra |

### Spawn a Stacking
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Spawn sance | `SPAWN_CHANCE_PER_SEC` | 0.06 (6%) | Kontrola 1x za sekundu |
| Max na mape | — | 1 | Jen 1 nezvednuty powerup |
| Pickup diameter | — | 66.0 px | 2.2x original 30px |
| Lifetime | `MAP_LIFETIME` | 15.0s | Zmizi po 15s |
| Blink start | `BLINK_START` | 10.0s | Blika poslednich 5s |
| Glow rotace | `GLOW_ROT_SPEED` | TAU/5 | 1 otocka za 5s |
| Stacking | ano | | Vic powerupu soucasne, timer se resetuje |
| Spawn pool | Common 5 | | Cleaner, HP, Triple, Speed, FMJ |
| Rare pool | Loot crate only | | Octoshoot, Shuriken, Invincibility, Stoppill |

### Combo Efekty
| Combo | Efekt |
|---|---|
| FMJ + Grenade | 2x blast radius |
| Cleaner + Grenade | Exploze maze paint |
| Octoshoot + cokoliv | 8-smerova varianta |

---

## 4. ITEMS (scripts/game/item_pickup.gd + item_manager.gd)

### Typy
| Item | Enum | Pouziti | Efekt |
|---|---|---|---|
| Grenade | GRENADE | Aim + throw | 99999 dmg v 150px radius, 60% self-dmg |
| Katana | KATANA | Instant | 3 rotace za 2.25s, instakill |
| Laser | LASER | Aim + fire | Celoobrazokvý paprsek, instakill |
| Slowpill | SLOWPILL | Instant | 8s Engine.time_scale=0.3 |
| HP +25 | HP25 | Instant | Lecí 25 HP |

### Spawn a Inventar
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Max inventar | `MAX_INVENTORY` | 3 | Max 3 itemy najednou |
| Spawn sance | `SPAWN_CHANCE_PER_SEC` | 0.04 (4%) | 1x za sekundu |
| Monster drop | `MONSTER_DROP_CHANCE` | 0.03 (3%) | Za kazde zabiti |
| Lifetime | `MAP_LIFETIME` | 20.0s | Zmizi po 20s |
| Blink start | `BLINK_START` | 15.0s | Blika poslednich 5s |

### Grenade Detail (grenade.gd)
| Hodnota | Promenna | Aktualni |
|---|---|---|
| Fuse time | `FUSE_TIME` | 4.0s |
| Pocatecni rychlost | `INITIAL_SPEED` | 900.0 px/s |
| Drag | `DRAG` | 3.0 (exponencialni) |
| Blast radius | `EXPLOSION_RADIUS` | 150.0 px (300 s FMJ) |
| Self damage | `PLAYER_DAMAGE_PERCENT` | 60% max HP |

### Katana Detail (katana_spin.gd)
| Hodnota | Promenna | Aktualni |
|---|---|---|
| Orbit radius | `ORBIT_RADIUS` | 95.0 px |
| Rotacni rychlost | `ROTATION_SPEED` | TAU/0.75 (1 otocka za 0.75s) |
| Celkova doba | `TOTAL_DURATION` | 2.25s (3 otocky) |
| Hit radius | CollisionShape2D | 67.0 px |

### Laser Detail (laser_beam.gd)
| Hodnota | Promenna | Aktualni |
|---|---|---|
| Sirka paprsku | `BASE_WIDTH` | 90.0 px |
| FMJ sirka | `FMJ_WIDTH_MULT` | 3.0x (= 270px) |
| Vizualni doba | `VISUAL_DURATION` | 0.5s fade |
| Flash doba | `FLASH_DURATION` | 0.1s |

### Shuriken Detail (shuriken_orbit.gd)
| Hodnota | Promenna | Aktualni |
|---|---|---|
| Orbit radius | `ORBIT_RADIUS` | 80.0 px |
| Orbit rychlost | `ORBIT_SPEED` | TAU/2 (1 kruh za 2s) |
| Self spin | `SELF_SPIN_SPEED` | TAU/0.5 (2 otocky/s) |
| Velikost | `SHURIKEN_SIZE` | 50.0 px diameter |
| Hit cooldown | `HIT_COOLDOWN` | 0.5s per monster |

---

## 5. SPAWNER (scripts/game/monster_spawner.gd)

### Endless Mode
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Pocatecni rate | `ENDLESS_RATE_START` | 0.5/s | Monstery za sekundu na zacatku |
| Konecny rate | `ENDLESS_RATE_END` | 2.0/s | Po 7 minutach |
| Ramp doba | `ENDLESS_RAMP_DURATION` | 420.0s (7 min) | Linearni ramp |
| Pocatecni pauza | `ENDLESS_INITIAL_PAUSE` | 1.5s | Pred prvnim spawnem |
| Max na obrazovce | `endless_max_monsters` | 50 | Performance cap |
| Spawn okraj | `endless_spawn_margin` | 120.0 px | Za okrajem obrazovky |

### Weighted Spawn Table
| Typ | Vaha | Procento |
|---|---|---|
| Basic | 55 | 55% |
| Tank | 15 | 15% |
| Brute | 7 | 7% |
| Speeder | 7 | 7% |
| Healer | 5 | 5% |
| Splitter | 4 | 4% |
| Ghost | 4 | 4% |
| Spawner | 3 | 3% |
| **Celkem** | **100** | **100%** |

### Spawner Rate Limit
| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Cap na 7 min | `SPAWNER_RATE_LIMIT_END` | 3/minuta | Max spawner spawnu za 60s |
| Ramp doba | `SPAWNER_RATE_RAMP_DURATION` | 420.0s | Zacina unlimited, ramps to 3/min |
| Metoda | sliding window | 60s okno | Timestamp tracking |

### Level Mode
| Hodnota | Popis |
|---|---|
| 30 levelu | Definovano v level_data.gd |
| Spawn interval | 0.3s mezi monstery ve skupine |
| Formace | "wall" (linie), "grid" (3x3), "" (random spread) |
| Completion | Vsechny vlny hotove + zadne monstera na mape |

---

## 6. ZONES (scripts/game/zone.gd + zone_manager.gd)

| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Grid | GRID_COLS x GRID_ROWS | 3 x 2 | Rozdeleni areny |
| Max aktivnich | `MAX_ACTIVE_ZONES` | 2 | |
| Spawn sance | `SPAWN_CHANCE_PER_SEC` | 0.03 (3%) | 1x za sekundu |
| Doba trvani | `ZONE_DURATION` | 20.0s | Countdown |
| Danger DPS | `DANGER_DPS` | 7.0 | Damage za sekundu |
| Timeboost mult | `TIMEBOOST_MULT` | 2.0 | Timer bezi 2x rychleji |
| Timeboost barva | zelena | rgb(0,60,0) border | 25% opacity fill |
| Danger barva | cervena | rgb(102,0,0) border | 25% opacity fill |
| Animace | dashed border | DASH_LENGTH=20, GAP=12, SPEED=60px/s | Pohyblive carkice |

---

## 7. LOOT CRATES (scripts/game/loot_crate.gd)

| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| HP | `MAX_HP` | 5.0 | 5 zasahu normalnimi strelami |
| Normal bullet DMG | `NORMAL_BULLET_DMG` | 1.0 | |
| FMJ bullet DMG | `FMJ_BULLET_DMG` | 3.0 | 2 zasahy |
| Laser DMG | `LASER_DMG` | 5.0 | Instakill |
| Grenade DMG | `GRENADE_DMG` | 5.0 | Instakill |
| Spawn sance | v game_world | 0.02 (2%)/s | Max 2 na mape |
| Item drop | `LOOT_ITEM_CHANCE` | 40% | |
| Powerup drop | `LOOT_POWERUP_CHANCE` | 40% | |
| Rare powerup | zbytok | 20% | Octoshoot/Shuriken/Invincibility/Stoppill |

---

## 8. FLOOR PAINT (scripts/game/floor_paint.gd)

| Hodnota | Popis |
|---|---|
| Canvas | SubViewport jako paint textura |
| Slowdown | 0.4x rychlost na cizyim paintu (vsechny kvality stejne) |
| Kvalita Low | Ctvercove splaty |
| Kvalita Mid | Mensi ctverce, vice decalu |
| Kvalita High | Elipsy a kulate tvary (SVG) |
| Splat velikost | CMath.rand(0.2, 0.5) * 0.75 |
| Vacuum | Powerup aktivni → sbirani paintu |

---

## 9. JOYSTICK (scripts/ui/virtual_joystick.gd)

| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Polomer | `joystick_radius` | 80.0 * sf | Max vzdalenost knobu |
| Dead zone | `dead_zone` | 0.15 | Ignorovany vstup pod 15% |
| Knob polomer | `knob_radius` | 30.0 * sf | Velikost pohyblive casti |
| Pruhlednost base | `base_color.a` | 0.3 | |
| Pruhlednost knob | `knob_color.a` | 0.6 | |
| Strana | `side` | "left"/"right" | Ktera polovina obrazovky |
| Textury | SVG | joystick_base.svg, joystick_knob.svg | Fallback: proceduralni kresleni |

---

## 10. AUDIO (scripts/autoload/audio_manager.gd)

| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Master volume | `global_volume` | 0.65 | Globalni hlasitost |
| SFX pitch | `_sfx_pitch` | 1.0 (0.3 pri slowpill) | Ovlivnuje vsechny SFX |
| Drums intensity | monster_count / 60 | 0.0-1.0 | Pro dynamic music |
| Melody intensity | player.is_powered_up | 0 nebo 1 | Pro dynamic music |
| SFX formaty | .wav, .ogg, .mp3 | | Hledany v tomto poradi |
| Music format | .ogg | | gameplay_01-03.ogg, menu.ogg |

---

## 11. PARTICLE SYSTEM (scripts/game/particle_effect.gd)

| Hodnota | Promenna | Aktualni | Popis |
|---|---|---|---|
| Max castic | `MAX_PARTICLES` | 500 | Mobilni performance cap |
| Motion blur threshold | hardcoded | 120 px/s | Nad = cara, pod = kruzek |
| Death exploze | 15 castic | vel: +-600, lt: 0.4-0.6s, death_paint: true |
| Dopad strely | 8 castic | vel: +-300, lt: 0.1-0.4s, death_paint: false |
| Damage efekt | 10 castic | vel: +-400, lt: 0.3-0.6s, death_paint: true |
| Menu dekorace | 20 castic | vel: +-600, lt: 2.4-4.6s, death_paint: true |
| Cleaner casice | 1 casice | vel: +-200, lt: 0.2-0.5s, death_paint: false |

---

## 12. SAVE SYSTEM (scripts/autoload/save_manager.gd)

| Cesta | Typ | Popis |
|---|---|---|
| settings.music_volume | int (0-100) | Hlasitost hudby |
| settings.sfx_volume | int (0-100) | Hlasitost efektu |
| settings.vibration | bool | Vibrace |
| settings.paint_quality | String | "low"/"mid"/"high" |
| settings.language | String | "en"/"cz"/"system" |
| progress.levels_unlocked | int | Odemcene levely (1-based) |
| progress.level_times | Dict{str: float} | Nejlepsi casy za level |
| progress.level_stars | Dict{str: int} | Hvezdicky za level (1-3) |
| progress.endless_best_time | float | Rekordni cas Endless |
| cosmetics.owned_skins | Array[String] | Vlastnene skiny |
| cosmetics.equipped_skin | String | Nasazeny skin |
| cosmetics.boxes_available | int | Neotevrene boxy |
| stats.total_kills | int | Celkove zabiti |
| stats.kills_{type} | int | Per-type (basic..ghost) |
| stats.total_deaths | int | Celkove smrti |
| stats.total_play_time | float | Celkovy cas hrani |
| stats.total_bullets_fired | int | Celkem strel |
| stats.endless_best_kills | int | Nejvic zabiti v jednom endless runu |
| stats.longest_session_time | float | Nejdelsi session |
| gdpr_consent | bool | GDPR souhlas |
| tutorial_completed | bool | Tutorial dokoncen |

---

## 13. LEVEL DATA (scripts/data/level_data.gd)

- **30 levelu** rozdelenychdo 6 arcu:
  - 1-5: Tutorial (jen Basic)
  - 6-10: Tank introduction
  - 11-15: Speeder introduction
  - 16-20: Brute + Healer
  - 21-25: Spawner + Splitter
  - 26-30: Vsechny typy + Ghost
- Kazdy level = pole vln (waves)
- Kazda vlna = `{ delay: float, groups: Array }`
- Helper funkce:
  - `_g(pos, spread, count, type)` — random spread spawn
  - `_wall(center, count, type, horizontal)` — line formace, spacing 0.08
  - `_transport(center, type)` — 3x3 grid formace, spacing 0.06
- Pozice v normalizovanych koordinatech (0.0-1.0, mapovano na arenu)

---

## 14. CANVAS LAYER ORDERING

| Layer | Screen | process_mode |
|---|---|---|
| 10 | StoppillOverlay (cyan tint) | — |
| 11 | HUD | — |
| 45 | GreyscaleOverlay (death shader) | — |
| 50 | DeathScreen | ALWAYS |
| 55 | PauseMenu | ALWAYS |
| 60 | VolumePopup / StatsPopup / SettingsPopup | ALWAYS |
| 100 | FadeOverlay (scene transitions) | ALWAYS |

---

## 15. COLLISION LAYERS

| Bit | Pouziti | Typ |
|---|---|---|
| 1 | Walls | StaticBody2D |
| 2 | Player | CharacterBody2D |
| 4 | Monsters | CharacterBody2D |
| 64 | LootCrates | Area2D (collision_layer=64) |
| Bullets mask | 4 + 64 | Area2D monitoruje monstera + crates |
