# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.

extends Node
## Prove d'integrazione del tracciamento: terreno, griglia, catalogo e pezzi.
##
## Il salvataggio su disco non viene toccato: la prova sostituisce soltanto i
## dati in memoria e non chiama mai le operazioni di acquisto o salvataggio.

const SCENA_CITTA := preload("res://scenes/city/CityView.tscn")

var _citta
var _fallimenti := PackedStringArray()


func _ready() -> void:
	SaveManager.data = {
		"credits": 100000,
		"world": { "seed": 424242, "zones": [[0, 0]], "tiles": [], "terrain_edits": [] },
	}
	_citta = SCENA_CITTA.instantiate()
	add_child(_citta)
	_citta._scelto = ReteStradale.voce_della_famiglia("asfaltata")
	_verifica(_citta.CELLA_NULLA != Vector2i(-1, -1),
		"La cella (-1, -1) non deve essere usata come segnaposto nel mondo infinito.")

	_prova_retta_e_incrocio()
	_prova_rampa_e_dosso()
	_prova_ostacoli()
	_prova_coordinate_negative()
	if not _fallimenti.is_empty():
		for fallimento in _fallimenti:
			push_error(fallimento)
		get_tree().quit(1)
		return
	print("Tracciamento strade: tutte le prove sono passate.")
	get_tree().quit()


func _verifica(condizione: bool, messaggio: String) -> void:
	if not condizione:
		_fallimenti.append(messaggio)


func _rendi_piane(celle: Array[Vector2i], livello: int) -> void:
	for cella in celle:
		_citta.terreno.imposta_livello(cella, livello)
	for cella in celle:
		_citta.terreno.riclassifica_cella(cella)


func _posa_senza_salvare(tracciato: Dictionary) -> void:
	for pezzo in tracciato["pezzi"]:
		var cella: Vector2i = pezzo["cella"]
		var livello := int(pezzo["livello"])
		var sola: Array[Vector2i] = [cella]
		_citta.terreno.spiana(sola, livello)
		_verifica(_citta._costruisci(
			str(pezzo["id"]), cella, int(pezzo["rotazione"]), livello, false),
			"Non è stato possibile posare %s in %s." % [pezzo["id"], cella])
	_citta._rifai_le_forme(tracciato["celle"])


func _prova_retta_e_incrocio() -> void:
	var orizzontale: Array[Vector2i] = []
	for x in range(4, 9):
		orizzontale.append(Vector2i(x, 6))
	_rendi_piane(orizzontale, 4)
	var prima: Dictionary = _citta._calcola_tracciato(orizzontale.front(), orizzontale.back())
	_verifica(prima["celle"] == orizzontale, "La retta non segue le celle richieste.")
	_verifica(prima["pezzi"].size() == 5, "La retta non produce cinque pezzi.")
	_verifica(int(prima["prezzo"]) == 5 * _citta.catalogo.prezzo("ROAD_LOCAL_1x1_STRAIGHT"),
		"Il prezzo della retta non è il prezzo per cella.")
	_posa_senza_salvare(prima)

	var verticale: Array[Vector2i] = []
	for y in range(4, 9):
		verticale.append(Vector2i(6, y))
	_rendi_piane(verticale, 4)
	var seconda: Dictionary = _citta._calcola_tracciato(verticale.front(), verticale.back())
	_verifica(seconda["celle"] == verticale, "La seconda strada non attraversa l'incrocio.")
	_verifica(seconda["pezzi"].size() == 4,
		"L'incrocio esistente è stato contato fra i pezzi da pagare: %s" % seconda)
	_posa_senza_salvare(seconda)
	_verifica(str(_citta.griglia.occupante(Vector2i(6, 6))["modello"]) \
		== "ROAD_LOCAL_1x1_CROSS", "La strada attraversata non diventa un incrocio.")


func _prova_rampa_e_dosso() -> void:
	var salita: Array[Vector2i] = [Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5)]
	_rendi_piane([salita[0]], 4)
	_rendi_piane([salita[1], salita[2]], 5)
	var tracciato: Dictionary = _citta._calcola_tracciato(salita.front(), salita.back())
	_verifica(tracciato["pezzi"].size() == 3, "La salita non produce tre pezzi: %s" % tracciato)
	if tracciato["pezzi"].size() == 3:
		_verifica(str(tracciato["pezzi"][1]["id"]) == "ROAD_LOCAL_SLOPE_1x1_UP_050",
			"Sul gradino non è stata scelta la rampa.")
		_verifica(int(tracciato["pezzi"][1]["livello"]) == 4,
			"Il piede della rampa non è alla quota bassa.")

	var dosso: Array[Vector2i] = [Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9)]
	_rendi_piane([dosso[0], dosso[2]], 4)
	_rendi_piane([dosso[1]], 5)
	var spianato: Dictionary = _citta._calcola_tracciato(dosso.front(), dosso.back())
	_verifica(spianato["quote"] == [4, 4, 4], "Il dosso isolato non viene spianato.")
	for pezzo in spianato["pezzi"]:
		_verifica(not str(pezzo["id"]).contains("SLOPE"),
			"Il dosso isolato ha prodotto una rampa.")


func _prova_ostacoli() -> void:
	var salto: Array[Vector2i] = [Vector2i(20, 5), Vector2i(21, 5), Vector2i(22, 5)]
	_rendi_piane([salto[0]], 4)
	_rendi_piane([salto[1], salto[2]], 6)
	var troncato: Dictionary = _citta._calcola_tracciato(salto.front(), salto.back())
	_verifica(troncato["celle"] == [salto[0]], "La strada supera un salto di due livelli.")
	_verifica(troncato["rifiutate"] == [salto[1], salto[2]],
		"Le celle oltre il salto non risultano rifiutate.")
	_verifica(not str(troncato["motivo"]).is_empty(), "Il salto non spiega perché si ferma.")

	var acqua: Array[Vector2i] = [Vector2i(20, 10), Vector2i(21, 10), Vector2i(22, 10)]
	_rendi_piane([acqua[0], acqua[2]], 4)
	_rendi_piane([acqua[1]], CityTerrain.LIVELLO_ACQUA)
	var sulla_riva: Dictionary = _citta._calcola_tracciato(acqua.front(), acqua.back())
	_verifica(sulla_riva["celle"] == [acqua[0]], "La strada entra nell'acqua.")
	_verifica(sulla_riva["rifiutate"] == [acqua[1], acqua[2]],
		"Le celle oltre l'acqua non risultano rifiutate.")
	_verifica(str(sulla_riva["motivo"]).contains("ponte"),
		"Il messaggio dell'acqua non suggerisce il ponte.")


func _prova_coordinate_negative() -> void:
	SaveManager.world_zones().append([-1, -1])
	var celle: Array[Vector2i] = [Vector2i(-3, -1), Vector2i(-2, -1), Vector2i(-1, -1)]
	_rendi_piane(celle, 4)
	var tracciato: Dictionary = _citta._calcola_tracciato(celle.front(), celle.back())
	_verifica(tracciato["celle"] == celle, "La strada non attraversa le coordinate negative.")
	_citta._cella = Vector2i(-1, -1)
	_citta._comincia_a_tracciare()
	_verifica(_citta._sta_tracciando(), "Non si può iniziare una strada dalla cella (-1, -1).")
	_citta._annulla_il_tracciato()
