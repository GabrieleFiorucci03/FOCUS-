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
## Radice dell'app: tiene le due modalità e fa passare dall'una all'altra.
##
## Le schermate non vengono create e distrutte a ogni cambio, ma istanziate una
## volta sola e mostrate o nascoste. Serve a garantire che il timer continui a
## scorrere mentre guardi la città: è il punto dell'app, non un dettaglio.

const SCENA_FOCUS := preload("res://scenes/focus/FocusScreen.tscn")
const SCENA_CITTA := preload("res://scenes/city/CityView.tscn")

@onready var _schermate: Node = $Schermate
@onready var _bottone_focus: Button = %ModoFocus
@onready var _bottone_citta: Button = %ModoCitta

var _focus: Control
var _citta: Node3D


func _ready() -> void:
	_focus = SCENA_FOCUS.instantiate()
	_citta = SCENA_CITTA.instantiate()
	_schermate.add_child(_focus)
	_schermate.add_child(_citta)

	_bottone_focus.pressed.connect(_mostra.bind(true))
	_bottone_citta.pressed.connect(_mostra.bind(false))
	_mostra(true)


func _mostra(focus: bool) -> void:
	_focus.visible = focus
	_citta.visible = not focus
	# La città smette di girare quando non si vede; la schermata focus no,
	# altrimenti il countdown si fermerebbe appena cambi modalità.
	_citta.process_mode = Node.PROCESS_MODE_DISABLED if focus else Node.PROCESS_MODE_INHERIT
	_bottone_focus.button_pressed = focus
	_bottone_citta.button_pressed = not focus
