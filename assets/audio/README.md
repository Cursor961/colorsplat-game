# Audio

Music and sound effects for ColorSplat!, generated with AI tools and then selected, cut
and arranged by me for the game.

```
music/   menu_1, menu_2            → main-menu playlist
         game_1 … game_7           → gameplay playlist (shuffled)
intro/   kompetlogosound.wav       → logo splash
sfx/     ~45 effects               → shooting, hits, deaths, pickups, crates, UI
```

`AudioManager` (`scripts/autoload/audio_manager.gd`) resolves every sound by name, trying
`.wav`, then `.ogg`, then `.mp3`, and silently skips anything it can't find — so you can
swap any file for your own, or drop extras in, without touching the code.

Sound effects follow the global slow-motion pitch shift, so short, dry samples work best.
