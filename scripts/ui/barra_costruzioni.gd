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

## Quanto è grande il ritratto di un modello, in pixel. Le schede sono piccole:
## più grande di così non si vedrebbe meglio, e sono novanta texture da tenere.
const LATO_RITRATTO := 96
## Da dove li guarda la telecamera dello studio. Stessa inclinazione e stessa
## imbardata della città: nella fascia un modello ha già la faccia che avrà una
## volta posato, e riconoscerlo non richiede di immaginarselo girato.
const INCLINAZIONE_STUDIO := 38.0
const IMBARDATA_STUDIO := 45.0

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
## id della voce -> il riquadro dove va il suo ritratto, quando è pronto.
var _ritratti: Dictionary = {}

## Lo studio dove si fanno i ritratti: un mondo tutto suo, grande una scheda.
var _studio: SubViewport
var _telecamera: Camera3D
## Cambia a ogni catalogo nuovo: i ritratti in coda del vecchio si accorgono di
## essere in ritardo e si fermano invece di scrivere sulle schede di adesso.
var _generazione: int = 0

var _trascinamento := false
var _percorso := 0.0


func _ready() -> void:
	_gruppo = ButtonGroup.new()
	_gruppo.allow_unpress = true
	_prepara_lo_studio()
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
	_generazione += 1
	_schede.clear()
	_ritratti.clear()
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
	_scatta_i_ritratti(_generazione)


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


## Una scheda è un pulsante con dentro il ritratto del modello, il nome e il
## prezzo. Il contenuto non prende il mouse: il pulsante resta uno solo, e sa
## già disegnarsi acceso, spento e sotto il dito senza che glielo si dica.
func _crea_scheda(id: String) -> Button:
	var v := _catalogo.voce(id)
	var f: Vector2i = v["footprint"]
	var scheda := Button.new()
	scheda.custom_minimum_size = Vector2(118, 92)
	scheda.toggle_mode = true
	scheda.button_group = _gruppo
	scheda.tooltip_text = "%s · %d crediti · ingombro %dx%d celle" % [
		v["nome"], _catalogo.prezzo(id), f.x, f.y
	]
	scheda.toggled.connect(_on_scheda_commutata.bind(id))

	var colonna := VBoxContainer.new()
	colonna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	colonna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_theme_constant_override("separation", 1)
	scheda.add_child(colonna)

	# Vuoto finché lo studio non arriva a questo modello: la scheda si può già
	# leggere e cliccare, il ritratto la raggiunge.
	var ritratto := TextureRect.new()
	ritratto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ritratto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ritratto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ritratto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(ritratto)

	var nome := Label.new()
	nome.text = str(v["nome"])
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.max_lines_visible = 2
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nome.add_theme_font_size_override("font_size", 11)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(nome)

	var prezzo := Label.new()
	prezzo.text = "%d cr" % _catalogo.prezzo(id)
	prezzo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prezzo.add_theme_font_size_override("font_size", 11)
	prezzo.add_theme_color_override("font_color", Color(0.905882, 0.85098, 0.505882))
	prezzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(prezzo)

	_schede[id] = scheda
	_ritratti[id] = ritratto
	return scheda


func _crea_attrezzo(id: String) -> Button:
	var attrezzo := Button.new()
	attrezzo.custom_minimum_size = Vector2(108, 92)
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
		var scheda := _schede[id] as Button
		var troppo_caro := _catalogo.prezzo(str(id)) > _crediti
		scheda.disabled = troppo_caro
		# Un pulsante spento si sbiadisce da solo, quello che ci sta dentro no.
		(scheda.get_child(0) as Control).modulate.a = 0.35 if troppo_caro else 1.0


## Riporta la barra a riposo. La chiama CityView quando si esce da una
## modalità, quindi non deve rimbalzare indietro nessun segnale.
func deseleziona() -> void:
	var acceso := _gruppo.get_pressed_button()
	if acceso != null:
		acceso.set_pressed_no_signal(false)
	_dettaglio.text = TESTO_VUOTO


# --- Lo studio dei ritratti -------------------------------------------------

