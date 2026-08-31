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


class_name BarraCostruzioni
extends Control
## Il negozio: un pulsante col martello e la chiave inglese, e la fascia che
## apre in cima allo schermo.
##
## Prima era un pannello in colonna sulla destra, che si mangiava un quarto
## della città per mostrare venti voci per volta. Adesso è una fascia sola,
## alta un centinaio di pixel: dentro ci sta tutto il catalogo di fila, diviso
## per scaffali, e si scorre trascinandolo col mouse. La città si vede intera,
## e quando non si costruisce la fascia non c'è.
##
## Qui dentro non si compra niente e non si tocca il salvataggio: la barra dice
## solo cosa ha scelto l'utente. Chi paga e chi costruisce è CityView, che è
## l'unico a sapere se il posto scelto va bene.

signal voce_scelta(id: String)
## Lo strumento in mano, o "" quando non ce n'è nessuno.
signal strumento_scelto(strumento: String)

const TESTO_VUOTO := "Scegli qualcosa da costruire."

## Gli attrezzi, nell'ordine in cui compaiono. Costruire sta negli scaffali;
## qui c'è quello che si fa a una città che esiste già.
const STRUMENTI := {
	"alza": "Alza",
	"abbassa": "Abbassa",
	"livella": "Livella",
	"demolisci": "Demolisci",
}

## Oltre questi pixel il gesto non è più un clic ma un trascinamento, e la
## scheda che ci finisce sotto non va selezionata.
const SOGLIA_TRASCINAMENTO := 6.0
## Quanto scorre la fascia a ogni scatto di rotella.
const PASSO_ROTELLA := 120

@onready var _pulsante: Button = %Attrezzi
@onready var _fascia: PanelContainer = %Fascia
@onready var _saldo: Label = %Saldo
@onready var _scaffali: HBoxContainer = %Scaffali
@onready var _fila: HBoxContainer = %Fila
@onready var _scorrimento: ScrollContainer = %Scorrimento
@onready var _dettaglio: Label = %Dettaglio
@onready var _chiudi: Button = %Chiudi

var _catalogo: CityCatalog
var _crediti: int = 0
## Un gruppo solo per schede e attrezzi: si escludono a vicenda, e riclicare
## quello acceso lo spegne invece di lasciare senza via d'uscita.
var _gruppo: ButtonGroup
## id della voce -> la sua scheda, per accenderle e spegnerle sui crediti.
var _schede: Dictionary = {}
## id dello scaffale -> il pezzo di fila dove comincia, per saltarci sopra.
var _inizio_scaffale: Dictionary = {}

var _trascinamento := false
var _percorso := 0.0


func _ready() -> void:
	_gruppo = ButtonGroup.new()
	_gruppo.allow_unpress = true
	_pulsante.toggled.connect(_on_pulsante_commutato)
	_chiudi.pressed.connect(chiudi)
	_fascia.hide()


# --- Aprire e chiudere ------------------------------------------------------

func aperta() -> bool:
	return _fascia.visible


func apri() -> void:
	_pulsante.button_pressed = true


func chiudi() -> void:
	_pulsante.button_pressed = false


func alterna() -> void:
	_pulsante.button_pressed = not _pulsante.button_pressed


func _on_pulsante_commutato(acceso: bool) -> void:
	_fascia.visible = acceso
	_trascinamento = false
	Sfx.suona("clic")


## Se il mouse sta sopra qualcosa di questa barra. CityView lo chiede prima di
## puntare una cella: sotto la fascia non c'è terreno da scegliere, c'è il
## negozio.
func sotto_il_mouse() -> bool:
	var punto := get_viewport().get_mouse_position()
	if _pulsante.get_global_rect().has_point(punto):
		return true
	return _fascia.visible and _fascia.get_global_rect().has_point(punto)


# --- Catalogo ---------------------------------------------------------------

func mostra_catalogo(catalogo: CityCatalog) -> void:
	_catalogo = catalogo
	_schede.clear()
	_inizio_scaffale.clear()
	for vecchio in _fila.get_children():
		_fila.remove_child(vecchio)
		vecchio.queue_free()
	for vecchio in _scaffali.get_children():
		_scaffali.remove_child(vecchio)
		vecchio.queue_free()

	for categoria in catalogo.categorie:
		_aggiungi_scaffale(str(categoria["nome"]), str(categoria["id"]), categoria["voci"])
	_aggiungi_scaffale("Strumenti", "strumenti", PackedStringArray())
	_aggiorna_disponibilita()


