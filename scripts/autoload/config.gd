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
	"price_default": 10,
	"refund_ratio": 0.5,
	"prices": {
		"tree": 2,
		"road": 3,
		"house": 8,
		"apartment": 25,
	},
}

## Crediti guadagnati per un'ora piena di focus.
var credits_per_hour: float = float(DEFAULTS["credits_per_hour"])

## Se true una sessione interrotta a mano accredita comunque il tempo svolto.
var credits_on_early_stop: bool = bool(DEFAULTS["credits_on_early_stop"])

## Sotto questa soglia un'interruzione manuale non accredita nulla.
var min_session_seconds: int = int(DEFAULTS["min_session_seconds"])

## Prezzo di ogni tipo di oggetto: la chiave è il "kind" del catalogo asset.
## Un tipo assente da qui costa price_default.
var prices: Dictionary = (DEFAULTS["prices"] as Dictionary).duplicate()

## Quanto costa un tipo che non compare in prices.
var price_default: int = int(DEFAULTS["price_default"])

## Quanta parte del prezzo torna indietro demolendo. 0.5 = metà.
var refund_ratio: float = float(DEFAULTS["refund_ratio"])


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
	price_default = int(values["price_default"])
	refund_ratio = clampf(float(values["refund_ratio"]), 0.0, 1.0)
	prices = values["prices"]


## Crediti (con decimali) maturati da un tempo di focus espresso in secondi.
func credits_for_seconds(seconds: float) -> float:
	return seconds / 3600.0 * credits_per_hour


## Quanto costa un oggetto, dato il suo tipo nel catalogo asset.
func price_for_kind(kind: String) -> int:
	return int(prices.get(kind, price_default))


## Quanto rende demolire qualcosa che era costato "price". Si arrotonda per
## difetto: costruire e demolire non deve mai far guadagnare crediti.
func refund_for_price(price: int) -> int:
	return int(floor(float(price) * refund_ratio))


func _read_json() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Config: %s non trovato, uso i valori di default." % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config: %s non è un oggetto JSON valido, uso i default." % CONFIG_PATH)
		return {}
	return parsed
