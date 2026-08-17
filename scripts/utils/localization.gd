class_name Localization
## Lightweight UI localization for ColorSplat! menus.
## Languages: en, cz, es, de, fr (es/de/fr translated from English). The UI font
## is Baloo 2 Bold (full Latin + diacritics). Language comes from the "language"
## save setting ("en"/"cz"/"es"/"de"/"fr"/"system"; system resolves via OS locale).
##
## Usage (reference via a local preload alias to dodge global-class timing):
##   const Loc := preload("res://scripts/utils/localization.gd")
##   label.text = Loc.t("play")
##
## EN values mirror the original hardcoded strings. Missing translations fall back
## to English. Skin/achievement DESCRIPTIONS stay English for es/de/fr (content).

const LANGS: Array[String] = ["en", "cz", "es", "de", "fr"]

const STRINGS: Dictionary = {
	# ---- Main menu ----
	"play":        {"en": "PLAY",        "cz": "HRÁT",       "es": "JUGAR",      "de": "SPIELEN",   "fr": "JOUER"},
	"daily":       {"en": "Daily",       "cz": "Odměna",     "es": "Diario",     "de": "Täglich",   "fr": "Quotidien"},
	"stats":       {"en": "Stats",       "cz": "Statistiky", "es": "Estadísticas", "de": "Statistik", "fr": "Stats"},
	"skins":       {"en": "Skins",       "cz": "Vzhledy",    "es": "Aspectos",   "de": "Skins",     "fr": "Apparences"},
	"settings":    {"en": "Settings",    "cz": "Nastavení",  "es": "Ajustes",    "de": "Optionen",  "fr": "Options"},
	"select_mode": {"en": "SELECT MODE", "cz": "VYBER REŽIM","es": "ELIGE MODO", "de": "MODUS WÄHLEN", "fr": "CHOISIR MODE"},
	"levels":      {"en": "LEVELS",      "cz": "ÚROVNĚ",     "es": "NIVELES",    "de": "LEVEL",     "fr": "NIVEAUX"},
	"level":       {"en": "Level",       "cz": "Úroveň",     "es": "Nivel",      "de": "Level",     "fr": "Niveau"},
	"selected":    {"en": "SELECTED",    "cz": "VYBRÁNO",    "es": "SELECCIONADO","de": "AUSGEWÄHLT","fr": "SÉLECTIONNÉ"},
	"endless":     {"en": "ENDLESS",     "cz": "NEKONEČNÝ",  "es": "INFINITO",   "de": "ENDLOS",    "fr": "INFINI"},
	"challenge":   {"en": "CHALLENGE",   "cz": "VÝZVA",      "es": "DESAFÍO",    "de": "PRÜFUNG",   "fr": "DÉFI"},
	"close":       {"en": "CLOSE",       "cz": "ZAVŘÍT",     "es": "CERRAR",     "de": "SCHLIESSEN","fr": "FERMER"},
	"skip_ad":     {"en": "SKIP ▶ (AD)", "cz": "PŘESKOČIT ▶ (ad)", "es": "SALTAR ▶ (AD)", "de": "ÜBERSPRINGEN ▶ (AD)", "fr": "PASSER ▶ (PUB)"},
	"ad_loading":  {"en": "Loading ad…", "cz": "Spouští se reklama…", "es": "Cargando anuncio…", "de": "Werbung wird geladen…", "fr": "Chargement de la pub…"},
	"privacy_policy":   {"en": "Privacy Policy", "cz": "Ochrana údajů", "es": "Privacidad", "de": "Datenschutz", "fr": "Confidentialité"},
	"privacy_settings": {"en": "Ad privacy", "cz": "Soukromí reklam", "es": "Privacidad de anuncios", "de": "Werbe-Datenschutz", "fr": "Pub & confidentialité"},
	"ad_offline":  {"en": "No internet connection", "cz": "Není připojení k internetu", "es": "Sin conexión a internet", "de": "Keine Internetverbindung", "fr": "Pas de connexion internet"},
	"apply":       {"en": "APPLY",       "cz": "POUŽÍT",     "es": "APLICAR",    "de": "ANWENDEN",  "fr": "APPLIQUER"},
	"settings_saved":   {"en": "All changes applied", "cz": "Vše použito", "es": "Todo aplicado", "de": "Alles übernommen", "fr": "Tout appliqué"},
	"settings_unsaved": {"en": "Unapplied changes", "cz": "Nepoužité změny", "es": "Cambios sin aplicar", "de": "Nicht übernommen", "fr": "Modifs non appliquées"},
	"unsaved_title":    {"en": "Unapplied changes", "cz": "Nepoužité změny", "es": "Cambios sin aplicar", "de": "Nicht übernommene Änderungen", "fr": "Modifications non appliquées"},
	"unsaved_msg":      {"en": "Leave without applying them?", "cz": "Odejít bez jejich použití?", "es": "¿Salir sin aplicarlos?", "de": "Ohne Übernehmen verlassen?", "fr": "Quitter sans les appliquer ?"},
	"discard_leave":    {"en": "DISCARD", "cz": "ZAHODIT", "es": "DESCARTAR", "de": "VERWERFEN", "fr": "ABANDONNER"},
	"stay":             {"en": "STAY", "cz": "ZŮSTAT", "es": "QUEDARSE", "de": "BLEIBEN", "fr": "RESTER"},
	"free_spin":        {"en": "FREE", "cz": "ZDARMA", "es": "GRATIS", "de": "GRATIS", "fr": "GRATUIT"},

	# ---- Pause menu ----
	"paused":      {"en": "PAUSED",  "cz": "PAUZA",      "es": "PAUSA",     "de": "PAUSE",      "fr": "PAUSE"},
	"resume":      {"en": "RESUME",  "cz": "POKRAČOVAT", "es": "CONTINUAR", "de": "WEITER",     "fr": "REPRENDRE"},
	"volume_btn":  {"en": "VOLUME",  "cz": "HLASITOST",  "es": "VOLUMEN",   "de": "LAUTSTÄRKE", "fr": "VOLUME"},
	"skip_song":   {"en": "SKIP SONG", "cz": "PŘESKOČIT SKLADBU", "es": "SALTAR CANCIÓN", "de": "SONG ÜBERSPRINGEN", "fr": "CHANSON SUIVANTE"},
	"level_complete": {"en": "LEVEL COMPLETE!", "cz": "LEVEL DOKONČEN!", "es": "¡NIVEL COMPLETADO!", "de": "LEVEL GESCHAFFT!", "fr": "NIVEAU TERMINÉ !"},
	"challenge_done":   {"en": "CHALLENGE COMPLETE", "cz": "VÝZVA SPLNĚNA", "es": "DESAFÍO COMPLETADO", "de": "PRÜFUNG BESTANDEN", "fr": "DÉFI RÉUSSI"},
	"challenges_title": {"en": "CHALLENGES", "cz": "VÝZVY", "es": "DESAFÍOS", "de": "PRÜFUNGEN", "fr": "DÉFIS"},
	"hidden_achievement": {"en": "Hidden achievement — unlock it to reveal what it hides.", "cz": "Skrytý úspěch — odemkni ho a odhal, co skrývá.", "es": "Logro oculto: desbloquéalo para revelarlo.", "de": "Verborgener Erfolg — schalte ihn frei, um ihn zu enthüllen.", "fr": "Succès caché — débloque-le pour le révéler."},
	"ad_space": {"en": "ADVERTISEMENT", "cz": "REKLAMA", "es": "PUBLICIDAD", "de": "WERBUNG", "fr": "PUBLICITÉ"},
	# ---- INFO / CREDITS popup (version-text tap in the main menu) ----
	"info_author": {"en": "Author: Adam \"Cursor\" Musílek", "cz": "Autor: Adam \"Cursor\" Musílek", "es": "Autor: Adam \"Cursor\" Musílek", "de": "Autor: Adam \"Cursor\" Musílek", "fr": "Auteur : Adam \"Cursor\" Musílek"},
	"info_desc": {
		"en": "ColorSplat is a classic top-down shooter that aims to emulate Doom's mechanics — you will find plenty of levels, challenges and an endless mode where you can put your skills to the test and survive as long as possible!",
		"cz": "Hra ColorSplat je klasický top-down shooter, který se snaží napodobit mechaniky Dooma — naleznete zde spousty levelů, challengí a také nekonečný mód, kde můžete využít vaše schopnosti k tomu, abyste vydrželi ve hře co nejdéle!",
		"es": "ColorSplat es un shooter cenital clásico que busca emular las mecánicas de Doom: encontrarás montón de niveles, desafíos y un modo infinito donde podrás usar tus habilidades para sobrevivir el mayor tiempo posible.",
		"de": "ColorSplat ist ein klassischer Top-Down-Shooter, der die Mechaniken von Doom nachahmen will — dich erwarten jede Menge Level, Prüfungen und ein Endlos-Modus, in dem du dein Können beweisen und so lange wie möglich überleben kannst!",
		"fr": "ColorSplat est un shooter vu de dessus classique qui cherche à imiter les mécaniques de Doom — vous y trouverez plein de niveaux, des défis et un mode infini où mettre vos talents à l'épreuve pour survivre le plus longtemps possible !"},
	"info_thanks": {
		"en": "Thanks to everyone who helped test this simple shooter game.",
		"cz": "Děkuji všem, kteří se podíleli na testingu této simple shooter gamesky.",
		"es": "Gracias a todos los que ayudaron a probar este sencillo shooter.",
		"de": "Danke an alle, die beim Testen dieses simplen Shooters geholfen haben.",
		"fr": "Merci à tous ceux qui ont participé aux tests de ce petit shooter."},
	"info_wish": {
		"en": "Good luck and have fun!",
		"cz": "Přeji hodně štěstí a zábavy.",
		"es": "¡Mucha suerte y a divertirse!",
		"de": "Viel Glück und viel Spaß!",
		"fr": "Bonne chance et amusez-vous bien !"},
	"info_ai": {
		"en": "AI assistance was used during development.",
		"cz": "Při vývoji byla využita pomoc od AI.",
		"es": "Durante el desarrollo se utilizó ayuda de IA.",
		"de": "Bei der Entwicklung wurde KI-Unterstützung genutzt.",
		"fr": "L'IA a été mise à contribution pendant le développement."},
	"ammo": {"en": "AMMO", "cz": "NÁBOJE", "es": "MUNICIÓN", "de": "MUNITION", "fr": "MUNITIONS"},
	"totems_hud": {"en": "TOTEMS", "cz": "TOTEMY", "es": "TÓTEMS", "de": "TOTEMS", "fr": "TOTEMS"},
	"record": {"en": "RECORD", "cz": "REKORD", "es": "RÉCORD", "de": "REKORD", "fr": "RECORD"},
	"kills_hud": {"en": "KILLS", "cz": "ZABITÍ", "es": "BAJAS", "de": "KILLS", "fr": "VICTIMES"},
	"completed":        {"en": "DONE", "cz": "SPLNĚNO", "es": "HECHO", "de": "ERLEDIGT", "fr": "FAIT"},
	"challenge_failed": {"en": "CHALLENGE FAILED", "cz": "VÝZVA NESPLNĚNA", "es": "DESAFÍO FALLIDO", "de": "PRÜFUNG FEHLGESCHLAGEN", "fr": "DÉFI ÉCHOUÉ"},
	"menu":        {"en": "MENU",    "cz": "MENU",       "es": "MENÚ",      "de": "MENÜ",       "fr": "MENU"},
	"leave_to_menu_title": {"en": "Leave to menu?", "cz": "Opravdu do menu?", "es": "¿Salir al menú?", "de": "Zum Menü zurück?", "fr": "Retour au menu ?"},
	"leave_to_menu_msg":   {"en": "Your progress in this run will be lost.", "cz": "Tvůj postup v této hře bude ztracen.", "es": "Perderás tu progreso en esta partida.", "de": "Dein Fortschritt in diesem Lauf geht verloren.", "fr": "Ta progression dans cette partie sera perdue."},

	# ---- Volume popup ----
	"volume_title": {"en": "VOLUME", "cz": "HLASITOST", "es": "VOLUMEN", "de": "LAUTSTÄRKE", "fr": "VOLUME"},
	"music":        {"en": "Music",  "cz": "Hudba",     "es": "Música",  "de": "Musik",      "fr": "Musique"},
	"sfx":          {"en": "SFX",    "cz": "Zvuky",     "es": "Sonido",  "de": "SFX",        "fr": "SFX"},

	# ---- Settings popup ----
	"settings_title": {"en": "SETTINGS",     "cz": "NASTAVENÍ",   "es": "AJUSTES",  "de": "OPTIONEN",  "fr": "OPTIONS"},
	"paint_detail":   {"en": "Paint Detail", "cz": "Detail barvy","es": "Detalle",  "de": "Farbdetail","fr": "Détail"},
	"q_low":          {"en": "Low",  "cz": "Nízký",   "es": "Bajo",  "de": "Niedrig", "fr": "Bas"},
	"q_mid":          {"en": "Mid",  "cz": "Střední", "es": "Medio", "de": "Mittel",  "fr": "Moyen"},
	"q_high":         {"en": "High", "cz": "Vysoký",  "es": "Alto",  "de": "Hoch",    "fr": "Élevé"},
	"volume_label":   {"en": "Volume",   "cz": "Hlasitost", "es": "Volumen", "de": "Lautstärke", "fr": "Volume"},
	"language":       {"en": "Language", "cz": "Jazyk",     "es": "Idioma",  "de": "Sprache",    "fr": "Langue"},
	"auto":           {"en": "Auto",     "cz": "Auto",      "es": "Auto",    "de": "Auto",       "fr": "Auto"},
	"player_indicator": {"en": "Player Indicator", "cz": "Ukazatel hráče", "es": "Indicador de jugador", "de": "Spieler-Anzeige", "fr": "Indicateur joueur"},
	"color_distinction": {"en": "Color Distinction", "cz": "Odlišení barev", "es": "Distinción de color", "de": "Farbunterschied", "fr": "Distinction couleur"},
	"bg_brightness":  {"en": "Background Lightness", "cz": "Jas pozadí", "es": "Brillo del fondo", "de": "Hintergrundhelligkeit", "fr": "Luminosité du fond"},
	"display_label":  {"en": "DISPLAY", "cz": "ZOBRAZENÍ", "es": "PANTALLA", "de": "ANZEIGE", "fr": "AFFICHAGE"},
	"tab_game":       {"en": "GAME", "cz": "HRA", "es": "JUEGO", "de": "SPIEL", "fr": "JEU"},
	"tab_speedrun":   {"en": "SPEEDRUN", "cz": "SPEEDRUN", "es": "SPEEDRUN", "de": "SPEEDRUN", "fr": "SPEEDRUN"},
	"sr_desc":        {"en": "Wipes ALL progress — levels, challenges, statistics, achievements and skins — for a clean speedrun start. Settings are kept.", "cz": "Smaže VEŠKERÝ postup — levely, výzvy, statistiky, úspěchy i skiny — pro čistý speedrun start. Nastavení zůstane.", "es": "Borra TODO el progreso — niveles, desafíos, estadísticas, logros y aspectos — para un inicio limpio de speedrun. Los ajustes se conservan.", "de": "Löscht den GESAMTEN Fortschritt — Level, Prüfungen, Statistiken, Erfolge und Skins — für einen sauberen Speedrun-Start. Einstellungen bleiben erhalten.", "fr": "Efface TOUTE la progression — niveaux, défis, statistiques, succès et apparences — pour un départ speedrun propre. Les réglages sont conservés."},
	"sr_reset":       {"en": "RESET PROGRESS", "cz": "RESETOVAT PROGRES", "es": "REINICIAR PROGRESO", "de": "FORTSCHRITT ZURÜCKSETZEN", "fr": "RÉINITIALISER"},
	"sr_code_prompt": {"en": "To confirm, enter the code:", "cz": "Pro potvrzení zadej kód:", "es": "Para confirmar, introduce el código:", "de": "Zur Bestätigung Code eingeben:", "fr": "Pour confirmer, saisis le code :"},
	"sr_cancel":      {"en": "CANCEL", "cz": "ZRUŠIT", "es": "CANCELAR", "de": "ABBRECHEN", "fr": "ANNULER"},
	"game_zoom":      {"en": "Camera Zoom", "cz": "Přiblížení", "es": "Zoom de cámara", "de": "Kamera-Zoom", "fr": "Zoom caméra"},
	"gui_scale":      {"en": "Game GUI Size", "cz": "Velikost herního GUI", "es": "Tamaño de interfaz del juego", "de": "Spiel-GUI-Größe", "fr": "Taille de l'interface en jeu"},
	"left_handed":    {"en": "Left-handed", "cz": "Pro leváky", "es": "Para zurdos", "de": "Linkshändig", "fr": "Gaucher"},
	"screen_shake":   {"en": "Screen shake", "cz": "Otřesy obrazovky", "es": "Vibración de pantalla", "de": "Bildschirmwackeln", "fr": "Tremblement d'écran"},
	"ach_not_counted": {"en": "Not counted toward 100%", "cz": "Nepočítá se do 100%", "es": "No cuenta para el 100%", "de": "Zählt nicht zu 100%", "fr": "Non compté dans les 100%"},
	"hint_tap_item":  {"en": "Tap the item icon to use it", "cz": "Ťukni na ikonu předmětu a použij ho", "es": "Toca el icono del objeto para usarlo", "de": "Tippe auf das Item-Symbol, um es zu benutzen", "fr": "Touche l'icône de l'objet pour l'utiliser"},
	"hpbar_opacity":  {"en": "HP Bar Opacity", "cz": "Průhlednost HP", "es": "Opacidad de la barra de vida", "de": "HP-Leisten-Deckkraft", "fr": "Opacité de la barre de vie"},
	"dynamic_opacity": {"en": "Dynamic Opacity", "cz": "Dynamická průhlednost", "es": "Opacidad dinámica", "de": "Dynamische Deckkraft", "fr": "Opacité dynamique"},
	"desc_hpbar":     {"en": "Opacity of the health bar at the bottom of the screen.", "cz": "Průhlednost ukazatele zdraví dole na obrazovce.", "es": "Opacidad de la barra de vida en la parte inferior.", "de": "Deckkraft der HP-Leiste am unteren Rand.", "fr": "Opacité de la barre de vie en bas de l'écran."},
	"desc_dynamic":   {"en": "Fades the health bar to 40% when the player moves near it.", "cz": "Ztlumí ukazatel zdraví na 40 %, když k němu hráč přijede.", "es": "Atenúa la barra de vida al 40% cuando el jugador se acerca.", "de": "Blendet die HP-Leiste auf 40% aus, wenn der Spieler nah ist.", "fr": "Atténue la barre de vie à 40% quand le joueur s'approche."},
	"reset_defaults": {"en": "RESET", "cz": "VÝCHOZÍ", "es": "RESTABL.", "de": "RESET", "fr": "RÉINIT."},
	"desc_volume":    {"en": "Music and sound-effect volume.", "cz": "Hlasitost hudby a zvukových efektů.", "es": "Volumen de música y efectos.", "de": "Lautstärke von Musik und Soundeffekten.", "fr": "Volume de la musique et des effets."},
	"desc_language":  {"en": "Language of in-game text.", "cz": "Jazyk textů ve hře.", "es": "Idioma del texto del juego.", "de": "Sprache der Spieltexte.", "fr": "Langue des textes du jeu."},
	"desc_indicator": {"en": "Highlights the player with a colored ring for visibility.", "cz": "Zvýrazní hráče barevným kroužkem pro lepší přehled.", "es": "Resalta al jugador con un anillo de color.", "de": "Hebt den Spieler mit einem farbigen Ring hervor.", "fr": "Met en évidence le joueur avec un anneau coloré."},
	"desc_distinction": {"en": "How much darker floor splats are than monsters.", "cz": "Jak moc jsou cákance na zemi tmavší než monstra.", "es": "Cuánto más oscuras son las manchas que los monstruos.", "de": "Wie viel dunkler Bodenkleckse als Monster sind.", "fr": "À quel point les taches au sol sont plus sombres que les monstres."},
	"desc_bg_brightness": {"en": "Lightens the dark game background (useful on phones).", "cz": "Zesvětlí tmavé pozadí hry (užitečné na telefonech).", "es": "Aclara el fondo oscuro del juego (útil en móviles).", "de": "Hellt den dunklen Spielhintergrund auf (nützlich am Handy).", "fr": "Éclaircit le fond sombre du jeu (utile sur mobile)."},
	"desc_zoom":      {"en": "How close the camera sits to the player in-game.", "cz": "Jak blízko je kamera u hráče během hry.", "es": "Qué tan cerca está la cámara del jugador.", "de": "Wie nah die Kamera am Spieler ist.", "fr": "À quel point la caméra est proche du joueur."},
	"desc_gui":       {"en": "Size of in-game overlays (HP bar, inventory, timer, joysticks).", "cz": "Velikost herních překryvů (HP bar, inventář, časovač, joysticky).", "es": "Tamaño de la interfaz en juego (vida, inventario, temporizador).", "de": "Größe der Spiel-Overlays (HP, Inventar, Timer).", "fr": "Taille de l'interface en jeu (PV, inventaire, chrono)."},
	"desc_lefty":     {"en": "Swaps the joysticks - move on the right, aim on the left.", "cz": "Prohodí joysticky - pohyb vpravo, míření vlevo.", "es": "Intercambia los joysticks: mover a la derecha, apuntar a la izquierda.", "de": "Tauscht die Joysticks - Bewegen rechts, Zielen links.", "fr": "Inverse les joysticks - déplacement à droite, visée à gauche."},
	"opt_on":         {"en": "On",  "cz": "Zap", "es": "On",  "de": "An",  "fr": "On"},
	"opt_off":        {"en": "Off", "cz": "Vyp", "es": "Off", "de": "Aus", "fr": "Off"},

	# ---- Stats popup ----
	"tab_stats":         {"en": "STATS",        "cz": "STATISTIKY", "es": "ESTADÍSTICAS", "de": "STATISTIK", "fr": "STATS"},
	"tab_achievements":  {"en": "ACHIEVEMENTS", "cz": "ÚSPĚCHY",    "es": "LOGROS",       "de": "ERFOLGE",   "fr": "SUCCÈS"},
	"ach_unlocked":      {"en": "ACHIEVEMENT UNLOCKED", "cz": "ÚSPĚCH ODEMČEN", "es": "LOGRO DESBLOQUEADO", "de": "ERFOLG FREIGESCHALTET", "fr": "SUCCÈS DÉBLOQUÉ"},
	"ach_locked_hint":   {"en": "Locked", "cz": "Zamčeno", "es": "Bloqueado", "de": "Gesperrt", "fr": "Verrouillé"},
	"sec_progress":      {"en": "PROGRESS", "cz": "POSTUP", "es": "PROGRESO", "de": "FORTSCHRITT", "fr": "PROGRESSION"},
	"stats_global":      {"en": "GLOBAL", "cz": "GLOBÁLNÍ", "es": "GLOBALES", "de": "GLOBAL", "fr": "GLOBALES"},
	"stats_global_sub":  {"en": "kept on a speedrun reset", "cz": "zůstává i po speedrun resetu", "es": "se conserva al reiniciar speedrun", "de": "bleibt beim Speedrun-Reset", "fr": "conservé au reset speedrun"},
	"stats_run":         {"en": "THIS RUN", "cz": "TENTO RUN", "es": "ESTA PARTIDA", "de": "DIESER RUN", "fr": "CE RUN"},
	"stats_run_sub":     {"en": "wiped by a speedrun reset", "cz": "maže se speedrun resetem", "es": "se borra al reiniciar speedrun", "de": "wird beim Speedrun-Reset gelöscht", "fr": "effacé au reset speedrun"},
	"st_levels_done":    {"en": "Levels Completed", "cz": "Levelů dokončeno", "es": "Niveles completados", "de": "Level abgeschlossen", "fr": "Niveaux terminés"},
	"st_challenges_done": {"en": "Challenges Completed", "cz": "Challengí dokončeno", "es": "Desafíos completados", "de": "Prüfungen abgeschlossen", "fr": "Défis terminés"},
	"st_game_completion": {"en": "Game Completion", "cz": "Splnění hry", "es": "Juego completado", "de": "Spielfortschritt", "fr": "Jeu complété"},
	"sec_combat":        {"en": "COMBAT", "cz": "BOJ", "es": "COMBATE", "de": "KAMPF", "fr": "COMBAT"},
	"st_total_kills":    {"en": "Total Monsters Killed", "cz": "Zabito monster celkem", "es": "Monstruos eliminados", "de": "Getötete Monster", "fr": "Monstres tués"},
	"st_total_deaths":   {"en": "Total Deaths", "cz": "Počet úmrtí", "es": "Muertes totales", "de": "Tode gesamt", "fr": "Morts totales"},
	"st_bullets":        {"en": "Bullets Fired", "cz": "Vystřeleno nábojů", "es": "Disparos", "de": "Schüsse", "fr": "Tirs"},
	"sec_kills_type":    {"en": "KILLS BY TYPE", "cz": "ZABITÍ PODLE TYPU", "es": "BAJAS POR TIPO", "de": "TÖTUNGEN NACH TYP", "fr": "TUÉS PAR TYPE"},
	"sec_endless":       {"en": "ENDLESS MODE", "cz": "NEKONEČNÝ REŽIM", "es": "MODO INFINITO", "de": "ENDLOS-MODUS", "fr": "MODE INFINI"},
	"st_best_survival":  {"en": "Best Survival Time", "cz": "Nejlepší čas přežití", "es": "Mejor tiempo", "de": "Beste Zeit", "fr": "Meilleur temps"},
	"st_most_kills":     {"en": "Most Kills (Single Run)", "cz": "Nejvíc zabití (1 hra)", "es": "Más bajas (1 partida)", "de": "Meiste Kills (1 Lauf)", "fr": "Plus de tués (1 partie)"},
	"sec_time":          {"en": "TIME PLAYED", "cz": "ODEHRANÝ ČAS", "es": "TIEMPO JUGADO", "de": "SPIELZEIT", "fr": "TEMPS DE JEU"},
	"st_total_time":     {"en": "Total Play Time", "cz": "Celkový čas", "es": "Tiempo total", "de": "Gesamtzeit", "fr": "Temps total"},
	"st_longest":        {"en": "Longest Session", "cz": "Nejdelší hraní", "es": "Sesión más larga", "de": "Längste Sitzung", "fr": "Plus longue session"},
	"coming_soon":       {"en": "COMING SOON", "cz": "JIŽ BRZY", "es": "PRÓXIMAMENTE", "de": "DEMNÄCHST", "fr": "BIENTÔT"},
	"achievements_soon": {"en": "Achievements will be added in a future update.", "cz": "Úspěchy budou přidány v budoucí aktualizaci.", "es": "Los logros se añadirán en una futura actualización.", "de": "Erfolge folgen in einem zukünftigen Update.", "fr": "Les succès arriveront dans une future mise à jour."},

	# ---- Monster names ----
	"mon_basic":    {"en": "Basic",    "cz": "Základní",  "es": "Básico",    "de": "Standard", "fr": "Basique"},
	"mon_tank":     {"en": "Tank",     "cz": "Tank",      "es": "Tanque",    "de": "Panzer",   "fr": "Tank"},
	"mon_speeder":  {"en": "Speeder",  "cz": "Rychlík",   "es": "Veloz",     "de": "Flitzer",  "fr": "Rapide"},
	"mon_brute":    {"en": "Brute",    "cz": "Hromotluk", "es": "Bruto",     "de": "Brocken",  "fr": "Brute"},
	"mon_healer":   {"en": "Healer",   "cz": "Léčitel",   "es": "Sanador",   "de": "Heiler",   "fr": "Soigneur"},
	"mon_spawner":  {"en": "Spawner",  "cz": "Ploditel",  "es": "Generador", "de": "Erzeuger", "fr": "Pondeur"},
	"mon_splitter": {"en": "Splitter", "cz": "Dělič",     "es": "Divisor",   "de": "Teiler",   "fr": "Diviseur"},
	"mon_ghost":    {"en": "Ghost",    "cz": "Duch",      "es": "Fantasma",  "de": "Geist",    "fr": "Fantôme"},
	"mon_tankbomber": {"en": "Tankbomber", "cz": "Bombový tank", "es": "Tanque bomba", "de": "Bombenpanzer", "fr": "Tank-bombe"},

	# ---- Skins popup ----
	"select_skin":    {"en": "SELECT SKIN", "cz": "VYBER VZHLED", "es": "ELIGE ASPECTO", "de": "SKIN WÄHLEN", "fr": "CHOISIR SKIN"},
	"player":         {"en": "PLAYER", "cz": "HRÁČ", "es": "JUGADOR", "de": "SPIELER", "fr": "JOUEUR"},
	"trail":          {"en": "TRAIL",  "cz": "STOPA", "es": "ESTELA", "de": "SPUR", "fr": "TRAÎNÉE"},
	"cat_skins":      {"en": "Skins",  "cz": "Vzhledy", "es": "Aspectos", "de": "Skins", "fr": "Apparences"},
	"cat_trails":     {"en": "Trails", "cz": "Stopy", "es": "Estelas", "de": "Spuren", "fr": "Traînées"},
	"locked_in_rewards": {"en": "Unlock it in Daily Rewards!", "cz": "Odemkni v Odměnách!", "es": "¡Desbloquéalo en Recompensas!", "de": "Schalte es in Belohnungen frei!", "fr": "Débloque-le dans les Récompenses !"},
	"locked_in_achievement": {"en": "Unlock it with an achievement!", "cz": "Odemkni splněním úspěchu!", "es": "¡Desbloquéalo con un logro!", "de": "Schalte es mit einem Erfolg frei!", "fr": "Débloque-le avec un succès !"},

	# ---- Daily reward / lucky box ----
	"daily_title":    {"en": "DAILY REWARD", "cz": "ODMĚNY", "es": "RECOMPENSA", "de": "BELOHNUNG", "fr": "RÉCOMPENSE"},
	"daily_desc":     {"en": "Open the box for a random skin or trail!", "cz": "Otevři bednu a získej náhodný vzhled nebo stopu!", "es": "¡Abre la caja para un aspecto o estela al azar!", "de": "Öffne die Box für einen zufälligen Skin oder Spur!", "fr": "Ouvre la boîte pour un skin ou une traînée au hasard !"},
	"box_open":       {"en": "OPEN", "cz": "OTEVŘÍT", "es": "ABRIR", "de": "ÖFFNEN", "fr": "OUVRIR"},
	"box_open_ad":    {"en": "OPEN (AD)", "cz": "OTEVŘÍT ZA REKLAMU", "es": "ABRIR (ANUNCIO)", "de": "ÖFFNEN (WERBUNG)", "fr": "OUVRIR (PUB)"},
	"box_next_free":  {"en": "Next free box in", "cz": "Další bedna zdarma za", "es": "Próxima gratis en", "de": "Nächste gratis in", "fr": "Prochaine gratuite dans"},
	"box_all_title":  {"en": "ALL UNLOCKED!", "cz": "VŠE ODEMČENO!", "es": "¡TODO DESBLOQUEADO!", "de": "ALLES FREIGESCHALTET!", "fr": "TOUT DÉBLOQUÉ !"},
	"box_all_desc":   {"en": "You own every skin and trail! You can still spin just for fun — it gives duplicates, free and with no ads. Or support the author with an ad.", "cz": "Máš odemčené všechny vzhledy i stopy! Klidně si zatoč jen tak pro radost — dostaneš duplikát, zdarma a bez reklam. Nebo podpoř autora reklamou.", "es": "¡Tienes todos los aspectos y estelas! Aun así puedes girar por diversión — da duplicados, gratis y sin anuncios. O apoya al autor con un anuncio.", "de": "Du hast alle Skins und Spuren! Du kannst trotzdem zum Spaß drehen — gibt Duplikate, gratis und ohne Werbung. Oder unterstütze den Autor mit Werbung.", "fr": "Tu as tous les skins et traînées ! Tu peux quand même tourner pour le plaisir — ça donne des doublons, gratuit et sans pub. Ou soutiens l'auteur avec une pub."},
	"box_spin_fun":   {"en": "SPIN (FREE)", "cz": "ZATOČIT (ZDARMA)", "es": "GIRAR (GRATIS)", "de": "DREHEN (GRATIS)", "fr": "TOURNER (GRATUIT)"},
	"box_support_ad": {"en": "SUPPORT (AD)", "cz": "PODPOŘIT (REKLAMA)", "es": "APOYAR (ANUNCIO)", "de": "UNTERSTÜTZEN (WERBUNG)", "fr": "SOUTENIR (PUB)"},
	"box_thanks":     {"en": "Thanks for the support! ♥", "cz": "Díky za podporu! ♥", "es": "¡Gracias por el apoyo! ♥", "de": "Danke für die Unterstützung! ♥", "fr": "Merci pour le soutien ! ♥"},
	"box_you_won":    {"en": "YOU GOT", "cz": "ZÍSKAL JSI", "es": "HAS CONSEGUIDO", "de": "DU HAST", "fr": "TU AS OBTENU"},
	"box_duplicate":  {"en": "Duplicate — try again for a new one!", "cz": "Duplikát — zkus to znovu pro nový!", "es": "¡Duplicado — prueba otra vez!", "de": "Duplikat — versuch's nochmal!", "fr": "Doublon — réessaie !"},
	"box_duplicate_all": {"en": "Duplicate — you already own everything!", "cz": "Duplikát — vždyť už máš všechno!", "es": "¡Duplicado — ya lo tienes todo!", "de": "Duplikat — du hast schon alles!", "fr": "Doublon — tu as déjà tout !"},
	"go_to_skins":    {"en": "GO TO SKINS", "cz": "DO VZHLEDŮ", "es": "IR A ASPECTOS", "de": "ZU SKINS", "fr": "VOIR SKINS"},
	"coming_soon_lc": {"en": "Coming soon", "cz": "Již brzy", "es": "Próximamente", "de": "Demnächst", "fr": "Bientôt"},

	# ---- Death screen ----
	"game_over":       {"en": "GAME OVER", "cz": "KONEC HRY", "es": "FIN DEL JUEGO", "de": "SPIEL VORBEI", "fr": "PARTIE TERMINÉE"},
	"survival_time":   {"en": "SURVIVAL TIME", "cz": "ČAS PŘEŽITÍ", "es": "TIEMPO DE SUPERVIVENCIA", "de": "ÜBERLEBENSZEIT", "fr": "TEMPS DE SURVIE"},
	"monsters_killed": {"en": "MONSTERS KILLED", "cz": "ZABITÁ MONSTRA", "es": "MONSTRUOS ELIMINADOS", "de": "GETÖTETE MONSTER", "fr": "MONSTRES TUÉS"},
	"retry":           {"en": "RETRY", "cz": "ZNOVU", "es": "REINTENTAR", "de": "NOCHMAL", "fr": "RÉESSAYER"},
	"next_level":      {"en": "NEXT LEVEL", "cz": "DALŠÍ LEVEL", "es": "SIGUIENTE NIVEL", "de": "NÄCHSTES LEVEL", "fr": "NIVEAU SUIVANT"},
	"new_best":        {"en": "NEW PERSONAL BEST!", "cz": "NOVÝ OSOBNÍ REKORD!", "es": "¡NUEVO RÉCORD!", "de": "NEUER REKORD!", "fr": "NOUVEAU RECORD !"},
	"best":            {"en": "BEST", "cz": "NEJ", "es": "MEJOR", "de": "BEST", "fr": "MEILLEUR"},
}

## Localized string for `key` in the active language (falls back to English).
static func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	if entry.is_empty():
		return key
	var lang := current_lang()
	return String(entry.get(lang, entry.get("en", key)))

## Active concrete language code ("en"/"cz"/"es"/"de"/"fr"), resolving "system".
static func current_lang() -> String:
	var s := String(SaveManager.get_setting("language", "system"))
	if s == "system" or s == "auto":
		return _system_lang()
	return s if s in LANGS else "en"

static func _system_lang() -> String:
	var loc := OS.get_locale().to_lower()
	if loc.begins_with("cs"): return "cz"
	if loc.begins_with("es"): return "es"
	if loc.begins_with("de"): return "de"
	if loc.begins_with("fr"): return "fr"
	return "en"

## Short uppercase code for indicators ("EN"/"CZ"/"ES"/"DE"/"FR").
static func lang_code() -> String:
	return current_lang().to_upper()