## Uno scaffale della fila: il nome sopra, le sue schede sotto, e in testa alla
## fascia la scorciatoia per saltarci. Il nome scorre insieme a quello che
## contiene, così si sa sempre dentro cosa si sta guardando.
func _aggiungi_scaffale(nome: String, id_scaffale: String, voci: PackedStringArray) -> void:
	if _fila.get_child_count() > 0:
		_fila.add_child(VSeparator.new())

	var scaffale := VBoxContainer.new()
	scaffale.add_theme_constant_override("separation", 4)
	var titolo := Label.new()
	titolo.text = nome.to_upper()
	titolo.add_theme_font_size_override("font_size", 11)
	titolo.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	scaffale.add_child(titolo)

	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 4)
	for id in voci:
		riga.add_child(_crea_scheda(str(id)))
	if id_scaffale == "strumenti":
		for id in STRUMENTI:
			riga.add_child(_crea_attrezzo(str(id)))
	scaffale.add_child(riga)

	_fila.add_child(scaffale)
	_inizio_scaffale[id_scaffale] = scaffale

	# Novantuno modelli sono tanti da trascinare: saltare allo scaffale che
	# interessa deve costare un clic.
	var salto := Button.new()
	salto.text = nome
	salto.flat = true
	salto.add_theme_font_size_override("font_size", 12)
	salto.pressed.connect(_vai_allo_scaffale.bind(id_scaffale))
	_scaffali.add_child(salto)


func _crea_scheda(id: String) -> Button:
	var v := _catalogo.voce(id)
	var f: Vector2i = v["footprint"]
	var scheda := Button.new()
	scheda.custom_minimum_size = Vector2(162, 44)
	scheda.toggle_mode = true
	scheda.button_group = _gruppo
	scheda.add_theme_font_size_override("font_size", 12)
	scheda.text = "%s · %d cr" % [v["nome"], _catalogo.prezzo(id)]
	scheda.tooltip_text = "%s · ingombro %dx%d celle" % [v["nome"], f.x, f.y]
	scheda.clip_text = true
	scheda.toggled.connect(_on_scheda_commutata.bind(id))
	_schede[id] = scheda
	return scheda


func _crea_attrezzo(id: String) -> Button:
	var attrezzo := Button.new()
	attrezzo.custom_minimum_size = Vector2(108, 44)
	attrezzo.toggle_mode = true
	attrezzo.button_group = _gruppo
	attrezzo.add_theme_font_size_override("font_size", 12)
	attrezzo.text = str(STRUMENTI[id])
	attrezzo.toggled.connect(_on_attrezzo_commutato.bind(id))
	return attrezzo


func _vai_allo_scaffale(id_scaffale: String) -> void:
	var scaffale: Control = _inizio_scaffale.get(id_scaffale)
	if scaffale == null:
		return
	Sfx.suona("clic")
	_scorrimento.scroll_horizontal = int(scaffale.position.x) - 8


func aggiorna_saldo(crediti: int) -> void:
	_crediti = crediti
	_saldo.text = "%d crediti" % crediti
	_aggiorna_disponibilita()


## Quello che non ci si può permettere resta a schermo, spento: sapere quanto
## manca è metà del motivo per tornare a fare focus.
func _aggiorna_disponibilita() -> void:
	if _catalogo == null:
		return
	for id in _schede:
		(_schede[id] as Button).disabled = _catalogo.prezzo(str(id)) > _crediti


## Riporta la barra a riposo. La chiama CityView quando si esce da una
## modalità, quindi non deve rimbalzare indietro nessun segnale.
func deseleziona() -> void:
	var acceso := _gruppo.get_pressed_button()
	if acceso != null:
		acceso.set_pressed_no_signal(false)
	_dettaglio.text = TESTO_VUOTO


# --- Interazione ------------------------------------------------------------

func _on_scheda_commutata(attivo: bool, id: String) -> void:
	if not attivo:
		_niente_in_mano()
		return
	_dettaglio.text = _descrizione(id)
	voce_scelta.emit(id)


func _on_attrezzo_commutato(attivo: bool, id: String) -> void:
	if not attivo:
		_niente_in_mano()
		return
	_dettaglio.text = _descrizione_strumento(id)
	strumento_scelto.emit(id)


