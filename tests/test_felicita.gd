# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.

extends Node
## Prove d'integrazione sulla felicità: quanti sono i servizi di zona, quanto
## vale ognuno, e a che punto un'abitazione viene abbandonata.
##
## I conti della felicità sono raccontati in tre posti — le costanti di
## `CityView`, i raggi in `economy.json` e le righe del pannello — e una volta
## sono già scivolati via l'uno dall'altro, quando le scuole hanno portato i
## servizi da cinque a sette. Questa prova li tiene insieme: aggiungere un
## servizio senza dargli un raggio, o senza dargli la sua riga, si vede da qui.
##
## Il salvataggio su disco non viene toccato: la prova sostituisce soltanto i
## dati in memoria e non chiama mai le operazioni di acquisto o salvataggio.

const SCENA_CITTA := preload("res://scenes/city/CityView.tscn")

## Il quartiere di prova: una strada dritta, la casa che ci si affaccia sopra e
## i sette presidi in fila sotto, tutti dentro il raggio della casa. I due
## impianti servono a tenerli allacciati: un presidio senza corrente è chiuso e
## la sua area sparisce, e non è quello che si sta misurando qui.
const QUOTA := 4
const RIGA_STRADA := 10
const CASA := Vector2i(20, 9)
const TORRE := Vector2i(50, 20)
const IMPIANTI := [
	["UTIL_WIND_2x2_001", Vector2i(2, 11)],
	["UTIL_WATER_2x2_001", Vector2i(5, 11)],
]
## In ordine di posa: i primi quattro sono quelli che portano la casa sopra la
## soglia, gli altri tre quelli che la finiscono.
const PRESIDI := [
	["verde", "PARK_1x1_004", Vector2i(20, 11)],
	["polizia", "CIV_POLICE_2x2_001", Vector2i(16, 11)],
	["sport", "SPORT_BASKET_2x1_001", Vector2i(22, 11)],
	["pompieri", "CIV_FIRE_2x2_001", Vector2i(13, 11)],
	["elementare", "EDU_SCHOOL_3x3_001", Vector2i(25, 11)],
	["ospedale", "CIV_HEALTH_3x3_001", Vector2i(9, 11)],
	["superiore", "EDU_SCHOOL_4x3_002", Vector2i(29, 11)],
]

var _citta
var _fallimenti := PackedStringArray()
var _id_casa := -1
var _id_torre := -1


func _ready() -> void:
	SaveManager.data = {
		"credits": 100000,
		"world": {
			"seed": 424242, "zones": [[0, 0], [1, 0]], "tiles": [], "terrain_edits": [],
		},
	}
	_citta = SCENA_CITTA.instantiate()
	add_child(_citta)

	_prova_i_conti_dichiarati()
	_prepara_il_quartiere()
	_prova_chi_porta_cosa()
	_prova_i_sette_gradini()
	_prova_la_media_pesata()
	_prova_la_strada_tolta()
	_prova_il_presidio_demolito()

	if not _fallimenti.is_empty():
		for fallimento in _fallimenti:
			push_error(fallimento)
		get_tree().quit(1)
		return
	print("Felicità: tutte le prove sono passate.")
	get_tree().quit()


func _verifica(condizione: bool, messaggio: String) -> void:
	if not condizione:
		_fallimenti.append(messaggio)


# --- Il quartiere -----------------------------------------------------------

func _rendi_piane(celle: Array[Vector2i], livello: int) -> void:
	for cella in celle:
		_citta.terreno.imposta_livello(cella, livello)
	for cella in celle:
		_citta.terreno.riclassifica_cella(cella)


func _spiana(da: Vector2i, a: Vector2i) -> void:
	var celle: Array[Vector2i] = []
	for x in range(da.x, a.x + 1):
		for y in range(da.y, a.y + 1):
			celle.append(Vector2i(x, y))
	_rendi_piane(celle, QUOTA)


