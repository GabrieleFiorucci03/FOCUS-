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
## Radice dell'app: tiene le due modalità, il menu, e fa passare dall'una all'altra.
##
## Le schermate non vengono create e distrutte a ogni cambio, ma istanziate una
## volta sola e mostrate o nascoste. Serve a garantire che il timer continui a
## scorrere mentre guardi la città: è il punto dell'app, non un dettaglio.

const SCENA_FOCUS := preload("res://scenes/focus/FocusScreen.tscn")
const SCENA_CITTA := preload("res://scenes/city/CityView.tscn")
const SCENA_MENU := preload("res://scenes/main/MainMenu.tscn")
const SCENA_STATISTICHE := preload("res://scenes/ui/StatsPanel.tscn")

## Quanto dura una dissolvenza, in secondi. Corta di proposito: serve a non far
## sbattere l'occhio fra una schermata 2D e un mondo 3D, non a farsi ammirare.
const CHIUSURA := 0.12
const APERTURA := 0.16

@onready var _schermate: Node = $Schermate
@onready var _sovrapposizioni: CanvasLayer = $Sovrapposizioni
@onready var _barra: HBoxContainer = %Modalita
@onready var _bottone_focus: Button = %ModoFocus
@onready var _bottone_citta: Button = %ModoCitta
@onready var _bottone_menu: Button = %Menu
@onready var _dissolvenza: ColorRect = %Dissolvenza

var _focus: FocusScreen
var _citta: Node3D
var _menu: MainMenu
var _statistiche: StatsPanel

var _in_focus: bool = true
var _in_transizione: bool = false


func _ready() -> void:
	_focus = SCENA_FOCUS.instantiate()
	_citta = SCENA_CITTA.instantiate()
	_schermate.add_child(_focus)
	_schermate.add_child(_citta)

	_menu = SCENA_MENU.instantiate()
	_statistiche = SCENA_STATISTICHE.instantiate()
	_sovrapposizioni.add_child(_menu)
	_sovrapposizioni.add_child(_statistiche)

	_bottone_focus.pressed.connect(_vai_a.bind(true))
	_bottone_citta.pressed.connect(_vai_a.bind(false))
	_bottone_menu.pressed.connect(_apri_il_menu)

	_menu.gioca.connect(_chiudi_il_menu)
	_menu.statistiche_richieste.connect(_apri_le_statistiche)
	_menu.nuova_partita_richiesta.connect(_ricomincia)
	_menu.uscita_richiesta.connect(_esci)
	_statistiche.chiuso.connect(_applica_stato)
	_focus.statistiche_richieste.connect(_apri_le_statistiche)

	# Si parte dal menu: la prima cosa che l'app dice è cosa è, non un
	# countdown già pronto su una durata che nessuno ha scelto.
	_menu.show()
	_applica_stato()


func _unhandled_input(evento: InputEvent) -> void:
	# In città l'Esc lo prende prima CityView, per posare l'attrezzo che ha in
	# mano: qui arriva solo quando non c'era niente da posare. Con le statistiche
	# aperte non arriva affatto, perché le prende il pannello.
	if evento.is_action_pressed("ui_cancel"):
		alterna_il_menu()
		get_viewport().set_input_as_handled()


## L'Esc apre il menu, e da aperto lo richiude: è lo stesso tasto che in città
## posa l'attrezzo, e deve voler dire sempre "torna indietro di un passo".
func alterna_il_menu() -> void:
	if _statistiche.visible:
		return
	if _menu.visible:
		_chiudi_il_menu()
	else:
		_apri_il_menu()


func _notification(che_cosa: int) -> void:
	if che_cosa == NOTIFICATION_WM_CLOSE_REQUEST:
		_chiudi_bottega()


# --- Schermate --------------------------------------------------------------

## Mette in pagina lo stato: chi si vede, chi gira, cosa è cliccabile.
##
## Un posto solo per questa decisione, perché le condizioni si intrecciano —
## il menu può aprirsi sopra la città, le statistiche sopra il menu — e sparse
## fra i gestori di eventi finirebbero prima o poi per contraddirsi.
func _applica_stato() -> void:
	var davanti := _c_e_qualcosa_davanti()
	_focus.visible = _in_focus
	_citta.visible = not _in_focus
	# La città smette di girare quando non si vede, e anche quando le sta
	# davanti qualcosa: l'anteprima non deve inseguire un mouse che sta
	# cliccando un pulsante del menu. La schermata focus invece non si ferma
	# mai, altrimenti si fermerebbe il countdown.
	var citta_viva := not _in_focus and not davanti
	_citta.process_mode = Node.PROCESS_MODE_INHERIT if citta_viva else Node.PROCESS_MODE_DISABLED
	_bottone_focus.button_pressed = _in_focus
	_bottone_citta.button_pressed = not _in_focus
	_barra.visible = not davanti


func _c_e_qualcosa_davanti() -> bool:
	return _menu.visible or _statistiche.visible


func _vai_a(focus: bool) -> void:
	if focus == _in_focus or _in_transizione:
		_applica_stato()
		return
	Sfx.suona("clic")
	_in_focus = focus
	_dissolvi(_applica_stato)


## Chiude, cambia quello che c'è da cambiare, riapre.
func _dissolvi(a_meta: Callable) -> void:
	_in_transizione = true
	var tw := create_tween()
	tw.tween_property(_dissolvenza, "color:a", 1.0, CHIUSURA)
	tw.tween_callback(a_meta)
	tw.tween_property(_dissolvenza, "color:a", 0.0, APERTURA)
	tw.tween_callback(func() -> void: _in_transizione = false)


# --- Menu e statistiche -----------------------------------------------------

func _apri_il_menu() -> void:
	if _menu.visible:
		return
	Sfx.suona("clic")
	_menu.aggiorna()
	_menu.show()
	_applica_stato()


func _chiudi_il_menu() -> void:
	_menu.hide()
	_applica_stato()


func _apri_le_statistiche() -> void:
	_statistiche.apri()
	_applica_stato()


# --- Partita ----------------------------------------------------------------

## Butta via tutto e riparte da un mondo nuovo.
##
## La città va ricostruita davvero, non svuotata: legge il seme una volta sola,
## in _ready, e un seme nuovo vuole un terreno nuovo.
func _ricomincia() -> void:
	_focus.abbandona_la_sessione()
	_dissolvi(func() -> void:
		SaveManager.reset_game()
		var vecchia := _citta
		_schermate.remove_child(vecchia)
		vecchia.queue_free()
		_citta = SCENA_CITTA.instantiate()
		_schermate.add_child(_citta)
		_in_focus = true
		_menu.aggiorna()
		_applica_stato()
	)


func _esci() -> void:
	_chiudi_bottega()
	get_tree().quit()


## Una sessione in corso non si butta via perché si chiude la finestra: vale il
## tempo svolto, esattamente come se avessi premuto Termina.
func _chiudi_bottega() -> void:
	_focus.chiudi_la_sessione()
	SaveManager.save_game()