## Il posto dove i modelli si fanno fotografare: un SubViewport grande una
## scheda, con un mondo tutto suo perche' la citta' non ci entri dentro.
##
## Uno solo, riusato novanta volte. Novanta viewport vivi costerebbero come un
## secondo mondo 3D, e queste immagini non cambiano mai piu' dopo essere state
## scattate: una texture ferma e' tutto quello che serve.
func _prepara_lo_studio() -> void:
	_studio = SubViewport.new()
	_studio.size = Vector2i(LATO_RITRATTO, LATO_RITRATTO)
	_studio.transparent_bg = true
	_studio.own_world_3d = true
	_studio.gui_disable_input = true
	_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_studio)

	var ambiente := WorldEnvironment.new()
	var mondo := Environment.new()
	mondo.background_mode = Environment.BG_CLEAR_COLOR
	mondo.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	mondo.ambient_light_color = Color(0.72, 0.78, 0.86)
	mondo.ambient_light_energy = 1.1
	mondo.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = mondo
	_studio.add_child(ambiente)

	# Lo stesso sole della citta', per la stessa ragione della telecamera.
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sole.light_energy = 0.95
	_studio.add_child(sole)

	_telecamera = Camera3D.new()
	_telecamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_studio.add_child(_telecamera)


## Fa il ritratto a tutti i modelli del catalogo, uno per frame.
##
## Uno per frame perche' scattare vuol dire aspettare che il rendering abbia
## finito, e nel frattempo il gioco continua a girare: le schede stanno gia' li'
## col loro nome e il loro prezzo, e l'immagine le raggiunge quando e' pronta.
## Novanta modelli sono un paio di secondi, spesi mentre si guarda il menu.
func _scatta_i_ritratti(generazione: int) -> void:
	for id in _ritratti.keys():
		if generazione != _generazione or not is_inside_tree():
			return
		var ritratto: Texture2D = await _fotografa(str(id))
		if generazione != _generazione or not is_inside_tree():
			return
		var riquadro: TextureRect = _ritratti.get(id)
		if ritratto != null and is_instance_valid(riquadro):
			riquadro.texture = ritratto


## Mette un modello nello studio, lo inquadra, scatta e lo porta via.
func _fotografa(id: String) -> Texture2D:
	var scena := load(CityCatalog.CARTELLA_MODELLI + str(_catalogo.voce(id)["modello"])) as PackedScene
	if scena == null:
		return null
	var modello: Node3D = scena.instantiate()
	_studio.add_child(modello)

	var ingombro := _ingombro(modello)
	if ingombro.size == Vector3.ZERO:
		_studio.remove_child(modello)
		modello.queue_free()
		return null
	_inquadra(ingombro)

	_studio.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var immagine := _studio.get_texture().get_image()

	# Via subito, non a fine frame: queue_free() lascerebbe due modelli nello
	# studio quando si scatta il prossimo.
	_studio.remove_child(modello)
	modello.queue_free()
	return ImageTexture.create_from_image(immagine)


## Punta la telecamera sul modello e stringe quanto basta a contenerlo. Un
## palazzo riempie la sua scheda come una panchina riempie la sua: nella fascia
## conta riconoscere la forma, e le dimensioni vere le dice l'ingombro in celle.
func _inquadra(ingombro: AABB) -> void:
	var centro := ingombro.get_center()
	var raggio := maxf(ingombro.size.length() * 0.5, 0.4)
	_telecamera.size = raggio * 2.05
	_telecamera.near = 0.05
	_telecamera.far = raggio * 40.0
	var verso := Vector3(0.0, 0.0, 1.0) 		.rotated(Vector3.RIGHT, deg_to_rad(-INCLINAZIONE_STUDIO)) 		.rotated(Vector3.UP, deg_to_rad(IMBARDATA_STUDIO))
	_telecamera.position = centro + verso * raggio * 12.0
	_telecamera.look_at(centro, Vector3.UP)


## Quanto spazio occupa un modello, senza sapere niente di com'e' fatto dentro.
## Le "-colonly" della pipeline non sono mesh e restano fuori da sole.
static func _ingombro(radice: Node) -> AABB:
	var totale := AABB()
	var trovata := false
	var da_vedere: Array[Node] = [radice]
	while not da_vedere.is_empty():
		var nodo: Node = da_vedere.pop_back()
		for figlio in nodo.get_children():
			da_vedere.append(figlio)
		if not nodo is VisualInstance3D:
			continue
		var pezzo := nodo as VisualInstance3D
		var suo: AABB = pezzo.global_transform * pezzo.get_aabb()
		totale = suo if not trovata else totale.merge(suo)
		trovata = true
	return totale if trovata else AABB()


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
