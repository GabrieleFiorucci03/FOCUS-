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


class_name PannelloCitta
extends Control
## I conti della città: per ogni servizio, quante costruzioni ne restano
## scoperte.
##
## Non è il pannello delle statistiche di focus (quello racconta le giornate di
## concentrazione): questo racconta la città, e sono due cose che si guardano in
## momenti diversi. Ci sta scritto solo quello che non va — il totale di chi
## chiede un servizio è il numero di una città che funziona, e in un pannello di
## problemi è rumore. Cliccando un servizio si accendono sul mondo le costruzioni
## che ne restano scoperte, perché un numero dice quante sono ma non dove sono,
## e per rimediare bisogna sapere dove.
##
## Qui dentro non si conta niente: i conti li fa CityView, che è l'unica a
## sapere cosa c'è in città. Questo li mette in pagina.

## Il servizio da accendere sul mondo, o "" per spegnere tutto.
signal servizio_scelto(id: String)

@onready var _pulsante: Button = %Statistiche
@onready var _pannello: PanelContainer = %Pannello
@onready var _righe: VBoxContainer = %Righe
@onready var _riepilogo: Label = %Riepilogo
@onready var _chiudi: Button = %Chiudi

## Un gruppo solo: si guarda un servizio per volta, e riclicare quello acceso lo
## spegne. Due colori sovrapposti non direbbero niente.
var _gruppo: ButtonGroup
## id del servizio -> il suo pulsante, per riscriverlo senza rifare il pannello.
var _bottoni: Dictionary = {}


func _ready() -> void:
	_gruppo = ButtonGroup.new()
	_gruppo.allow_unpress = true
	_pulsante.toggled.connect(_on_pulsante_commutato)
	_chiudi.pressed.connect(chiudi)
	_pannello.hide()


# --- Aprire e chiudere ------------------------------------------------------

func aperto() -> bool:
	return _pannello.visible


func apri() -> void:
	_pulsante.button_pressed = true


func chiudi() -> void:
	_pulsante.button_pressed = false


func alterna() -> void:
	_pulsante.button_pressed = not _pulsante.button_pressed


## Chiudendo si spegne anche l'evidenza: lasciare la città colorata senza più il
## pannello che spiega di che colore si tratta sarebbe solo un mondo strano.
func _on_pulsante_commutato(acceso: bool) -> void:
	_pannello.visible = acceso
	Sfx.suona("clic")
	if not acceso:
		_spegni()


func _spegni() -> void:
	var scelto := _gruppo.get_pressed_button()
	if scelto != null:
		scelto.set_pressed_no_signal(false)
	servizio_scelto.emit("")


func sotto_il_mouse() -> bool:
	var punto := get_viewport().get_mouse_position()
	if _pulsante.get_global_rect().has_point(punto):
		return true
	return _pannello.visible and _pannello.get_global_rect().has_point(punto)


# --- Contenuto --------------------------------------------------------------

## Rimette in pagina i conti. Ogni riga è
## { id, nome, chiedono, scoperte }, e `riepilogo` è la frase che sta in fondo.
func mostra(righe: Array, riepilogo: String) -> void:
	for riga in righe:
		var id := str(riga["id"])
		if not _bottoni.has(id):
			_bottoni[id] = _crea_riga(id)
		_scrivi_riga(_bottoni[id], riga)
	_riepilogo.text = riepilogo


func _crea_riga(id: String) -> Button:
	var bottone := Button.new()
	bottone.toggle_mode = true
	bottone.button_group = _gruppo
	bottone.custom_minimum_size = Vector2(0, 38)
	bottone.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bottone.add_theme_font_size_override("font_size", 13)
	bottone.toggled.connect(_on_riga_commutata.bind(id))
	_righe.add_child(bottone)
	return bottone


static func _scrivi_riga(bottone: Button, riga: Dictionary) -> void:
	var scoperte := int(riga["scoperte"])
	# Sulla riga ci va solo quello che non va: quante lo chiedono e' il totale
	# di una citta' che funziona, e in un pannello di problemi e' rumore. Resta
	# nel suggerimento, per chi lo cerca.
	bottone.text = "%s · %s" % [
		str(riga["nome"]),
		"tutte servite" if scoperte == 0 else "%d scoperte" % scoperte,
	]
	bottone.tooltip_text = "%d costruzioni chiedono questo servizio.\nClicca per accendere sul mondo quelle scoperte." % int(riga["chiedono"])
	# Il rosso sta sulla riga che ha qualcosa che non va, non su tutte: se sono
	# tutte rosse non se ne guarda nessuna.
	bottone.add_theme_color_override("font_color",
		Color(0.90, 0.44, 0.38) if scoperte > 0 else Color(1, 1, 1, 0.82))


func _on_riga_commutata(attivo: bool, id: String) -> void:
	if attivo:
		servizio_scelto.emit(id)
	elif _gruppo.get_pressed_button() == null:
		servizio_scelto.emit("")
