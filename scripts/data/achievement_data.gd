class_name AchievementData
## Achievement registry for ColorSplat! — names + descriptions in en/cz/es/de/fr.
## Icons authored in ColorSplat!/icons/achievements/, copied to
## res://assets/sprites/ui/achievements/<id>.svg. `auto` marks conditions tracked
## in code now. Language resolution is shared with Localization.

const Loc := preload("res://scripts/utils/localization.gd")
const TrailMeta := preload("res://scripts/data/trail_data.gd")
## The challenge registry (for the complete-5 / complete-all progress + checks).
const ChallengeReg := preload("res://scripts/ui/challenge_select_popup.gd")
const ICON_DIR := "res://assets/sprites/ui/achievements/"
## Mystery icon shown for hidden achievements while they're still locked.
const SECRET_ICON := ICON_DIR + "game_secretachievementicon.svg"

## Achievements with cumulative, cross-session progress — shown as a progress bar on
## the achievements screen while still locked. Everything else is a single-run feat
## (no bar). Value = the "kind" computed in get_progress().
const PROGRESS: Dictionary = {
	"game_playfor24hours": "time24",
	"game_die100times": "deaths100",
	"game_unlock5skins": "skins5",
	"game_unlockallskins": "collection",
	"game_unlockallachievements": "allach",
	"game_complete5challenges": "chal5",
	"game_completeallchallenges": "chalall",
	"game_completeallchallengesON3STARS": "chal3stars",
}

## Achievements that DON'T count toward 100 % completion: cosmetic collection + playtime.
## "Full Wardrobe" would even be circular (owning ALL skins needs the 100 % reward skin), so
## these are excluded from the meta "100 % Complete" check, kept through a SPEEDRUN reset
## (along with owned skins), and shown as a separate group in the achievements list.
const NON_COMPLETION_IDS := ["game_unlock5skins", "game_unlockallskins", "game_playfor24hours"]

