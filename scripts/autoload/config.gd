extends Node
## Valori dell'economia in un unico posto.
##
## I numeri vivono in res://data/economy.json così si ritoccano senza toccare il
## codice. Se il file manca o è rotto si usano i DEFAULTS e si segnala l'errore.

const CONFIG_PATH := "res://data/economy.json"

## Rete di sicurezza: usati solo se economy.json non è leggibile.
const DEFAULTS := {
	"credits_per_hour": 10.0,
	"credits_on_early_stop": true,
	"min_session_seconds": 60,
	"prices": {
		"NAT_TREE": 2,
		"ROAD": 3,
		"RES_LOW": 8,
		"RES_MID": 25,
	},
}

## Crediti guadagnati per un'ora piena di focus.
var credits_per_hour: float = float(DEFAULTS["credits_per_hour"])

## Se true una sessione interrotta a mano accredita comunque il tempo svolto.
var credits_on_early_stop: bool = bool(DEFAULTS["credits_on_early_stop"])

## Sotto questa soglia un'interruzione manuale non accredita nulla.
var min_session_seconds: int = int(DEFAULTS["min_session_seconds"])

## Prezzi provvisori per prefisso di categoria. La Fase 4 li collegherà ai
## singoli ID di assets/models/generated/catalog.json.
var prices: Dictionary = (DEFAULTS["prices"] as Dictionary).duplicate()


func _ready() -> void:
	reload()


func reload() -> void:
	var values: Dictionary = DEFAULTS.duplicate(true)
	var from_disk := _read_json()
	for key in from_disk:
		values[key] = from_disk[key]
	credits_per_hour = float(values["credits_per_hour"])
	credits_on_early_stop = bool(values["credits_on_early_stop"])
	min_session_seconds = int(values["min_session_seconds"])
	prices = values["prices"]


## Crediti (con decimali) maturati da un tempo di focus espresso in secondi.
func credits_for_seconds(seconds: float) -> float:
	return seconds / 3600.0 * credits_per_hour


func _read_json() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Config: %s non trovato, uso i valori di default." % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config: %s non è un oggetto JSON valido, uso i default." % CONFIG_PATH)
		return {}
	return parsed