func _posa(id: String, ancora: Vector2i) -> void:
	_verifica(_citta._costruisci(id, ancora, 0, QUOTA, false),
		"Non è stato possibile posare %s in %s." % [id, ancora])


func _id_in(cella: Vector2i) -> int:
	var occupante: Dictionary = _citta.griglia.occupante(cella)
	return -1 if occupante.is_empty() else int(occupante["id"])


## Toglie quello che occupa una cella, come fa la demolizione ma senza crediti
## né salvataggio.
func _demolisci(cella: Vector2i) -> void:
	var occupante: Dictionary = _citta.griglia.occupante(cella)
	if occupante.is_empty():
		_fallimenti.append("In %s non c'è niente da demolire." % cella)
		return
	var costruzione: Dictionary = _citta._costruzioni.get(int(occupante["id"]), {})
	if costruzione.has("nodo"):
		(costruzione["nodo"] as Node3D).queue_free()
	_citta._costruzioni.erase(int(occupante["id"]))
	_citta.griglia.rimuovi(cella)
	_citta._conta_i_servizi(_citta.catalogo.voce(str(occupante["modello"])), -1)


func _prepara_il_quartiere() -> void:
	_spiana(Vector2i(0, RIGA_STRADA - 2), Vector2i(34, RIGA_STRADA + 4))
	_spiana(TORRE, TORRE + Vector2i(3, 3))
	for x in range(0, 35):
		_posa("ROAD_LOCAL_1x1_STRAIGHT", Vector2i(x, RIGA_STRADA))
	for impianto in IMPIANTI:
		_posa(str(impianto[0]), impianto[1])
	_posa("RES_LOW_1x1_001", CASA)
	_posa("RES_TOWER_3x3_001", TORRE)
	_id_casa = _id_in(CASA)
	_id_torre = _id_in(TORRE)
	_verifica(_id_casa >= 0 and _id_torre >= 0, "Le abitazioni di prova non sono in griglia.")
	var disponibili: Vector2i = _citta._servizi_disponibili()
	_verifica(disponibili.x > 0 and disponibili.y > 0,
		"Gli impianti non stanno producendo: %s." % disponibili)


# --- Le prove ---------------------------------------------------------------

## Le tre voci che raccontano la stessa cosa devono dire lo stesso numero.
func _prova_i_conti_dichiarati() -> void:
	var zona: Array = _citta.SERVIZI_ZONA
	_verifica(zona.size() == 7, "I servizi di zona sono %d, non sette." % zona.size())
	for atteso in ["polizia", "pompieri", "ospedale", "verde", "sport",
			"elementare", "superiore"]:
		_verifica(zona.has(atteso), "Manca il servizio di zona %s." % atteso)
	for vitale in _citta.SERVIZI_VITALI:
		_verifica(not zona.has(vitale),
			"%s è insieme un allacciamento e un servizio di zona." % vitale)
	for servizio in zona:
		_verifica(Config.service_radius(str(servizio)) > 0.0,
			"Il servizio di zona %s non ha un raggio in economy.json." % servizio)

	var righe: Array = _citta.SERVIZI
	var attese: Array = _citta.SERVIZI_VITALI + zona
	_verifica(righe.size() == attese.size(),
		"Il pannello ha %d righe e i servizi sono %d." % [righe.size(), attese.size()])
	for i in range(mini(righe.size(), attese.size())):
		_verifica(str(righe[i]["id"]) == str(attese[i]),
			"La riga %d del pannello è %s, non %s." % [i, righe[i]["id"], attese[i]])


func _prova_chi_porta_cosa() -> void:
	for presidio in PRESIDI:
		_verifica(_citta.catalogo.zona(str(presidio[1])) == str(presidio[0]),
			"%s non porta il servizio %s." % [presidio[1], presidio[0]])
	for id in ["RES_LOW_1x1_001", "RES_TOWER_3x3_001", "ROAD_LOCAL_1x1_STRAIGHT",
			"UTIL_WIND_2x2_001"]:
		_verifica(_citta.catalogo.zona(id).is_empty(),
			"%s porta un servizio di zona che non dovrebbe portare." % id)


