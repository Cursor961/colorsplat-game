class_name SkinData
## Player skin metadata registry for ColorSplat! — names + descriptions in
## en/cz/es/de/fr. Skins authored as SVG outside the project and copied into
## res://assets/sprites/player/skins/<id>.svg (see SpriteLoader.SKINS_DIR);
## "default" is the baked-in res://assets/sprites/player/player_default.svg.
## Skin id = copied filename without .svg (e.g. "Player_nerd"). Ownership (locked
## until won from the daily box) lives in SaveManager, not here.

const Loc := preload("res://scripts/utils/localization.gd")

const DEFAULT_SKIN := "default"

const SKINS: Dictionary = {
	"default": {
		"name_en": "Classic", "name_cz": "Klasik", "name_es": "Clásico", "name_de": "Klassisch", "name_fr": "Classique",
		"desc_en": "The basic skin.", "desc_cz": "Základní skin.", "desc_es": "El aspecto básico.", "desc_de": "Der Standard-Skin.", "desc_fr": "L'apparence de base.",
	},
	"Player_alien": {
		"name_en": "Alien", "name_cz": "Vetřelec", "name_es": "Alien", "name_de": "Alien", "name_fr": "Alien",
		"desc_en": "They are coming", "desc_cz": "Už jsou na cestě", "desc_es": "Ya vienen", "desc_de": "Sie kommen", "desc_fr": "Ils arrivent",
	},
	"Player_badsoup": {
		"name_en": "Bad Soup", "name_cz": "Špatná polévka", "name_es": "Mala Sopa", "name_de": "Schlechte Suppe", "name_fr": "Mauvaise Soupe",
		"desc_en": "Might throw up during game", "desc_cz": "Moc mi nechutnalo", "desc_es": "Puede que vomite durante la partida", "desc_de": "Könnte im Spiel kotzen", "desc_fr": "Pourrait vomir pendant la partie",
	},
	"Player_bomb": {
		"name_en": "Bomb", "name_cz": "Bomba", "name_es": "Bomba", "name_de": "Bombe", "name_fr": "Bombe",
		"desc_en": "7355608", "desc_cz": "7355608", "desc_es": "7355608", "desc_de": "7355608", "desc_fr": "7355608",
	},
	"Player_donut": {
		"name_en": "Donut", "name_cz": "Donut", "name_es": "Dónut", "name_de": "Donut", "name_fr": "Donut",
		"desc_en": "First day with blender!", "desc_cz": "První den v blenderu!", "desc_es": "¡Primer día con la batidora!", "desc_de": "Erster Tag mit dem Mixer!", "desc_fr": "Premier jour au mixeur !",
	},
	"Player_frozen": {
		"name_en": "Frozen", "name_cz": "Zmrzlý", "name_es": "Congelado", "name_de": "Eingefroren", "name_fr": "Gelé",
		"desc_en": "Stay cool", "desc_cz": "Přímo z mrazáku!", "desc_es": "Mantén la calma", "desc_de": "Bleib cool", "desc_fr": "Reste cool",
	},
	"Player_hater": {
		"name_en": "Hater", "name_cz": "Hejtr", "name_es": "Hater", "name_de": "Hater", "name_fr": "Rageux",
		"desc_en": "Skill issue", "desc_cz": "Skill issue", "desc_es": "Skill issue", "desc_de": "Skill issue", "desc_fr": "Skill issue",
	},
	"Player_knight": {
		"name_en": "Knight", "name_cz": "Rytíř", "name_es": "Caballero", "name_de": "Ritter", "name_fr": "Chevalier",
		"desc_en": "Collecting heads", "desc_cz": "Sbírá hlavy", "desc_es": "Coleccionando cabezas", "desc_de": "Sammelt Köpfe", "desc_fr": "Collectionne les têtes",
	},
	"Player_machinery": {
		"name_en": "Machinery", "name_cz": "Stroj", "name_es": "Maquinaria", "name_de": "Maschine", "name_fr": "Machinerie",
		"desc_en": "Blue collar", "desc_cz": "Těžká dřina", "desc_es": "Obrero", "desc_de": "Malocher", "desc_fr": "Col bleu",
	},
	"Player_minesweep": {
		"name_en": "Minesweep", "name_cz": "Hledač min", "name_es": "Buscaminas", "name_de": "Minensucher", "name_fr": "Démineur",
		"desc_en": "Comes with 50% chance of explosion!", "desc_cz": "S 50% šancí na explozi!", "desc_es": "¡Viene con un 50% de probabilidad de explotar!", "desc_de": "Mit 50% Explosionschance!", "desc_fr": "Avec 50% de chance d'exploser !",
	},
	"Player_mogus": {
		"name_en": "Mogus", "name_cz": "Mogus", "name_es": "Mogus", "name_de": "Mogus", "name_fr": "Mogus",
		"desc_en": "It's him!", "desc_cz": "Je to on!", "desc_es": "¡Es él!", "desc_de": "Er ist es!", "desc_fr": "C'est lui !",
	},
	"Player_nerd": {
		"name_en": "Nerd", "name_cz": "Šprt", "name_es": "Empollón", "name_de": "Streber", "name_fr": "Nerd",
		"desc_en": "Ehm... Actually...", "desc_cz": "Uhm... Ale...", "desc_es": "Ehm... En realidad...", "desc_de": "Ähm... Eigentlich...", "desc_fr": "Euh... En fait...",
	},
	"Player_ninja": {
		"name_en": "Ninja", "name_cz": "Nindža", "name_es": "Ninja", "name_de": "Ninja", "name_fr": "Ninja",
		"desc_en": "Not that one from Fortnite", "desc_cz": "Ne ten z Fortnitu!", "desc_es": "No el de Fortnite", "desc_de": "Nicht der aus Fortnite", "desc_fr": "Pas celui de Fortnite",
	},
	"Player_pause": {
		"name_en": "Pause", "name_cz": "Pauza", "name_es": "Pausa", "name_de": "Pause", "name_fr": "Pause",
		"desc_en": "What an ugly skin!", "desc_cz": "Stejně si tento skin nevybereš. lol", "desc_es": "¡Qué aspecto tan feo!", "desc_de": "Was für ein hässlicher Skin!", "desc_fr": "Quel skin moche !",
	},
	"Player_princess": {
		"name_en": "Princess", "name_cz": "Princezna", "name_es": "Princesa", "name_de": "Prinzessin", "name_fr": "Princesse",
		"desc_en": "Comes with flying pegasus", "desc_cz": "Přijde s létajícím pegasem", "desc_es": "Viene con pegaso volador", "desc_de": "Kommt mit fliegendem Pegasus", "desc_fr": "Livré avec un pégase volant",
	},
	"Player_rambo": {
		"name_en": "Rambo", "name_cz": "Rambo", "name_es": "Rambo", "name_de": "Rambo", "name_fr": "Rambo",
		"desc_en": "First blood", "desc_cz": "Zdecimuj je všechny!", "desc_es": "Primera sangre", "desc_de": "Erstes Blut", "desc_fr": "Premier sang",
	},
	"Player_Surprised": {
		"name_en": "Surprised", "name_cz": "Překvapený", "name_es": "Sorprendido", "name_de": "Überrascht", "name_fr": "Surpris",
		"desc_en": "Wait, what?!", "desc_cz": "Počkej, co?!", "desc_es": "¿Espera, qué?!", "desc_de": "Warte, was?!", "desc_fr": "Attends, quoi ?!",
	},
	"Player_deadrose": {
		"name_en": "Dead Rose", "name_cz": "Uvadlá růže", "name_es": "Rosa Marchita", "name_de": "Welke Rose", "name_fr": "Rose Fanée",
		"desc_en": "Bro...", "desc_cz": "Bro...", "desc_es": "Bro...", "desc_de": "Bro...", "desc_fr": "Bro...",
	},
	"Player_familiar": {
		"name_en": "Familiar", "name_cz": "Známý", "name_es": "Familiar", "name_de": "Vertraut", "name_fr": "Familier",
		"desc_en": "Have we met before?", "desc_cz": "Neznáme se odněkud?", "desc_es": "¿Nos conocemos?", "desc_de": "Kennen wir uns?", "desc_fr": "On s'est déjà vus ?",
	},
	"Player_heisenberg": {
		"name_en": "Heisenberg", "name_cz": "Heisenberg", "name_es": "Heisenberg", "name_de": "Heisenberg", "name_fr": "Heisenberg",
		"desc_en": "Say my name.", "desc_cz": "Řekni mé jméno.", "desc_es": "Di mi nombre.", "desc_de": "Sag meinen Namen.", "desc_fr": "Dis mon nom.",
	},
	"Player_racer": {
		"name_en": "Racer", "name_cz": "Závodník", "name_es": "Corredor", "name_de": "Rennfahrer", "name_fr": "Pilote",
		"desc_en": "Born to go fast.", "desc_cz": "Zrozen pro rychlost.", "desc_es": "Nacido para correr.", "desc_de": "Geboren für Tempo.", "desc_fr": "Né pour la vitesse.",
	},
	"Player_robot": {
		"name_en": "Robot", "name_cz": "Robot", "name_es": "Robot", "name_de": "Roboter", "name_fr": "Robot",
		"desc_en": "No jumping here!", "desc_cz": "Tady se neskáče!", "desc_es": "¡Aquí no se salta!", "desc_de": "Hier wird nicht gesprungen!", "desc_fr": "Ici, on ne saute pas !",
	},
	"Player_deprived": {
		"name_en": "Deprived", "name_cz": "Vyčerpaný", "name_es": "Privado", "name_de": "Entzogen", "name_fr": "Privé",
		"desc_en": "Touch grass. (Played 5 hours)", "desc_cz": "Běž si ven. (5 h ve hře)", "desc_es": "Toca pasto. (5 h jugadas)", "desc_de": "Geh mal raus. (5 Std gespielt)", "desc_fr": "Va dehors. (5 h jouées)",
	},
	"Player_brehowski": {
		"name_en": "Brehowski", "name_cz": "Brehowski", "name_es": "Brehowski", "name_de": "Brehowski", "name_fr": "Brehowski",
		"desc_en": "Came to carry out the final execution.", "desc_cz": "Přišel vykonat poslední exekuci.", "desc_es": "Vino a ejecutar la última sentencia.", "desc_de": "Kam, um die letzte Hinrichtung zu vollstrecken.", "desc_fr": "Venu exécuter la dernière sentence.",
	},
	"Player_100": {
		"name_en": "100%", "name_cz": "100 %", "name_es": "100%", "name_de": "100%", "name_fr": "100%",
		"desc_en": "Congrats on 100% completion. — The Author", "desc_cz": "Gratuluji k dokončení hry na 100 %. — Autor", "desc_es": "Felicidades por completar el juego al 100%. — El Autor", "desc_de": "Glückwunsch zum 100%-Abschluss. — Der Autor", "desc_fr": "Félicitations pour le 100%. — L'Auteur",
	},
	"Player_blue": {
		"name_en": "Blue", "name_cz": "Modrá", "name_es": "Azul", "name_de": "Blau", "name_fr": "Bleu",
		"desc_en": "Feeling blue.", "desc_cz": "Modré jako z pohádky.", "desc_es": "Sintiéndose azul.", "desc_de": "Ganz schön blau.", "desc_fr": "Le blues.",
	},
	"Player_cyan": {
		"name_en": "Cyan", "name_cz": "Tyrkysová", "name_es": "Cian", "name_de": "Cyan", "name_fr": "Cyan",
		"desc_en": "Cool to the touch.", "desc_cz": "Chladí už od pohledu.", "desc_es": "Fresco al tacto.", "desc_de": "Kühl im Griff.", "desc_fr": "Frais au toucher.",
	},
	"Player_green": {
		"name_en": "Green", "name_cz": "Zelená", "name_es": "Verde", "name_de": "Grün", "name_fr": "Vert",
		"desc_en": "Eco-friendly mayhem.", "desc_cz": "Ekologický chaos.", "desc_es": "Caos ecológico.", "desc_de": "Umweltfreundliches Chaos.", "desc_fr": "Chaos écolo.",
	},
	"Player_orange": {
		"name_en": "Orange", "name_cz": "Oranžová", "name_es": "Naranja", "name_de": "Orange", "name_fr": "Orange",
		"desc_en": "Freshly squeezed.", "desc_cz": "Čerstvě vymačkaná.", "desc_es": "Recién exprimido.", "desc_de": "Frisch gepresst.", "desc_fr": "Fraîchement pressé.",
	},
	"Player_pink": {
		"name_en": "Pink", "name_cz": "Růžová", "name_es": "Rosa", "name_de": "Pink", "name_fr": "Rose",
		"desc_en": "Think pink.", "desc_cz": "Mysli růžově.", "desc_es": "Piensa en rosa.", "desc_de": "Denk pink.", "desc_fr": "Pense rose.",
	},
	"Player_purple": {
		"name_en": "Purple", "name_cz": "Fialová", "name_es": "Morado", "name_de": "Lila", "name_fr": "Violet",
		"desc_en": "Royally violent.", "desc_cz": "Královsky nebezpečná.", "desc_es": "Violencia real.", "desc_de": "Königlich brutal.", "desc_fr": "Royalement violent.",
	},
	"Player_white": {
		"name_en": "White", "name_cz": "Bílá", "name_es": "Blanco", "name_de": "Weiß", "name_fr": "Blanc",
		"desc_en": "A clean slate.", "desc_cz": "Čistý štít.", "desc_es": "Borrón y cuenta nueva.", "desc_de": "Reine Weste.", "desc_fr": "Page blanche.",
	},
	"Player_skeleton": {
		"name_en": "Skeleton", "name_cz": "Kostlivec", "name_es": "Esqueleto", "name_de": "Skelett", "name_fr": "Squelette",
		"desc_en": "Only a true madman owns this skin — congratulations!", "desc_cz": "Tento skin má jen opravdový blázen — gratuluji!", "desc_es": "Solo un verdadero loco tiene este aspecto — ¡felicidades!", "desc_de": "Diesen Skin besitzt nur ein wahrer Verrückter — Glückwunsch!", "desc_fr": "Seul un vrai fou possède cette apparence — félicitations !",
	},
}

static func get_info(skin_id: String) -> Dictionary:
	return SKINS.get(skin_id, {})

static func get_display_name(skin_id: String) -> String:
	var s := get_info(skin_id)
	return _localized(s, "name") if not s.is_empty() else _prettify(skin_id)

static func get_description(skin_id: String) -> String:
	var s := get_info(skin_id)
	return _localized(s, "desc") if not s.is_empty() else ""

## Legacy hooks (ownership now lives in SaveManager). Kept for compatibility.
static func is_unlocked(_skin_id: String) -> bool:
	return true

static func get_milestone(_skin_id: String) -> String:
	return ""

static func _localized(s: Dictionary, prefix: String) -> String:
	var lang := Loc.current_lang()
	return String(s.get(prefix + "_" + lang, s.get(prefix + "_en", "")))

## "ice_dragon" -> "Ice Dragon" (fallback for files without a registry entry)
static func _prettify(skin_id: String) -> String:
	var parts := skin_id.replace("_", " ").replace("-", " ").split(" ", false)
	var out: PackedStringArray = []
	for p: String in parts:
		if p.length() > 0:
			out.append(p.substr(0, 1).to_upper() + p.substr(1))
	return " ".join(out)