const ACHIEVEMENTS: Array = [
	{
		"id": "endless_survive3mins", "auto": true, "color": Color(0.30, 0.80, 0.35),
		"name_en": "Just Warming Up", "name_cz": "Teprve se zahřívám", "name_es": "Calentando", "name_de": "Erst Aufgewärmt", "name_fr": "Échauffement",
		"desc_en": "Survive 3 minutes in Endless.", "desc_cz": "Přežij 3 minuty v Nekonečném režimu.", "desc_es": "Sobrevive 3 minutos en Infinito.", "desc_de": "Überlebe 3 Minuten im Endlos-Modus.", "desc_fr": "Survis 3 minutes en mode Infini.",
	},
	{
		"id": "endless_survive5mins", "auto": true, "color": Color(0.30, 0.80, 0.35),
		"name_en": "Still Standing", "name_cz": "Pořád ve hře", "name_es": "Sigo en Pie", "name_de": "Immer Noch Da", "name_fr": "Toujours Debout",
		"desc_en": "Survive 5 minutes in Endless.", "desc_cz": "Přežij 5 minut v Nekonečném režimu.", "desc_es": "Sobrevive 5 minutos en Infinito.", "desc_de": "Überlebe 5 Minuten im Endlos-Modus.", "desc_fr": "Survis 5 minutes en mode Infini.",
	},
	{
		"id": "endless_survive10mins", "auto": true, "color": Color(0.30, 0.80, 0.35),
		"name_en": "Unkillable", "name_cz": "Nezničitelný", "name_es": "Inmortal", "name_de": "Unsterblich", "name_fr": "Increvable",
		"desc_en": "Survive 10 minutes in Endless.", "desc_cz": "Přežij 10 minut v Nekonečném režimu.", "desc_es": "Sobrevive 10 minutos en Infinito.", "desc_de": "Überlebe 10 Minuten im Endlos-Modus.", "desc_fr": "Survis 10 minutes en mode Infini.",
	},
	{
		"id": "endless_kill200enemies_onelife", "auto": true, "color": Color(0.95, 0.55, 0.15),
		"name_en": "Exterminator", "name_cz": "Hubitel", "name_es": "Exterminador", "name_de": "Kammerjäger", "name_fr": "Exterminateur",
		"desc_en": "Kill 200 enemies in a single life in Endless.", "desc_cz": "Zabij 200 nepřátel během jednoho života v Nekonečném režimu.", "desc_es": "Elimina 200 enemigos en una vida en Infinito.", "desc_de": "Töte 200 Gegner in einem Leben im Endlos-Modus.", "desc_fr": "Tue 200 ennemis en une vie en mode Infini.",
	},
	{
		"id": "endless_kill500enemies_onelife", "auto": true, "color": Color(0.95, 0.45, 0.12),
		"name_en": "Massacre", "name_cz": "Masakr", "name_es": "Masacre", "name_de": "Massaker", "name_fr": "Massacre",
		"desc_en": "Kill 500 enemies in a single life in Endless.", "desc_cz": "Zabij 500 nepřátel během jednoho života v Nekonečném režimu.", "desc_es": "Elimina 500 enemigos en una vida en Infinito.", "desc_de": "Töte 500 Gegner in einem Leben im Endlos-Modus.", "desc_fr": "Tue 500 ennemis en une vie en mode Infini.",
	},
	{
		"id": "endless_kill1000enemies_onelife", "auto": true, "color": Color(0.95, 0.30, 0.20),
		"name_en": "One-Man Army", "name_cz": "Jednočlenná armáda", "name_es": "Ejército de Uno", "name_de": "Ein-Mann-Armee", "name_fr": "Armée à Lui Seul",
		"desc_en": "Kill 1000 enemies in a single life in Endless.", "desc_cz": "Zabij 1000 nepřátel během jednoho života v Nekonečném režimu.", "desc_es": "Elimina 1000 enemigos en una vida en Infinito.", "desc_de": "Töte 1000 Gegner in einem Leben im Endlos-Modus.", "desc_fr": "Tue 1000 ennemis en une vie en mode Infini.",
	},
	{
		"id": "endless_morethan3powerups", "auto": true, "color": Color(0.40, 0.70, 1.0),
		"name_en": "Power Overload", "name_cz": "Přetížení silou", "name_es": "Sobrecarga", "name_de": "Power-Überladung", "name_fr": "Surcharge",
		"desc_en": "Have more than 3 powerups active at once in Endless.", "desc_cz": "Měj v Nekonečném režimu aktivní více než 3 powerupy najednou.", "desc_es": "Ten más de 3 mejoras activas a la vez en Infinito.", "desc_de": "Habe im Endlos-Modus mehr als 3 Powerups gleichzeitig aktiv.", "desc_fr": "Aie plus de 3 bonus actifs en même temps en mode Infini.",
	},
	{
		"id": "endless_getkilledbybasic", "auto": true, "color": Color(0.85, 0.20, 0.25),
		"name_en": "How Embarrassing", "name_cz": "Jak trapné", "name_es": "Qué Vergüenza", "name_de": "Wie Peinlich", "name_fr": "La Honte",
		"desc_en": "Get killed by a basic monster in Endless.", "desc_cz": "Nech se v Nekonečném režimu zabít základním monstrem.", "desc_es": "Muere a manos de un monstruo básico en Infinito.", "desc_de": "Lass dich im Endlos-Modus von einem Standard-Monster töten.", "desc_fr": "Fais-toi tuer par un monstre basique en mode Infini.",
	},
	{
		"id": "game_unlock5skins", "auto": true, "color": Color(0.75, 0.40, 0.95),
		"name_en": "Fashionista", "name_cz": "Módní ikona", "name_es": "Fashionista", "name_de": "Fashionista", "name_fr": "Fashionista",
		"desc_en": "Unlock 5 skins.", "desc_cz": "Odemkni 5 vzhledů.", "desc_es": "Desbloquea 5 aspectos.", "desc_de": "Schalte 5 Skins frei.", "desc_fr": "Débloque 5 apparences.",
	},
	{
		"id": "endless_5killswith1grenade", "auto": true, "color": Color(0.95, 0.55, 0.15),
		"name_en": "Frag Out", "name_cz": "Granát mezi ně", "name_es": "¡Granada!", "name_de": "Granate Raus", "name_fr": "Grenade !",
		"desc_en": "Kill 5 enemies with a single grenade in Endless.", "desc_cz": "Zabij v Nekonečném režimu 5 nepřátel jedním granátem.", "desc_es": "Elimina 5 enemigos con una sola granada en Infinito.", "desc_de": "Töte im Endlos-Modus 5 Gegner mit einer Granate.", "desc_fr": "Tue 5 ennemis avec une seule grenade en mode Infini.",
	},
	{
		"id": "endless_10killswith1grenade", "auto": true, "color": Color(0.95, 0.35, 0.15),
		"name_en": "Boom Headshot", "name_cz": "Bum!", "name_es": "¡Bum!", "name_de": "Bumm!", "name_fr": "Boum !",
		"desc_en": "Kill 10 enemies with a single grenade in Endless.", "desc_cz": "Zabij v Nekonečném režimu 10 nepřátel jedním granátem.", "desc_es": "Elimina 10 enemigos con una sola granada en Infinito.", "desc_de": "Töte im Endlos-Modus 10 Gegner mit einer Granate.", "desc_fr": "Tue 10 ennemis avec une seule grenade en mode Infini.",
	},
	{
		"id": "game_kill10enemieswithonekatanaswing", "auto": true, "color": Color(0.40, 0.85, 0.95),
		"name_en": "Slice 'n' Dice", "name_cz": "Na nudličky", "name_es": "Corta y Pica", "name_de": "Kleinschnetzeln", "name_fr": "Tranche-Menu",
		"desc_en": "Kill 10 enemies with one katana swing.", "desc_cz": "Zabij 10 nepřátel jedním máchnutím katany.", "desc_es": "Elimina 10 enemigos con un golpe de katana.", "desc_de": "Töte 10 Gegner mit einem Katana-Schwung.", "desc_fr": "Tue 10 ennemis d'un coup de katana.",
	},
	{
		"id": "endless_3chargedbrutes", "auto": true, "color": Color(0.95, 0.50, 0.15),
		"name_en": "Matador", "name_cz": "Matador", "name_es": "Matador", "name_de": "Matador", "name_fr": "Matador",
		"desc_en": "Face 3 enraged Brutes at the same moment in Endless.", "desc_cz": "V jeden moment měj proti sobě 3 rozzuřené Hromotluky v Nekonečném režimu.", "desc_es": "Enfréntate a 3 Brutos enfurecidos a la vez en Infinito.", "desc_de": "Stelle dich im Endlos-Modus 3 wütenden Brocken gleichzeitig.", "desc_fr": "Affronte 3 Brutes enragées au même moment en mode Infini.",
	},
	{
		"id": "endless_kill15monsterswithownbody_onelife", "auto": true, "color": Color(0.90, 0.75, 0.20),
		"name_en": "Bumper Cars", "name_cz": "Autodrom", "name_es": "Autos de Choque", "name_de": "Autoscooter", "name_fr": "Autos Tamponneuses",
		"desc_en": "Kill 15 monsters with your own body in one life in Endless.", "desc_cz": "Zabij v Nekonečném režimu 15 monster vlastním tělem během jednoho života.", "desc_es": "Elimina 15 monstruos con tu cuerpo en una vida en Infinito.", "desc_de": "Töte im Endlos-Modus 15 Monster mit deinem Körper in einem Leben.", "desc_fr": "Tue 15 monstres avec ton corps en une vie en mode Infini.",
	},
	{
		"id": "endless_spawnerkilledbeforespawningbasics", "auto": true, "color": Color(0.85, 0.85, 0.90),
		"name_en": "Nip It in the Bud", "name_cz": "Utni to v zárodku", "name_es": "Cortar de Raíz", "name_de": "Im Keim Ersticken", "name_fr": "Tuer dans l'Œuf",
		"desc_en": "Kill a Spawner in Endless before it spawns any grunts.", "desc_cz": "Zabij v Nekonečném režimu Plodiče dřív, než vyplodí nějaké pěšáky.", "desc_es": "Mata en Infinito a un Generador antes de que genere esbirros.", "desc_de": "Töte im Endlos-Modus einen Erzeuger, bevor er Schergen erzeugt.", "desc_fr": "Tue en mode Infini un Pondeur avant qu'il ne ponde des sbires.",
	},
	{
		"id": "endless_1minuteintimeboostzone_onelife", "auto": true, "color": Color(0.30, 0.90, 0.70),
		"name_en": "Time Lord", "name_cz": "Pán času", "name_es": "Señor del Tiempo", "name_de": "Zeitherr", "name_fr": "Maître du Temps",
		"desc_en": "Spend 1 minute inside timeboost zones in one Endless life.", "desc_cz": "Strav v Nekonečném režimu 1 minutu v časových zónách během jednoho života.", "desc_es": "Pasa 1 minuto en zonas de tiempo en una vida de Infinito.", "desc_de": "Verbringe im Endlos-Modus 1 Minute in Zeitzonen in einem Leben.", "desc_fr": "Passe 1 minute dans les zones temporelles en une vie en mode Infini.",
	},
	{
		"id": "endless_survive5minwithouttakingdamage", "auto": true, "color": Color(0.35, 0.85, 0.55),
		"name_en": "Untouchable", "name_cz": "Nedotknutelný", "name_es": "Intocable", "name_de": "Unberührbar", "name_fr": "Intouchable",
		"desc_en": "Survive 5 minutes in Endless without taking any damage.", "desc_cz": "Přežij 5 minut v Nekonečném režimu bez jediného zásahu.", "desc_es": "Sobrevive 5 minutos en Infinito sin recibir daño.", "desc_de": "Überlebe 5 Minuten im Endlos-Modus, ohne Schaden zu nehmen.", "desc_fr": "Survis 5 minutes en mode Infini sans subir de dégâts.",
	},
	{
		"id": "game_die100times", "auto": true, "color": Color(0.70, 0.70, 0.75),
		"name_en": "Try, Try Again", "name_cz": "Zkoušej dál", "name_es": "Inténtalo Otra Vez", "name_de": "Immer Wieder", "name_fr": "Réessaye Encore",
		"desc_en": "Die 100 times in total.", "desc_cz": "Zemři celkem 100×.", "desc_es": "Muere 100 veces en total.", "desc_de": "Stirb insgesamt 100-mal.", "desc_fr": "Meurs 100 fois au total.",
	},
	{
		"id": "game_explode3bombtankswithkillingone", "auto": true, "color": Color(0.95, 0.45, 0.10),
		"name_en": "Chain Reaction", "name_cz": "Řetězová reakce", "name_es": "Reacción en Cadena", "name_de": "Kettenreaktion", "name_fr": "Réaction en Chaîne",
		"desc_en": "Kill one bomber tank and chain-explode 2 more in an instant.", "desc_cz": "Zabij jeden bombový tank a nech ve zlomku vteřiny vybuchnout 2 další.", "desc_es": "Mata un tanque bomba y haz explotar 2 más al instante.", "desc_de": "Töte einen Bombenpanzer und lass im Nu 2 weitere mitexplodieren.", "desc_fr": "Tue un tank-bombe et fais exploser 2 autres dans l'instant.",
	},
	{
		"id": "game_killchargingbrutewithlaser", "auto": true, "color": Color(0.40, 0.85, 0.95),
		"name_en": "Counter-Charge", "name_cz": "Protiútok", "name_es": "Contracarga", "name_de": "Gegenangriff", "name_fr": "Contre-Charge",
		"desc_en": "Laser a charging Brute to death.", "desc_cz": "Zabij útočícího Hromotluka laserem.", "desc_es": "Mata con láser a un Bruto que carga.", "desc_de": "Erschieße einen stürmenden Brocken mit dem Laser.", "desc_fr": "Tue au laser une Brute en pleine charge.",
	},
	{
		"id": "game_playfor24hours", "auto": true, "color": Color(0.75, 0.45, 0.95),
		"name_en": "Touch Grass", "name_cz": "Běž na vzduch", "name_es": "Toca el Pasto", "name_de": "Geh an die Luft", "name_fr": "Va Prendre l'Air",
		"desc_en": "Play for 5 hours total — unlocks the Deprived skin.", "desc_cz": "Odehraj celkem 5 hodin — odemkne skin Vyčerpaný.", "desc_es": "Juega 5 horas en total — desbloquea el aspecto Privado.", "desc_de": "Spiele insgesamt 5 Stunden — schaltet den Skin Entzogen frei.", "desc_fr": "Joue 5 heures au total — débloque l'apparence Privé.",
	},
	{
		"id": "game_unlockallskins", "auto": true, "color": Color(0.85, 0.55, 0.95),
		"name_en": "Full Wardrobe", "name_cz": "Plný šatník", "name_es": "Armario Completo", "name_de": "Volle Garderobe", "name_fr": "Garde-robe Complète",
		"desc_en": "Unlock every skin and trail.", "desc_cz": "Odemkni všechny skiny a stopy.", "desc_es": "Desbloquea todos los aspectos y estelas.", "desc_de": "Schalte alle Skins und Spuren frei.", "desc_fr": "Débloque toutes les apparences et traînées.",
	},
	{
		"id": "game_healfrom10andloverto100hp", "auto": true, "color": Color(0.35, 0.90, 0.45),
		"name_en": "Back from the Brink", "name_cz": "Návrat z hrobu", "name_es": "Al Filo de la Muerte", "name_de": "Dem Tod Entkommen", "name_fr": "Retour de Loin",
		"desc_en": "In Endless, survive below 10 HP and heal back up to 100 HP.", "desc_cz": "Přežij v Nekonečném režimu s méně než 10 HP a doleč se zpět na 100 HP.", "desc_es": "En Infinito, sobrevive con menos de 10 PS y cúrate hasta 100 PS.", "desc_de": "Überlebe im Endlos-Modus mit unter 10 LP und heile dich auf 100 LP.", "desc_fr": "En mode Infini, survis sous 10 PV et soigne-toi jusqu'à 100 PV.",
	},
	{
		"id": "game_complete5challenges", "auto": true, "color": Color(0.35, 0.55, 0.95),
		"name_en": "Challenger", "name_cz": "Vyzyvatel", "name_es": "Retador", "name_de": "Herausforderer", "name_fr": "Challenger",
		"desc_en": "Complete 5 challenges.", "desc_cz": "Splň 5 výzev.", "desc_es": "Completa 5 desafíos.", "desc_de": "Schließe 5 Prüfungen ab.", "desc_fr": "Termine 5 défis.",
	},
	{
		"id": "game_completeallchallenges", "auto": true, "color": Color(0.55, 0.45, 0.95),
		"name_en": "Challenge Master", "name_cz": "Pán výzev", "name_es": "Maestro de Desafíos", "name_de": "Meister der Prüfungen", "name_fr": "Maître des Défis",
		"desc_en": "Complete every challenge.", "desc_cz": "Splň všechny výzvy.", "desc_es": "Completa todos los desafíos.", "desc_de": "Schließe alle Prüfungen ab.", "desc_fr": "Termine tous les défis.",
	},
	{
		"id": "game_completeallchallengesON3STARS", "auto": true, "color": Color(1.0, 0.75, 0.15),
		"name_en": "Still Got Something to Prove?", "name_cz": "Stále si chceš něco dokázat?", "name_es": "¿Aún Quieres Demostrar Algo?", "name_de": "Willst Du Dir Noch Etwas Beweisen?", "name_fr": "Encore Quelque Chose à Prouver ?",
		"desc_en": "Complete every challenge with 3 stars.", "desc_cz": "Dohraj všechny výzvy na 3 hvězdy.", "desc_es": "Completa todos los desafíos con 3 estrellas.", "desc_de": "Schließe alle Prüfungen mit 3 Sternen ab.", "desc_fr": "Termine tous les défis avec 3 étoiles.",
	},
	{
		"id": "game_grenadeapocalypse", "auto": true, "hidden": true, "color": Color(0.95, 0.25, 0.45),
		"name_en": "Grenade Apocalypse", "name_cz": "Granátová apokalypsa", "name_es": "Apocalipsis de Granadas", "name_de": "Granaten-Apokalypse", "name_fr": "Apocalypse de Grenades",
		"desc_en": "Throw a grenade while Octoshoot and FMJ are active.", "desc_cz": "Vyhoď granát s aktivními powerupy Octoshoot a FMJ.", "desc_es": "Lanza una granada con Octoshoot y FMJ activos.", "desc_de": "Wirf eine Granate, während Octoshoot und FMJ aktiv sind.", "desc_fr": "Lance une grenade avec Octoshoot et FMJ actifs.",
	},
	{
		"id": "levels_completeall", "auto": true, "color": Color(0.35, 0.80, 0.42),
		"name_en": "End of Mutation, For Now...", "name_cz": "Konec mutace, prozatím...", "name_es": "Fin de la Mutación, Por Ahora...", "name_de": "Ende der Mutation, vorerst...", "name_fr": "Fin de la Mutation, Pour l'instant...",
		"desc_en": "Complete every level in Levels mode.", "desc_cz": "Dokonči všechny levely v režimu Levely.", "desc_es": "Completa todos los niveles en el modo Niveles.", "desc_de": "Schließe jedes Level im Level-Modus ab.", "desc_fr": "Termine tous les niveaux en mode Niveaux.",
	},
	{
		"id": "levels_completeallon3stars", "auto": true, "color": Color(1.0, 0.80, 0.20),
		"name_en": "In a Hurry", "name_cz": "Ve spěchu", "name_es": "Con Prisa", "name_de": "In Eile", "name_fr": "En Vitesse",
		"desc_en": "Get 3 stars on every level.", "desc_cz": "Získej 3 hvězdy na každém levelu.", "desc_es": "Consigue 3 estrellas en cada nivel.", "desc_de": "Hol dir 3 Sterne in jedem Level.", "desc_fr": "Obtiens 3 étoiles à chaque niveau.",
	},
	{
		"id": "levels_inrowwithnodeath", "auto": true, "color": Color(0.88, 0.88, 0.92),
		"name_en": "Absolute Master", "name_cz": "Absolutní master", "name_es": "Maestro Absoluto", "name_de": "Absoluter Meister", "name_fr": "Maître Absolu",
		"desc_en": "Beat every level in a row from level 1 without a single death — and earn the exclusive Skeleton skin.", "desc_cz": "Projdi všechny levely v řadě od levelu 1 bez jediné smrti — a získej exkluzivní skin Kostlivec.", "desc_es": "Supera todos los niveles seguidos desde el nivel 1 sin morir — y consigue el aspecto exclusivo Esqueleto.", "desc_de": "Schaffe alle Level am Stück ab Level 1 ohne einen einzigen Tod — und erhalte den exklusiven Skelett-Skin.", "desc_fr": "Termine tous les niveaux d'affilée depuis le niveau 1 sans une seule mort — et obtiens l'apparence exclusive Squelette.",
	},
	{
		"id": "game_unlockallachievements", "auto": true, "color": Color(1.0, 0.82, 0.20),
		"name_en": "100% Complete", "name_cz": "Hotovo na 100 %", "name_es": "100% Completado", "name_de": "100% Abgeschlossen", "name_fr": "100% Terminé",
		"desc_en": "Unlock every other achievement — and earn the exclusive 100% skin.", "desc_cz": "Odemkni všechny ostatní úspěchy — a získej exkluzivní skin 100%.", "desc_es": "Desbloquea todos los demás logros — y consigue el aspecto exclusivo 100%.", "desc_de": "Schalte alle anderen Erfolge frei — und erhalte den exklusiven 100%-Skin.", "desc_fr": "Débloque tous les autres succès — et obtiens l'apparence exclusive 100%.",
	},
]