## Un presidio per volta: la felicità sale di un settimo a colpo, e la casa si
## ripopola appena arriva a quattro su sette.
func _prova_i_sette_gradini() -> void:
	var soglia := Config.abandon_below()
	_verifica(is_equal_approx(_felicita_casa(), 0.0),
		"Senza presidi la casa non è a zero: %f" % _felicita_casa())
	_verifica(_abbandonata(), "Senza presidi la casa non viene abbandonata.")

	var quanti := PRESIDI.size()
	for i in range(quanti):
		var presidio: Array = PRESIDI[i]
		_posa(str(presidio[1]), presidio[2])
		var atteso := float(i + 1) / float(quanti)
		var ottenuta := _felicita_casa()
		_verifica(is_equal_approx(ottenuta, atteso),
			"Con %d presidi la felicità è %f invece di %f (non arriva %s?)." % [
				i + 1, ottenuta, atteso, presidio[0]])
		_verifica(_abbandonata() == (atteso < soglia),
			"Con %d presidi su %d l'abbandono non segue la soglia %.2f." % [
				i + 1, quanti, soglia])
	_verifica(is_equal_approx(_felicita_casa(), 1.0),
		"Con tutti e sette i presidi la casa non arriva al pieno.")


## La felicità della città pesa sugli abitanti, non sugli edifici: la torre
## scontenta lontana da tutto conta per quanta gente ci sta.
func _prova_la_media_pesata() -> void:
	var felicita: Dictionary = _citta._felicita_per_edificio()
	_verifica(is_equal_approx(float(felicita.get(_id_torre, -1.0)), 0.0),
		"La torre lontana da tutto non è a zero.")
	var teste_casa: int = _citta.catalogo.abitanti("RES_LOW_1x1_001")
	var teste_torre: int = _citta.catalogo.abitanti("RES_TOWER_3x3_001")
	_verifica(teste_torre > teste_casa, "La torre non ospita più gente della casa.")
	var atteso := float(teste_casa) / float(teste_casa + teste_torre)
	_verifica(is_equal_approx(_citta._felicita_media(felicita), atteso),
		"La media della città è %f invece di %f." % [
			_citta._felicita_media(felicita), atteso])


## Un presidio senza strada è chiuso, e la sua area sparisce insieme a lui.
func _prova_la_strada_tolta() -> void:
	var sotto_la_polizia: Array[Vector2i] = [
		Vector2i(16, RIGA_STRADA), Vector2i(17, RIGA_STRADA),
	]
	for cella in sotto_la_polizia:
		_demolisci(cella)
	_verifica(is_equal_approx(_felicita_casa(), 6.0 / 7.0),
		"Togliendo la strada alla polizia la felicità è %f." % _felicita_casa())
	for cella in sotto_la_polizia:
		_posa("ROAD_LOCAL_1x1_STRAIGHT", cella)
	_verifica(is_equal_approx(_felicita_casa(), 1.0),
		"Ridando la strada alla polizia la felicità non torna piena.")


## Demolire presidi riporta la casa sotto la soglia, e la casa viene
## riabbandonata.
func _prova_il_presidio_demolito() -> void:
	for i in range(4):
		var presidio: Array = PRESIDI[PRESIDI.size() - 1 - i]
		_demolisci(presidio[2])
		var atteso := float(PRESIDI.size() - 1 - i) / float(PRESIDI.size())
		_verifica(is_equal_approx(_felicita_casa(), atteso),
			"Demolito %s la felicità è %f invece di %f." % [
				presidio[0], _felicita_casa(), atteso])
	_verifica(_abbandonata(), "Tornata a tre su sette, la casa non viene riabbandonata.")
	_citta._aggiorna_i_conti()


func _felicita_casa() -> float:
	return float(_citta._felicita_per_edificio().get(_id_casa, -1.0))


func _abbandonata() -> bool:
	return _citta._abbandonate(_citta._felicita_per_edificio()).has(_id_casa)
