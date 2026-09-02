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
signal settings_changed()

const SAVE_PATH := "user://focus_save.json"
const SAVE_VERSION := 1
## Il mondo è una scacchiera di zone quadrate: se ne possiede una all'inizio e
## si comprano le altre. La misura di una zona è la vecchia misura del mondo —
## una città intera ci stava dentro — e adesso è il pezzo che si compra.
const LATO_ZONA := 32
## Quante zone per lato ha il mondo intero.
const ZONE_PER_LATO := 3
const DEFAULT_WORLD_SIZE := LATO_ZONA * ZONE_PER_LATO

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

var credits_earned_total: int:
	get:
		return int(data.get("credits_earned_total", 0))


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
		"credits_earned_total": 0,
		# Un giorno per chiave, "AAAA-MM-GG" -> { seconds, sessions }. Lo streak non
		# si salva: si ricalcola da qui, cosi non puo' scollarsi dai giorni veri.
		"daily": {},
		"settings": {
			"volume": 0.8,
			"muted": false,
		},
		"world": {
			"seed": randi(),
			"size": [DEFAULT_WORLD_SIZE, DEFAULT_WORLD_SIZE],
			"zones": [[ZONE_PER_LATO / 2, ZONE_PER_LATO / 2]],
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
	_segna_il_giorno(int(round(seconds)), whole)
	if whole > 0:
		add_credits(whole)
	stats_changed.emit()
	save_game()
	return whole


# --- Statistiche e streak ---------------------------------------------------
#
# Del registro si salvano solo i giorni: lo streak no, si ricalcola. E' la
# stessa scelta che il mondo fa con l'acqua — quello che si puo' ridedurre non
# si scrive, cosi non puo' scollarsi da cio' che descrive.

## Oggi come chiave del registro, secondo l'orologio locale.
##
## Locale e non UTC di proposito: un'ora di studio finita a mezzanotte e mezza
## appartiene alla giornata in cui l'hai vissuta.
static func chiave_di_oggi() -> String:
	var adesso := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [adesso["year"], adesso["month"], adesso["day"]]


## Il giorno prima di una chiave. Il conto si fa a mezzogiorno e in UTC, cosi
## un fuso orario o un'ora legale non possono far saltare o ripetere un giorno.
static func giorno_prima(chiave: String) -> String:
	var istante := int(Time.get_unix_time_from_datetime_string(chiave + "T12:00:00"))
	return Time.get_date_string_from_unix_time(istante - 86400)


func giorni() -> Dictionary:
	if not data.has("daily"):
		data["daily"] = {}
	return data["daily"]


func secondi_del_giorno(chiave: String) -> int:
	var giorno: Dictionary = giorni().get(chiave, {})
	return int(giorno.get("seconds", 0))


func sessioni_del_giorno(chiave: String) -> int:
	var giorno: Dictionary = giorni().get(chiave, {})
	return int(giorno.get("sessions", 0))


## Un giorno conta per lo streak se ci sta dentro almeno il minimo che rende
## una sessione accreditabile: la soglia e' la stessa, non una seconda regola.
func giorno_valido(chiave: String) -> bool:
	return secondi_del_giorno(chiave) >= Config.min_session_seconds


## I giorni che contano, in ordine di calendario.
func giorni_validi() -> Array:
	var chiavi: Array = []
	for chiave in giorni():
		if giorno_valido(str(chiave)):
			chiavi.append(str(chiave))
	chiavi.sort()
	return chiavi


func giorni_attivi() -> int:
	return giorni_validi().size()


## Giorni di fila fino a oggi. Se oggi non hai ancora fatto niente la serie
## regge lo stesso: si riparte da ieri, perche' la giornata non e' finita.
func streak_attuale() -> int:
	var chiave := chiave_di_oggi()
	if not giorno_valido(chiave):
		chiave = giorno_prima(chiave)
		if not giorno_valido(chiave):
			return 0
	var conta := 0
	while giorno_valido(chiave):
		conta += 1
		chiave = giorno_prima(chiave)
	return conta


## La serie piu' lunga mai fatta.
func streak_record() -> int:
	var chiavi := giorni_validi()
	if chiavi.is_empty():
		return 0
	var record := 1
	var corrente := 1
	for i in range(1, chiavi.size()):
		corrente = corrente + 1 if giorno_prima(str(chiavi[i])) == str(chiavi[i - 1]) else 1
		record = maxi(record, corrente)
	return record


## Gli ultimi giorni, dal piu' vecchio a oggi, buchi compresi: il grafico deve
## poter disegnare anche le colonne vuote.
func ultimi_giorni(quanti: int) -> Array:
	var elenco: Array = []
	var chiave := chiave_di_oggi()
	for _i in maxi(0, quanti):
		elenco.append({
			"data": chiave,
			"secondi": secondi_del_giorno(chiave),
			"sessioni": sessioni_del_giorno(chiave),
		})
		chiave = giorno_prima(chiave)
	elenco.reverse()
	return elenco


func _segna_il_giorno(secondi: int, crediti: int) -> void:
	var registro := giorni()
	var chiave := chiave_di_oggi()
	var giorno: Dictionary = registro.get(chiave, { "seconds": 0, "sessions": 0 })
	giorno["seconds"] = int(giorno.get("seconds", 0)) + secondi
	giorno["sessions"] = int(giorno.get("sessions", 0)) + 1
	registro[chiave] = giorno
	data["credits_earned_total"] = credits_earned_total + crediti


# --- Preferenze e partita ---------------------------------------------------

func impostazioni() -> Dictionary:
	if not data.has("settings"):
		data["settings"] = { "volume": 0.8, "muted": false }
	return data["settings"]


func volume() -> float:
	return clampf(float(impostazioni().get("volume", 0.8)), 0.0, 1.0)


func muto() -> bool:
	return bool(impostazioni().get("muted", false))


func imposta_audio(volume_nuovo: float, muto_nuovo: bool) -> void:
	var preferenze := impostazioni()
	preferenze["volume"] = clampf(volume_nuovo, 0.0, 1.0)
	preferenze["muted"] = muto_nuovo
	settings_changed.emit()
	save_game()


## Se c'e' gia' qualcosa da riprendere. Serve al menu per dire "Continua"
## invece di "Comincia", e per chiedere conferma prima di buttare via tutto.
func partita_iniziata() -> bool:
	return total_focus_seconds > 0 or credits > 0 or not world_tiles().is_empty()


## Ricomincia da capo: mondo nuovo, crediti a zero, statistiche azzerate.
##
## Le preferenze sopravvivono: il volume dell'audio e' dell'utente, non della
## partita, e non c'e' motivo di rialzarlo ogni volta che si riparte.
func reset_game() -> void:
	var preferenze: Dictionary = (impostazioni() as Dictionary).duplicate(true)
	data = new_save()
	data["settings"] = preferenze
	save_game()
	game_loaded.emit()
	credits_changed.emit(credits)
	stats_changed.emit()


# --- Il mondo ---------------------------------------------------------------

func world_seed() -> int:
	var world: Dictionary = data.get("world", {})
	return int(world.get("seed", 0))


func world_size() -> Vector2i:
	var world: Dictionary = data.get("world", {})
	var size: Array = world.get("size", [DEFAULT_WORLD_SIZE, DEFAULT_WORLD_SIZE])
	return Vector2i(int(size[0]), int(size[1]))


## Quante zone ha il mondo per lato, dedotte dalla sua misura: una partita
## vecchia, nata quando il mondo era una zona sola, resta una zona sola.
func world_zones_per_side() -> int:
	return maxi(1, world_size().x / LATO_ZONA)


## Le zone che il giocatore possiede, come coordinate di zona.
##
## Una partita salvata prima che le zone esistessero non ne ha nessuna scritta:
## in quel caso sono sue tutte quelle che il suo mondo conteneva, perché ci
## costruiva sopra liberamente e togliergliele adesso sarebbe un dispetto.
func world_zones() -> Array:
	var world: Dictionary = data.get("world", {})
	if not world.has("zones"):
		var tutte: Array = []
		for zx in world_zones_per_side():
			for zy in world_zones_per_side():
				tutte.append([zx, zy])
		return tutte
	return world.get("zones", [])


func owns_zone(zona: Vector2i) -> bool:
	for posseduta in world_zones():
		if int(posseduta[0]) == zona.x and int(posseduta[1]) == zona.y:
			return true
	return false


## Aggiunge una zona a quelle possedute. Restituisce false se era già sua.
func add_zone(zona: Vector2i) -> bool:
	if owns_zone(zona):
		return false
	var world: Dictionary = data.get("world", {})
	var zone: Array = world_zones()
	zone.append([zona.x, zona.y])
	world["zones"] = zone
	data["world"] = world
	return true


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
