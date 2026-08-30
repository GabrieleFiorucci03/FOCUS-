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

class_name GraficoGiorni
extends Control
## Le ultime due settimane di focus, una colonna per giorno.
##
## I giorni vuoti si disegnano lo stesso, come colonna appena accennata: è il
## buco a raccontare la storia, e una settimana con tre barre attaccate
## direbbe una cosa diversa da quella vera.

const GIORNI := 14

## Godot numera i giorni della settimana partendo dalla domenica.
const INIZIALI: Array[String] = ["D", "L", "M", "M", "G", "V", "S"]

const COLORE_BARRA := Color(0.176, 0.404, 0.427)
const COLORE_OGGI := Color(0.180392, 0.768627, 0.713726)
const COLORE_TESTO := Color(0.545098, 0.588235, 0.639216)
const COLORE_TRACCIA := Color(1.0, 1.0, 1.0, 0.16)
const COLORE_GRIGLIA := Color(1.0, 1.0, 1.0, 0.10)

## Lo zoccolo sotto ogni colonna, in pixel.
const ZOCCOLO := 3.0

## Altezza riservata alle iniziali sotto le colonne.
const PIEDE := 16.0
## Altezza riservata all'etichetta del fondoscala.
const TESTA := 14.0

var _giorni: Array = []
var _scala: float = 3600.0


func aggiorna() -> void:
	_giorni = SaveManager.ultimi_giorni(GIORNI)
	var picco := 0.0
	for giorno in _giorni:
		picco = maxf(picco, float(giorno["secondi"]))
	# Il fondoscala non scende mai sotto l'ora e sale di mezz'ora in mezz'ora:
	# senza un minimo, venti minuti riempirebbero il grafico e sembrerebbero
	# una giornata piena.
	_scala = maxf(3600.0, ceil(picco / 1800.0) * 1800.0)
	queue_redraw()


func _draw() -> void:
	if _giorni.is_empty():
		return

	var font := get_theme_default_font()
	var base := size.y - PIEDE
	var cima := TESTA
	if base <= cima:
		return

	draw_line(Vector2(0.0, base), Vector2(size.x, base), COLORE_GRIGLIA)
	draw_line(Vector2(0.0, cima), Vector2(size.x, cima), COLORE_GRIGLIA)
	draw_string(font, Vector2(0.0, cima - 3.0), Durata.discorsiva(int(_scala)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLORE_TESTO)

	var passo := size.x / float(_giorni.size())
	var larghezza := minf(passo - 5.0, 24.0)

	for i in _giorni.size():
		var giorno: Dictionary = _giorni[i]
		var oggi := i == _giorni.size() - 1
		var colore := COLORE_OGGI if oggi else COLORE_BARRA
		var x := passo * float(i) + (passo - larghezza) * 0.5
		var altezza := (base - cima) * clampf(float(giorno["secondi"]) / _scala, 0.0, 1.0)

		# Uno zoccolo basso invece della colonna intera in trasparenza: una
		# traccia alta come il grafico si legge come una giornata grigia, non
		# come una giornata vuota, ed e' esattamente il contrario di quello che
		# deve dire.
		draw_rect(Rect2(x, base - ZOCCOLO, larghezza, ZOCCOLO), COLORE_TRACCIA, true)
		if altezza >= ZOCCOLO:
			draw_rect(Rect2(x, base - altezza, larghezza, altezza), colore, true)
		draw_string(font, Vector2(x, base + 12.0), _iniziale(str(giorno["data"])),
			HORIZONTAL_ALIGNMENT_CENTER, larghezza, 10,
			colore if oggi else COLORE_TESTO)


## L'iniziale del giorno della settimana di una data "AAAA-MM-GG".
static func _iniziale(data: String) -> String:
	var istante := int(Time.get_unix_time_from_datetime_string(data + "T12:00:00"))
	var pezzi := Time.get_datetime_dict_from_unix_time(istante)
	return INIZIALI[int(pezzi["weekday"]) % 7]
