# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.
#
# Questo programma è distribuito nella speranza che sia utile, ma SENZA ALCUNA
# GARANZIA; senza neppure la garanzia implicita di COMMERCIABILITÀ o IDONEITÀ
# PER UNO SCOPO PARTICOLARE. Vedi la GNU General Public License per i dettagli.
#
# Dovresti aver ricevuto una copia della GNU General Public License insieme a
# questo programma. In caso contrario, vedi <https://www.gnu.org/licenses/>.

extends Node
## Unica fonte di verità per crediti, statistiche e mondo. Persiste in JSON.
##
## Il file sta in user:// (su Windows in %APPDATA%\Godot\app_userdata\FOCUS!).
## Il mondo non viene salvato per intero: si tiene il seed per rigenerare il
## terreno e solo le celle costruite. Vector2i non esiste in JSON, quindi le
## coordinate viaggiano come array [x, y].

signal credits_changed(credits: int)
signal stats_changed()
signal game_loaded()

const SAVE_PATH := "user://focus_save.json"
const SAVE_VERSION := 1
const DEFAULT_WORLD_SIZE := 32

var data: Dictionary = {}

var credits: int:
	get:
		return int(data.get("credits", 0))

var total_focus_seconds: int:
	get:
		return int(data.get("total_focus_seconds", 0))

var sessions_completed: int:
	get:
		return int(data.get("sessions_completed", 0))


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## Salvataggio vuoto, usato al primo avvio e come base su cui innestare il file.
static func new_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"credits": 0,
		"credit_remainder": 0.0,
		"total_focus_seconds": 0,
		"sessions_completed": 0,
		"world": {
			"seed": randi(),
			"size": [DEFAULT_WORLD_SIZE, DEFAULT_WORLD_SIZE],
			"tiles": [],
			"terrain_edits": [],
		},
	}


func load_game() -> void:
	data = new_save()
	if FileAccess.file_exists(SAVE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			# Innesto sui default: un salvataggio vecchio a cui manca una chiave
			# nuova continua a caricarsi invece di rompersi.
			for key in (parsed as Dictionary):
				data[key] = (parsed as Dictionary)[key]
		else:
			push_error("SaveManager: salvataggio illeggibile, riparto da zero.")
	game_loaded.emit()
	credits_changed.emit(credits)
	stats_changed.emit()


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: impossibile scrivere %s (%s)" % [
			SAVE_PATH, error_string(FileAccess.get_open_error())
		])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func add_credits(amount: int) -> void:
	if amount == 0:
		return
	data["credits"] = maxi(0, credits + amount)
	credits_changed.emit(credits)


func can_afford(cost: int) -> bool:
	return credits >= cost


## Scala il costo solo se il saldo basta. Restituisce true se l'acquisto è andato.
func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	add_credits(-cost)
	save_game()
	return true


## Registra una sessione di focus e restituisce i crediti accreditati.
##
## I decimali non si buttano via: il resto sotto l'unità resta da parte e si
## somma alla sessione successiva, così venti sessioni da tre minuti valgono
## quanto un'ora piena.
func register_focus_session(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	var earned := Config.credits_for_seconds(seconds) + float(data.get("credit_remainder", 0.0))
	var whole := int(floor(earned))
	data["credit_remainder"] = earned - float(whole)
	data["total_focus_seconds"] = total_focus_seconds + int(round(seconds))
	data["sessions_completed"] = sessions_completed + 1
	if whole > 0:
		add_credits(whole)
	stats_changed.emit()
	save_game()
	return whole


# --- Il mondo ---------------------------------------------------------------

func world_seed() -> int:
	var world: Dictionary = data.get("world", {})
	return int(world.get("seed", 0))


func world_size() -> Vector2i:
	var world: Dictionary = data.get("world", {})
	var size: Array = world.get("size", [DEFAULT_WORLD_SIZE, DEFAULT_WORLD_SIZE])
	return Vector2i(int(size[0]), int(size[1]))


## Le celle costruite, così come stanno su disco: pos come array [x, z], tipo,
## rotazione a scatti di 90° e quota del lotto in livelli interi.
##
## La quota si salva anche se il terreno si rigenera dal seme, perché piazzare
## spiana: senza il livello scelto allora, ricaricando la stessa città il suolo
## sotto gli edifici tornerebbe quello di prima.
func world_tiles() -> Array:
	var world: Dictionary = data.get("world", {})
	if not world.has("tiles"):
		world["tiles"] = []
	return world["tiles"]


func add_tile(cell: Vector2i, type: String, rotation: int, level: int) -> void:
	world_tiles().append({
		"pos": [cell.x, cell.y],
		"type": type,
		"rotation": rotation,
		"level": level,
	})
	save_game()


## Le quote che sono state spianate, come stanno su disco: pos come array
## [x, z] e la quota in livelli interi.
##
## Sono separate dalle celle costruite perché sopravvivono alla demolizione: un
## lotto spianato è una modifica al mondo, non un pezzo dell'edificio che l'ha
## chiesta. Chi ricarica applica prima queste e poi ci rimette sopra le case.
func world_terrain_edits() -> Array:
	var world: Dictionary = data.get("world", {})
	if not world.has("terrain_edits"):
		world["terrain_edits"] = []
	return world["terrain_edits"]


## Segna una cella spianata. Se c'era già, ne aggiorna la quota invece di
## aggiungere una riga: di una cella conta solo com'è adesso.
func set_terrain_edit(cell: Vector2i, level: int) -> void:
	var edits := world_terrain_edits()
	for edit in edits:
		var pos: Array = edit.get("pos", [])
		if pos.size() == 2 and int(pos[0]) == cell.x and int(pos[1]) == cell.y:
			edit["level"] = level
			return
	edits.append({ "pos": [cell.x, cell.y], "level": level })


## Dimentica la quota di una cella: si usa quando torna a quella del seme, che
## si rigenera da sola e non ha bisogno di stare su disco.
func clear_terrain_edit(cell: Vector2i) -> void:
	var edits := world_terrain_edits()
	for i in edits.size():
		var pos: Array = edits[i].get("pos", [])
		if pos.size() == 2 and int(pos[0]) == cell.x and int(pos[1]) == cell.y:
			edits.remove_at(i)
			return


## Toglie la cella ancorata in "cell". Restituisce true se c'era davvero.
func remove_tile(cell: Vector2i) -> bool:
	var tiles := world_tiles()
	for i in tiles.size():
		var pos: Array = tiles[i].get("pos", [])
		if pos.size() == 2 and int(pos[0]) == cell.x and int(pos[1]) == cell.y:
			tiles.remove_at(i)
			save_game()
			return true
	return false
