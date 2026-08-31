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
	"terrain_cost_per_level": 1,
	"prices": {
		"tree": 2,
		"road": 3,
		"house": 8,
		"apartment": 25,
	},
	"services": {
		"base": { "power": 12, "water": 12 },
		"plants": { "wind": { "power": 72 }, "water": { "water": 72 } },
		"per_cell": { "house": { "power": 1, "water": 1 } },
	},
	"population": {
		"per_cell": { "house": 3 },
	},
	"jobs": {
		"per_cell": { "shop": 4, "office": 8 },
	},
	"zone_price": 120,
	"zone_price_growth": 1.6,
	"happiness": {
		"abandon_below": 0.5,
		"radius": {
			"polizia": 9, "pompieri": 9, "ospedale": 9,
			"verde": 6, "sport": 8, "elementare": 7, "superiore": 10,
		},
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

## Quanto costa alzare o abbassare una cella di un gradino. Non si rimborsa:
## rimettere il terreno com'era è un lavoro come scavarlo.
var terrain_cost_per_level: int = int(DEFAULTS["terrain_cost_per_level"])

## Quanto costa la prima zona in più, e di quanto rincara ogni volta.
var zone_price: int = int(DEFAULTS["zone_price"])
var zone_price_growth: float = float(DEFAULTS["zone_price_growth"])


## Corrente e acqua: l'allacciamento di partenza, quanto dà ogni impianto e
## quanto prende a cella ogni tipo di edificio. La forma la descrive
## economy.json, che è anche il posto dove si ritocca.
var services: Dictionary = (DEFAULTS["services"] as Dictionary).duplicate(true)

## Quanti abitanti porta, a cella occupata, ogni tipo di edificio residenziale.
var population: Dictionary = (DEFAULTS["population"] as Dictionary).duplicate(true)

## Quanti posti di lavoro offre, a cella occupata, ogni tipo di edificio.
var jobs: Dictionary = (DEFAULTS["jobs"] as Dictionary).duplicate(true)

## I raggi dei servizi di zona e la soglia sotto la quale un'abitazione viene
## abbandonata.
var happiness: Dictionary = (DEFAULTS["happiness"] as Dictionary).duplicate(true)


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
	terrain_cost_per_level = maxi(0, int(values["terrain_cost_per_level"]))
	zone_price = maxi(0, int(values["zone_price"]))
	zone_price_growth = maxf(1.0, float(values["zone_price_growth"]))
	prices = values["prices"]
	services = values["services"]
	population = values["population"]
	jobs = values["jobs"]
	happiness = values["happiness"]


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


## Corrente e acqua stanno sempre insieme, quindi viaggiano in un Vector2i:
## x è la corrente, y è l'acqua. Sommare due bilanci diventa un'addizione sola.
static func _coppia(dati: Dictionary) -> Vector2i:
	return Vector2i(int(dati.get("power", 0)), int(dati.get("water", 0)))


## L'allacciamento che la città ha già addosso, senza aver costruito niente.
## Senza, la prima casa costerebbe anche una centrale, e la prima sessione da
## venticinque minuti non basterebbe più a posare niente.
func service_base() -> Vector2i:
	return _coppia(services.get("base", {}))


## Quanto mette in comune un impianto. Zero per tutto quello che non lo è: gli
## impianti sono i soli a dare, e sono riconosciuti dalla variante del modello.
func plant_output(kind: String, variant: String) -> Vector2i:
	if kind != "utility":
		return Vector2i.ZERO
	var impianti: Dictionary = services.get("plants", {})
	return _coppia(impianti.get(variant, {}))


## Quanto prende, a cella occupata, un tipo di edificio. Zero per quello che non
## è un edificio: strade, ponti, alberi e parchi non si allacciano a niente.
func consumption_per_cell(kind: String) -> Vector2i:
	var consumi: Dictionary = services.get("per_cell", {})
	return _coppia(consumi.get(kind, {}))


## Quanti abitanti porta, a cella occupata, un tipo di edificio. Zero per tutto
## quello in cui non ci abita nessuno — che è tutto tranne le cinque tipologie
## residenziali.
func residents_per_cell(kind: String) -> int:
	var densita: Dictionary = population.get("per_cell", {})
	return int(densita.get(kind, 0))


## Quanti posti di lavoro offre, a cella occupata, un tipo di edificio. Zero per
## tutto quello in cui non lavora nessuno: case, strade, alberi, parchi.
func jobs_per_cell(kind: String) -> int:
	var posti: Dictionary = jobs.get("per_cell", {})
	return int(posti.get(kind, 0))


## Il raggio base di un servizio di zona, in celle. Chi lo usa ci somma il lato
## più lungo dell'edificio meno uno: un ospedale 3x3 arriva più lontano di una
## clinica 2x2, e non serve un numero per modello per dirlo.
## Quanto costa la prossima zona, sapendo quante se ne hanno già.
##
## Cresce con quelle possedute: allargarsi deve restare una scelta, non
## l'automatismo che si fa perché tanto costa poco. La prima in più è la
## seconda del mondo, quindi l'esponente parte da quante ce n'erano meno una.
func zone_cost(gia_possedute: int) -> int:
	return int(round(float(zone_price) * pow(zone_price_growth, maxi(0, gia_possedute - 1))))


func service_radius(zona: String) -> float:
	var raggi: Dictionary = happiness.get("radius", {})
	return float(raggi.get(zona, 0.0))


## Sotto questa quota di servizi di zona un'abitazione viene abbandonata.
func abandon_below() -> float:
	return clampf(float(happiness.get("abandon_below", 0.5)), 0.0, 1.0)


func _read_json() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Config: %s non trovato, uso i valori di default." % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config: %s non è un oggetto JSON valido, uso i default." % CONFIG_PATH)
		return {}
	return parsed
