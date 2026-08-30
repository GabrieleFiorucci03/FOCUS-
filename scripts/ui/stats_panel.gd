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

class_name StatsPanel
extends Control
## Quanto hai fatto, e da quanti giorni di fila lo fai.
##
## Il pannello non calcola niente per conto suo: legge SaveManager, che è
## l'unico a sapere quali giorni contano. Qui si decide solo come dirlo.

signal chiuso()

## Le quattro cifre grandi, nell'ordine in cui compaiono.
const CIFRE: Array[Dictionary] = [
	{ "id": "streak", "etichetta": "giorni di fila" },
	{ "id": "record", "etichetta": "record" },
	{ "id": "focus", "etichetta": "focus totale" },
	{ "id": "sessioni", "etichetta": "sessioni" },
]

const COLORE_ACCENTO := Color(0.180392, 0.768627, 0.713726)
const COLORE_TENUE := Color(0.545098, 0.588235, 0.639216)

@onready var _cifre: GridContainer = %Cifre
@onready var _grafico: GraficoGiorni = %Grafico
@onready var _oggi: Label = %Oggi
@onready var _riepilogo: Label = %Riepilogo
@onready var _chiudi: Button = %Chiudi

## id della cifra -> la Label che ne mostra il valore.
var _valori: Dictionary = {}


func _ready() -> void:
	_costruisci_le_cifre()
	_chiudi.pressed.connect(chiudi)
	SaveManager.stats_changed.connect(_aggiorna_se_aperto)
	hide()


func apri() -> void:
	aggiorna()
	show()
	_chiudi.grab_focus()


func chiudi() -> void:
	if not visible:
		return
	Sfx.suona("clic")
	hide()
	chiuso.emit()


func aggiorna() -> void:
	var streak := SaveManager.streak_attuale()
	_valori["streak"].text = str(streak)
	_valori["record"].text = str(SaveManager.streak_record())
	_valori["focus"].text = Durata.discorsiva(SaveManager.total_focus_seconds)
	_valori["sessioni"].text = str(SaveManager.sessions_completed)

	# Lo streak è l'unico numero che può spegnersi da solo, senza che tu abbia
	# fatto niente: vale la pena che si veda quando è acceso.
	_valori["streak"].add_theme_color_override("font_color",
		COLORE_ACCENTO if streak > 0 else COLORE_TENUE)

	var chiave := SaveManager.chiave_di_oggi()
	var secondi_oggi := SaveManager.secondi_del_giorno(chiave)
	var sessioni_oggi := SaveManager.sessioni_del_giorno(chiave)
	if sessioni_oggi == 0:
		_oggi.text = "Oggi non hai ancora cominciato."
	else:
		_oggi.text = "Oggi: %s in %d %s." % [
			Durata.discorsiva(secondi_oggi), sessioni_oggi,
			"sessione" if sessioni_oggi == 1 else "sessioni",
		]

	_grafico.aggiorna()
	_riepilogo.text = _riga_di_chiusura()


# Solo se è aperto: ridisegnare un pannello nascosto è lavoro buttato, e
# riaprendolo si aggiorna comunque.
func _aggiorna_se_aperto() -> void:
	if visible:
		aggiorna()


func _input(evento: InputEvent) -> void:
	# _input e non _unhandled_input: da aperto questo pannello viene prima di
	# tutto, e l'Esc non deve arrivare alla città a spegnerle uno strumento.
	if not visible:
		return
	if evento.is_action_pressed("ui_cancel"):
		chiudi()
		get_viewport().set_input_as_handled()


# --- Costruzione ------------------------------------------------------------

func _costruisci_le_cifre() -> void:
	for cifra in CIFRE:
		var colonna := VBoxContainer.new()
		colonna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colonna.add_theme_constant_override("separation", 0)

		var valore := Label.new()
		valore.text = "0"
		valore.add_theme_font_size_override("font_size", 34)
		valore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var etichetta := Label.new()
		etichetta.text = str(cifra["etichetta"])
		etichetta.add_theme_font_size_override("font_size", 12)
		etichetta.add_theme_color_override("font_color", COLORE_TENUE)
		etichetta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		colonna.add_child(valore)
		colonna.add_child(etichetta)
		_cifre.add_child(colonna)
		_valori[str(cifra["id"])] = valore


func _riga_di_chiusura() -> String:
	var pezzi := PackedStringArray()
	pezzi.append("%d crediti guadagnati in tutto" % SaveManager.credits_earned_total)
	var sessioni := SaveManager.sessions_completed
	if sessioni > 0:
		pezzi.append("media di %s a sessione" % Durata.discorsiva(
			SaveManager.total_focus_seconds / sessioni))
	var attivi := SaveManager.giorni_attivi()
	pezzi.append("%d %s di attività" % [attivi, "giorno" if attivi == 1 else "giorni"])
	return " · ".join(pezzi)