## Cambiando scelta arriva prima lo spegnimento della vecchia: solo se non se
## n'è accesa un'altra vuol dire davvero "niente in mano".
func _niente_in_mano() -> void:
	if _gruppo.get_pressed_button() != null:
		return
	_dettaglio.text = TESTO_VUOTO
	strumento_scelto.emit("")


## La fascia si scorre trascinandola, non con una barra da centrare col mouse.
##
## Il gesto va preso qui e non in _gui_input, perché sotto il dito ci sono le
## schede e sarebbero loro a prendersi il clic. Da _input si arriva prima della
## GUI: finché il gesto è un clic lo si lascia scendere alle schede, e appena
## diventa un trascinamento lo si trattiene, così scorrere la fascia non compra
## mai niente per sbaglio.
func _input(evento: InputEvent) -> void:
	if not _fascia.visible:
		return

	if evento is InputEventMouseMotion:
		if not _trascinamento:
			return
		var moto := evento as InputEventMouseMotion
		_percorso += absf(moto.relative.x)
		_scorrimento.scroll_horizontal -= int(moto.relative.x)
		if _percorso > SOGLIA_TRASCINAMENTO:
			get_viewport().set_input_as_handled()
		return

	if not evento is InputEventMouseButton:
		return
	var clic := evento as InputEventMouseButton
	var dentro := _scorrimento.get_global_rect().has_point(clic.position)
	match clic.button_index:
		MOUSE_BUTTON_LEFT:
			if clic.pressed:
				_trascinamento = dentro
				_percorso = 0.0
			elif _trascinamento:
				_trascinamento = false
				if _percorso > SOGLIA_TRASCINAMENTO:
					_annulla_la_pressione()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			# Sopra la fascia la rotella scorre lo scaffale invece di zoomare:
			# la città sta dietro, ma quello che si sta guardando è qui.
			if clic.pressed and dentro:
				var verso := -1 if clic.button_index == MOUSE_BUTTON_WHEEL_UP else 1
				_scorrimento.scroll_horizontal += verso * PASSO_ROTELLA
				get_viewport().set_input_as_handled()


## Un trascinamento comincia sempre premendo una scheda, e quella scheda la
## pressione l'ha già vista: lasciata così, al rilascio si considererebbe
## cliccata e comprerebbe.
##
## Trattenere il rilascio non basta — un pulsante decide di essere stato
## premuto guardando se il mouse era dentro, non dove è il rilascio. Quello che
## serve è fargli uscire il mouse dai bordi prima, che è poi la stessa strada
## di un dito che scivola via: da lì in poi il rilascio non lo riguarda più.
func _annulla_la_pressione() -> void:
	var fuori := InputEventMouseMotion.new()
	fuori.position = Vector2(-1.0, -1.0)
	fuori.global_position = fuori.position
	fuori.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(fuori, true)


# --- Testi ------------------------------------------------------------------

func _descrizione_strumento(id: String) -> String:
	match id:
		"demolisci":
			return "Clic su una costruzione per demolirla: torna indietro il %d%% del prezzo, ma il terreno resta come l'hai spianato. Esc per smettere." % roundi(Config.refund_ratio * 100.0)
		"livella":
			return "Primo clic: prende la quota. Da lì in poi ci porta le celle che tocchi. %d crediti a gradino, senza rimborso." % Config.terrain_cost_per_level
		_:
			return "%s il terreno di un gradino (0,5 m) a ogni clic. %d crediti a gradino, senza rimborso. Sotto una costruzione non si tocca." % [
				"Alza" if id == "alza" else "Abbassa", Config.terrain_cost_per_level
			]


func _descrizione(id: String) -> String:
	var v := _catalogo.voce(id)
	var f: Vector2i = v["footprint"]
	var pezzi := PackedStringArray()
	pezzi.append("%s · %dx%d celle · %d crediti" % [v["nome"], f.x, f.y, _catalogo.prezzo(id)])
	match _catalogo.regola(id):
		CityCatalog.Regola.PONTE, CityCatalog.Regola.RAMPA:
			pezzi.append("va su qualunque cella libera, e non spiana niente")
			pezzi.append("clic per posare · R ruota · PagSu / PagGiù cambia quota · Esc annulla")
		_:
			pezzi.append("spiana il lotto al livello più basso che tocca")
			pezzi.append("clic per posare · R ruota · Esc annulla")
	return " · ".join(pezzi)
