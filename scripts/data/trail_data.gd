class_name TrailData
## Player trail registry for ColorSplat! — names + descriptions in en/cz/es/de/fr.
## Authored as SVG and copied to res://assets/sprites/player/trails/<id>.svg.
## "none" = no trail (default). Ownership lives in SaveManager.

const Loc := preload("res://scripts/utils/localization.gd")
const TRAILS_DIR := "res://assets/sprites/player/trails/"

const TRAILS: Array = [
	{
		"id": "none",
		"name_en": "None", "name_cz": "Žádná", "name_es": "Ninguna", "name_de": "Keine", "name_fr": "Aucune",
		"desc_en": "No trail.", "desc_cz": "Bez stopy.", "desc_es": "Sin estela.", "desc_de": "Keine Spur.", "desc_fr": "Aucune traînée.",
	},
	{
		"id": "greentrail",
		"name_en": "Green Comet", "name_cz": "Zelená kometa", "name_es": "Cometa Verde", "name_de": "Grüner Komet", "name_fr": "Comète Verte",
		"desc_en": "A glowing green streak behind you.", "desc_cz": "Zářivá zelená stopa za tebou.", "desc_es": "Una estela verde brillante tras de ti.", "desc_de": "Ein leuchtender grüner Schweif hinter dir.", "desc_fr": "Une traînée verte lumineuse derrière toi.",
	},
	{
		"id": "bluetrail",
		"name_en": "Blue Comet", "name_cz": "Modrá kometa", "name_es": "Cometa Azul", "name_de": "Blauer Komet", "name_fr": "Comète Bleue",
		"desc_en": "A cool blue streak in your wake.", "desc_cz": "Chladná modrá stopa za tebou.", "desc_es": "Una estela azul fría tras de ti.", "desc_de": "Ein kühler blauer Schweif hinter dir.", "desc_fr": "Une traînée bleue glaciale derrière toi.",
	},
	{
		"id": "cyantrail",
		"name_en": "Cyan Pulse", "name_cz": "Tyrkysový puls", "name_es": "Pulso Cian", "name_de": "Cyan-Puls", "name_fr": "Pulsation Cyan",
		"desc_en": "Electric cyan energy follows you.", "desc_cz": "Elektrická tyrkysová energie tě následuje.", "desc_es": "Energía cian eléctrica te sigue.", "desc_de": "Elektrische cyanfarbene Energie folgt dir.", "desc_fr": "Une énergie cyan électrique te suit.",
	},
	{
		"id": "orangetrail",
		"name_en": "Ember Trail", "name_cz": "Žhavá stopa", "name_es": "Estela de Brasa", "name_de": "Glut-Spur", "name_fr": "Traînée de Braise",
		"desc_en": "Glowing embers trail behind you.", "desc_cz": "Žhnoucí uhlíky se táhnou za tebou.", "desc_es": "Brasas ardientes te siguen.", "desc_de": "Glühende Glut zieht hinter dir her.", "desc_fr": "Des braises ardentes te suivent.",
	},
	{
		"id": "pinktrail",
		"name_en": "Bubblegum", "name_cz": "Žvýkačka", "name_es": "Chicle", "name_de": "Kaugummi", "name_fr": "Chewing-gum",
		"desc_en": "Sweet pink, sticky speed.", "desc_cz": "Sladká růžová rychlost.", "desc_es": "Rosa dulce, velocidad pegajosa.", "desc_de": "Süßes Pink, klebriges Tempo.", "desc_fr": "Rose sucré, vitesse collante.",
	},
	{
		"id": "purpletrail",
		"name_en": "Void Streak", "name_cz": "Fialová mlha", "name_es": "Estela del Vacío", "name_de": "Leerenspur", "name_fr": "Traînée du Vide",
		"desc_en": "A trail torn from the void.", "desc_cz": "Stopa vytržená z prázdnoty.", "desc_es": "Una estela arrancada del vacío.", "desc_de": "Eine Spur aus der Leere gerissen.", "desc_fr": "Une traînée arrachée au vide.",
	},
	{
		"id": "redtrail",
		"name_en": "Crimson Streak", "name_cz": "Rudá stopa", "name_es": "Estela Carmesí", "name_de": "Purpurstreif", "name_fr": "Traînée Cramoisie",
		"desc_en": "Leave a blood-red blur.", "desc_cz": "Zanech krvavě rudou šmouhu.", "desc_es": "Deja un borrón rojo sangre.", "desc_de": "Hinterlasse einen blutroten Schweif.", "desc_fr": "Laisse un flou rouge sang.",
	},
	{
		"id": "whitetrail",
		"name_en": "Spirit Trail", "name_cz": "Duchová stopa", "name_es": "Estela Espectral", "name_de": "Geisterspur", "name_fr": "Traînée Spectrale",
		"desc_en": "A pale, ghostly glow.", "desc_cz": "Bledá, přízračná záře.", "desc_es": "Un resplandor pálido y fantasmal.", "desc_de": "Ein blasses, geisterhaftes Leuchten.", "desc_fr": "Une lueur pâle et spectrale.",
	},
	{
		"id": "yellowtrail",
		"name_en": "Lightning", "name_cz": "Blesk", "name_es": "Relámpago", "name_de": "Blitz", "name_fr": "Éclair",
		"desc_en": "Crackling yellow lightning.", "desc_cz": "Praskající žlutý blesk.", "desc_es": "Relámpago amarillo crepitante.", "desc_de": "Knisternder gelber Blitz.", "desc_fr": "Éclair jaune crépitant.",
	},
	{
		"id": "rainbowtrail",
		"name_en": "Rainbow", "name_cz": "Duha", "name_es": "Arcoíris", "name_de": "Regenbogen", "name_fr": "Arc-en-ciel",
		"desc_en": "Every colour of the rainbow trails behind you.", "desc_cz": "Za tebou se táhne celá duha.", "desc_es": "Todos los colores del arcoíris te siguen.", "desc_de": "Alle Farben des Regenbogens hinter dir.", "desc_fr": "Toutes les couleurs de l'arc-en-ciel te suivent.",
	},
	{
		"id": "bluespark", "style": "spark",
		"name_en": "Blue Sparks", "name_cz": "Modré jiskry", "name_es": "Chispas Azules", "name_de": "Blaue Funken", "name_fr": "Étincelles Bleues",
		"desc_en": "Shimmering blue sparks crackle in your wake.", "desc_cz": "Za tebou praská roj modrých jisker.", "desc_es": "Chispas azules crepitan tras de ti.", "desc_de": "Blaue Funken sprühen hinter dir.", "desc_fr": "Des étincelles bleues crépitent derrière toi.",
	},
	{
		"id": "greenspark", "style": "spark",
		"name_en": "Green Sparks", "name_cz": "Zelené jiskry", "name_es": "Chispas Verdes", "name_de": "Grüne Funken", "name_fr": "Étincelles Vertes",
		"desc_en": "Shimmering green sparks crackle in your wake.", "desc_cz": "Za tebou praská roj zelených jisker.", "desc_es": "Chispas verdes crepitan tras de ti.", "desc_de": "Grüne Funken sprühen hinter dir.", "desc_fr": "Des étincelles vertes crépitent derrière toi.",
	},
	{
		"id": "orangespark", "style": "spark",
		"name_en": "Orange Sparks", "name_cz": "Oranžové jiskry", "name_es": "Chispas Naranjas", "name_de": "Orange Funken", "name_fr": "Étincelles Orange",
		"desc_en": "Shimmering orange sparks crackle in your wake.", "desc_cz": "Za tebou praská roj oranžových jisker.", "desc_es": "Chispas naranjas crepitan tras de ti.", "desc_de": "Orange Funken sprühen hinter dir.", "desc_fr": "Des étincelles orange crépitent derrière toi.",
	},
	{
		"id": "pinkspark", "style": "spark",
		"name_en": "Pink Sparks", "name_cz": "Růžové jiskry", "name_es": "Chispas Rosas", "name_de": "Rosa Funken", "name_fr": "Étincelles Roses",
		"desc_en": "Shimmering pink sparks crackle in your wake.", "desc_cz": "Za tebou praská roj růžových jisker.", "desc_es": "Chispas rosas crepitan tras de ti.", "desc_de": "Rosa Funken sprühen hinter dir.", "desc_fr": "Des étincelles roses crépitent derrière toi.",
	},
	{
		"id": "redspark", "style": "spark",
		"name_en": "Red Sparks", "name_cz": "Rudé jiskry", "name_es": "Chispas Rojas", "name_de": "Rote Funken", "name_fr": "Étincelles Rouges",
		"desc_en": "Shimmering red sparks crackle in your wake.", "desc_cz": "Za tebou praská roj rudých jisker.", "desc_es": "Chispas rojas crepitan tras de ti.", "desc_de": "Rote Funken sprühen hinter dir.", "desc_fr": "Des étincelles rouges crépitent derrière toi.",
	},
	{
		"id": "whitespark", "style": "spark",
		"name_en": "White Sparks", "name_cz": "Bílé jiskry", "name_es": "Chispas Blancas", "name_de": "Weiße Funken", "name_fr": "Étincelles Blanches",
		"desc_en": "Shimmering white sparks crackle in your wake.", "desc_cz": "Za tebou praská roj bílých jisker.", "desc_es": "Chispas blancas crepitan tras de ti.", "desc_de": "Weiße Funken sprühen hinter dir.", "desc_fr": "Des étincelles blanches crépitent derrière toi.",
	},
]

