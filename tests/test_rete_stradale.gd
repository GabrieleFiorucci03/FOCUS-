# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.

extends SceneTree
## Prove rapide della geometria pura usata dal tracciamento stradale.
##
## Si eseguono con Godot headless, senza aprire né modificare il salvataggio:
##   godot --headless --path . --script res://tests/test_rete_stradale.gd

var _fallimenti := PackedStringArray()


func _init() -> void:
	_prova_i_sedici_pezzi()
	_prova_le_rotazioni_della_rampa()
	_prova_i_due_gomiti()
	_prova_i_nomi_dei_modelli()
	if not _fallimenti.is_empty():
		for fallimento in _fallimenti:
			push_error(fallimento)
		quit(1)
		return
	print("ReteStradale: tutte le prove sono passate.")
	quit()


func _verifica(condizione: bool, messaggio: String) -> void:
	if not condizione:
		_fallimenti.append(messaggio)


func _prova_i_sedici_pezzi() -> void:
	for maschera in range(1, 16):
		var scelto := ReteStradale.pezzo(maschera)
		var base := int(ReteStradale.BRACCIA[str(scelto["variante"])])
		var ottenuta := ReteStradale.maschera_ruotata(base, int(scelto["rotazione"]))
		_verifica(ottenuta == maschera,
			"Maschera %d ricostruita come %d" % [maschera, ottenuta])
	var solitario := ReteStradale.pezzo(0)
	_verifica(solitario["variante"] == "STRAIGHT", "Il pezzo solitario non è un dritto.")
	_verifica(int(solitario["rotazione"]) == 0, "Il pezzo solitario è ruotato.")


func _prova_le_rotazioni_della_rampa() -> void:
	for direzione in ReteStradale.DIREZIONI:
		var quarti := ReteStradale.rotazione_della_rampa(direzione)
		_verifica(ReteStradale.ruota(Vector2i(0, -1), quarti) == direzione,
			"La rampa non sale verso %s." % direzione)


func _prova_i_due_gomiti() -> void:
	var partenza := Vector2i(2, 3)
	var arrivo := Vector2i(5, 7)
	for prima_x in [true, false]:
		var percorso := ReteStradale.percorso_a_elle(partenza, arrivo, prima_x)
		_verifica(percorso.size() == 8, "Il percorso a elle non ha 8 celle.")
		_verifica(percorso.front() == partenza, "Il percorso non parte dalla cella chiesta.")
		_verifica(percorso.back() == arrivo, "Il percorso non arriva alla cella chiesta.")
		for i in range(1, percorso.size()):
			var passo: Vector2i = percorso[i] - percorso[i - 1]
			_verifica(absi(passo.x) + absi(passo.y) == 1,
				"Il percorso contiene un salto fra %s e %s." % [percorso[i - 1], percorso[i]])
		var gomito := Vector2i(arrivo.x, partenza.y) if prima_x \
			else Vector2i(partenza.x, arrivo.y)
		_verifica(percorso.has(gomito), "Il percorso non passa dal gomito %s." % gomito)


func _prova_i_nomi_dei_modelli() -> void:
	for famiglia in ReteStradale.FAMIGLIE:
		_verifica(not ReteStradale.id_del_pezzo(famiglia, "STRAIGHT").is_empty(),
			"Manca il modello dritto della famiglia %s." % famiglia)
		_verifica(not ReteStradale.id_della_rampa(famiglia).is_empty(),
			"Manca la rampa della famiglia %s." % famiglia)
		var voce := ReteStradale.voce_della_famiglia(famiglia)
		_verifica(ReteStradale.famiglia_della_voce(voce) == famiglia,
			"La voce %s non torna alla famiglia %s." % [voce, famiglia])
