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