static func get_info(id: String) -> Dictionary:
	for t: Dictionary in TRAILS:
		if t.get("id", "") == id:
			return t
	return {}

## Render style of a trail: "ribbon" (stretched Line2D, the default comet trails) or
## "spark" (popping spark sprites — SparkTrail).
static func get_style(id: String) -> String:
	return String(get_info(id).get("style", "ribbon"))

## Texture path for a trail (the FULL/normal art used to render the trail in-game),
## or "" for "none"/unknown.
static func texture_path(id: String) -> String:
	if id == "none" or id == "" or get_info(id).is_empty():
		return ""
	return TRAILS_DIR + id + ".svg"

## Preview ("nahled") art used for the lootbox + skins menu thumbnails. Falls back
## to the normal art if a dedicated preview SVG isn't present.
static func preview_path(id: String) -> String:
	if id == "none" or id == "" or get_info(id).is_empty():
		return ""
	var p := TRAILS_DIR + id + "_nahled.svg"
	return p if ResourceLoader.exists(p) else texture_path(id)

static func display_name(id: String) -> String:
	var t := get_info(id)
	return _localized(t, "name") if not t.is_empty() else id

static func get_desc(id: String) -> String:
	var t := get_info(id)
	return _localized(t, "desc") if not t.is_empty() else ""

static func _localized(t: Dictionary, prefix: String) -> String:
	var lang := Loc.current_lang()
	return String(t.get(prefix + "_" + lang, t.get(prefix + "_en", "")))