static func get_info(id: String) -> Dictionary:
	for a: Dictionary in ACHIEVEMENTS:
		if a.get("id", "") == id:
			return a
	return {}

static func get_icon_path(id: String) -> String:
	return ICON_DIR + id + ".svg"

static func display_name(id: String) -> String:
	var a := get_info(id)
	return _localized(a, "name") if not a.is_empty() else id

static func get_desc(id: String) -> String:
	var a := get_info(id)
	return _localized(a, "desc") if not a.is_empty() else ""

static func get_color(id: String) -> Color:
	var a := get_info(id)
	return a.get("color", Color(1.0, 0.8, 0.2)) if not a.is_empty() else Color(1.0, 0.8, 0.2)

## True if this achievement is hidden (shows the mystery icon + "???" until unlocked).
static func is_hidden(id: String) -> bool:
	return bool(get_info(id).get("hidden", false))

## True if this achievement has a cumulative progress bar.
static func has_progress(id: String) -> bool:
	return PROGRESS.has(id)

## Current progress for a cumulative achievement, computed live from SaveManager.
## Returns {current, target, ratio (0..1), text "X / Y"} — or {} if it has no bar.
static func get_progress(id: String) -> Dictionary:
	if not PROGRESS.has(id):
		return {}
	var kind: String = PROGRESS[id]
	var cur := 0.0
	var tgt := 1.0
	var text := ""
	match kind:
		"time24":
			cur = SaveManager.get_stat("total_play_time")
			tgt = 18000.0
			text = "%d / 5 h" % int(cur / 3600.0)
		"deaths100":
			cur = SaveManager.get_stat("total_deaths")
			tgt = 100.0
			text = "%d / 100" % int(cur)
		"skins5":
			cur = float(SaveManager.get_owned_skins().size())
			tgt = 5.0
			text = "%d / 5" % int(cur)
		"collection":
			var owned := 0
			var total := 0
			for sid in SpriteLoader.get_available_skins():
				if String(sid) == "Player_100":
					continue  # the 100% reward isn't part of the collection goal
				total += 1
				if SaveManager.is_skin_owned(String(sid)):
					owned += 1
			for t: Dictionary in TrailMeta.TRAILS:
				var tid := String(t.get("id", ""))
				if tid == "" or tid == "none":
					continue
				total += 1
				if SaveManager.is_trail_owned(tid):
					owned += 1
			cur = float(owned)
			tgt = float(maxi(total, 1))
			text = "%d / %d" % [owned, total]
		"allach":
			var u := 0
			var tot := 0
			for a: Dictionary in ACHIEVEMENTS:
				var aid := String(a.get("id", ""))
				# 100 % ignores the meta one itself AND the cosmetic/playtime ones that don't
				# count — so the bar reads e.g. X/27, not X/30.
				if aid == "game_unlockallachievements" or aid in NON_COMPLETION_IDS:
					continue
				tot += 1
				if SaveManager.is_achievement_unlocked(aid):
					u += 1
			cur = float(u)
			tgt = float(maxi(tot, 1))
			text = "%d / %d" % [u, tot]
		"chal5":
			cur = float(SaveManager.data.get("progress", {}).get("challenges_completed", []).size())
			tgt = 5.0
			text = "%d / 5" % int(cur)
		"chalall":
			var done: Array = SaveManager.data.get("progress", {}).get("challenges_completed", [])
			var total_ch: int = ChallengeReg.CHALLENGES.size()
			var done_n := 0
			for ch: Dictionary in ChallengeReg.CHALLENGES:
				if String(ch.get("id", "")) in done:
					done_n += 1
			cur = float(done_n)
			tgt = float(maxi(total_ch, 1))
			text = "%d / %d" % [done_n, total_ch]
		"chal3stars":
			var total3: int = ChallengeReg.CHALLENGES.size()
			var full := 0
			for ch: Dictionary in ChallengeReg.CHALLENGES:
				if SaveManager.get_challenge_stars(String(ch.get("id", ""))) >= 3:
					full += 1
			cur = float(full)
			tgt = float(maxi(total3, 1))
			text = "%d / %d" % [full, total3]
	var ratio := clampf(cur / tgt, 0.0, 1.0) if tgt > 0.0 else 0.0
	return {"current": cur, "target": tgt, "ratio": ratio, "text": text}

## Pick the "<prefix>_<lang>" field, falling back to English.
static func _localized(a: Dictionary, prefix: String) -> String:
	var lang := Loc.current_lang()
	return String(a.get(prefix + "_" + lang, a.get(prefix + "_en", "")))
