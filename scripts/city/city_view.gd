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

extends Node3D
## Il mondo della città: terreno procedurale, griglia, camera, negozio e cantiere.
##
## Il terreno si rigenera dal seme salvato: del suolo naturale non finisce su
## disco nemmeno una quota. Su disco vanno il seme, le celle costruite e le
## quote spianate — quelle sì, perché costruire muove il suolo e il seme da solo
## non se ne ricorderebbe.

## Le coordinate di griglia non sono mai negative, quindi questa vale "nessuna".
const CELLA_NULLA := Vector2i(-1, -1)

## Il terreno è l'unica cosa che il raggio del mouse deve colpire. Gli edifici
## restano fuori da ogni layer: puntando una casa si vuole la cella su cui
## poggia, non la sua grondaia.
const LAYER_TERRENO := 1

const COLORE_VALIDO := Color(0.36, 0.84, 0.47, 0.55)
const COLORE_INVALIDO := Color(0.90, 0.31, 0.26, 0.50)
const COLORE_DEMOLIZIONE := Color(0.95, 0.47, 0.20, 0.45)
const COLORE_SPOSTAMENTO := Color(0.36, 0.70, 0.95, 0.45)
const COLORE_SCOPERTO := Color(0.92, 0.28, 0.24, 0.55)

## Quanto si scurisce una costruzione a cui manca qualcosa, e il rosso del punto
## esclamativo che le sta sopra.
const VELO_SCOPERTO := Color(0.03, 0.02, 0.06, 0.75)
const COLORE_SEGNALE := Color(0.95, 0.26, 0.22)
## Quanto lontano dal centro di un punto esclamativo vale ancora come averlo
## preso. Un cartello piccolo su uno schermo grande vuole un bersaglio più largo
## di quello che si vede, altrimenti si clicca tre volte prima di beccarlo.
const RAGGIO_SEGNALE := 22.0

## I servizi di cui la città tiene il conto, nell'ordine in cui si leggono. Le
## chiavi sono quelle che il pannello rimanda indietro quando se ne clicca uno.
## I cinque presidi civici (polizia, sanità, pompieri, le due scuole) non sono
## qui perché non hanno ancora un'area di azione: quando ce l'avranno entrano in
## questo elenco, e il resto funziona già.
const SERVIZI := [
	{ "id": "strada", "nome": "Strada" },
	{ "id": "corrente", "nome": "Corrente" },
	{ "id": "acqua", "nome": "Acqua" },
]

enum Modo { NAVIGA, PIAZZA, DEMOLISCI, TERRENO, SPOSTA }

## Gli attrezzi della modalità terreno.
enum Attrezzo { ALZA, ABBASSA, LIVELLA }

@onready var _terreno_mesh: MeshInstance3D = $Terreno
@onready var _forma_terreno: CollisionShape3D = $Terreno/Corpo/Forma
@onready var _acqua_mesh: MeshInstance3D = $Acqua
@onready var _reticolo: MeshInstance3D = $Griglia
@onready var _selezione: MeshInstance3D = $Selezione
@onready var _evidenza: MeshInstance3D = $Evidenza
@onready var _edifici: Node3D = $Edifici
@onready var _segnali: Node3D = $Segnali
@onready var _anteprima: Node3D = $Anteprima
@onready var _camera: IsoCamera = $Camera
@onready var _sole: DirectionalLight3D = $Sole
@onready var _interfaccia: CanvasLayer = $Interfaccia
@onready var _barra: BarraCostruzioni = %Costruzioni
@onready var _conti: PannelloCitta = %Conti
@onready var _aiuto: Label = %Aiuto
@onready var _messaggio_label: Label = %Messaggio

var griglia: CityGrid
var terreno: CityTerrain
var catalogo: CityCatalog

var _modo: Modo = Modo.NAVIGA
## Cosa si sta per costruire, e come.
var _scelto: String = ""
var _rotazione: int = 0
## Di quanti gradini si è scostata a mano la quota del pezzo che si ha in mano.
var _alzata: int = 0
## La costruzione presa su per spostarla, e da dove viene: { modello, ancora,
## rotazione, livello }. Vuoto quando non si ha niente in mano. Serve a
## rimetterla dov'era se ci si ripensa, che è l'unica cosa che uno spostamento
## deve garantire.
var _in_mano: Dictionary = {}
var _cella := CELLA_NULLA
var _ancora := CELLA_NULLA
var _esito: Dictionary = {}
var _fantasma: Node3D = null

## id del piazzamento -> { nodo, livello }. La griglia sa chi occupa cosa; qui
## sta quello che serve per disfare: il nodo da buttare e la quota a cui sta.
var _costruzioni: Dictionary = {}

var _attrezzo: Attrezzo = Attrezzo.ALZA
## La quota a cui livellare, presa col primo clic. -1 = ancora da scegliere.
var _quota_riferimento: int = -1

## Quanta corrente e quanta acqua prende tutto quello che è stato posato, x e y.
## Quanta ne arriva non sta qui: dipende da quali impianti funzionano, e la si
## chiede a _prodotto() quando serve. Non si salva niente di questo: è la somma
## di quello che c'è in città, e si rifà da sola al caricamento.
var _consumato := Vector2i.ZERO
## Il servizio acceso sul mondo, o "" se non ce n'è nessuno.
var _servizio_acceso: String = ""
## id del piazzamento -> il punto esclamativo che gli sta sopra. Ci sta solo chi
## ha qualcosa che non va, quindi è anche l'elenco di chi è in difetto.
var _segnali_per_id: Dictionary = {}
var _velo: StandardMaterial3D

var _messaggio_corrente: String = ""
var _materiale_valido: StandardMaterial3D
var _materiale_invalido: StandardMaterial3D


func _ready() -> void:
	# Un CanvasLayer non eredita la visibilità dal Node3D che lo contiene:
	# senza questo, il negozio resterebbe stampato sopra la schermata di focus
	# quando si cambia modalità.
	visibility_changed.connect(_aggiorna_interfaccia)
	_aggiorna_interfaccia()

	_sole.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	_materiale_valido = _materiale_fantasma(COLORE_VALIDO)
	_materiale_invalido = _materiale_fantasma(COLORE_INVALIDO)
	_velo = _materiale_velo()

	catalogo = CityCatalog.new()
	griglia = CityGrid.new(SaveManager.world_size())
	terreno = CityTerrain.new(griglia.size, SaveManager.world_seed())

	_barra.voce_scelta.connect(_on_voce_scelta)
	_barra.strumento_scelto.connect(_on_strumento_scelto)
	_conti.servizio_scelto.connect(_on_servizio_scelto)
	SaveManager.credits_changed.connect(_on_crediti_cambiati)
	_barra.mostra_catalogo(catalogo)
	_barra.aggiorna_saldo(SaveManager.credits)

	var costruiti := _ricostruisci_dal_salvataggio()
	_costruisci_mesh()
	_mostra_i_servizi()
	_aggiorna_i_conti()

	var centro_griglia := Vector2i(griglia.size.x / 2, griglia.size.y / 2)
	var centro := griglia.centro_cella(centro_griglia)
	centro.y = terreno.quota(centro_griglia)
	_camera.inquadra(centro)

	if costruiti == 0:
		_messaggio("Mondo %d · %s · la città è tutta da fare." % [terreno.seme, _riepilogo_biomi()])
	else:
		_messaggio("Mondo %d · %d costruzioni." % [terreno.seme, costruiti])


func _process(_delta: float) -> void:
	if _modo == Modo.NAVIGA:
		return
	# Col cursore sopra il negozio il raggio andrebbe comunque a colpire il
	# terreno dietro il pannello, e l'anteprima ballerebbe mentre si sceglie.
	var puntata := CELLA_NULLA if _mouse_sul_pannello() else _cella_puntata()
	if puntata != _cella:
		_cella = puntata
		_aggiorna_bersaglio()


func _unhandled_input(evento: InputEvent) -> void:
	# Il negozio si apre e si chiude sempre, anche a mani vuote: è il modo di
	# entrare in cantiere, non una cosa che si fa mentre già ci si sta dentro.
	if evento is InputEventKey and _tasto_del_negozio(evento as InputEventKey):
		get_viewport().set_input_as_handled()
		return

	# Un punto esclamativo si clicca in qualunque modo si sia, e vince sul
	# piazzamento: chi lo tocca sta chiedendo cosa non va, non sta costruendo.
	if evento is InputEventMouseButton:
		var tocco := evento as InputEventMouseButton
		if tocco.pressed and tocco.button_index == MOUSE_BUTTON_LEFT \
				and not _mouse_sul_pannello() and _segnale_sotto(tocco.position):
			_conti.apri()
			_aggiorna_i_conti()
			get_viewport().set_input_as_handled()
			return

	if _modo == Modo.NAVIGA:
		return

	if evento is InputEventKey:
		var tasto := evento as InputEventKey
		if not tasto.pressed or tasto.echo:
			return
		match tasto.physical_keycode:
			KEY_R:
				# Q ed E girano la vista: il pezzo gira con un tasto suo.
				_ruota_il_pezzo(-1 if tasto.shift_pressed else 1)
				get_viewport().set_input_as_handled()
			KEY_PAGEUP, KEY_KP_ADD:
				_alza_il_pezzo(1)
				get_viewport().set_input_as_handled()
			KEY_PAGEDOWN, KEY_KP_SUBTRACT:
				_alza_il_pezzo(-1)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				# Un passo indietro per volta: chi ha qualcosa in mano la rimette
				# dov'era e resta a spostare, e solo il secondo Esc esce.
				if _rimetti_dov_era():
					_messaggio("Rimessa dov'era.")
					_aggiorna_bersaglio()
				else:
					_torna_a_navigare()
				get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			_conferma()
			get_viewport().set_input_as_handled()


func _aggiorna_interfaccia() -> void:
	_interfaccia.visible = is_visible_in_tree()


## B apre e chiude la fascia delle costruzioni, C i conti della città; l'Esc
## chiude quello che è aperto, ma solo quando non c'è niente in mano da posare —
## in cantiere l'Esc lascia prima l'attrezzo, e solo al giro dopo tocca ai
## pannelli. Restituisce se il tasto era per noi.
func _tasto_del_negozio(tasto: InputEventKey) -> bool:
	if not tasto.pressed or tasto.echo:
		return false
	match tasto.physical_keycode:
		KEY_B:
			_barra.alterna()
			return true
		KEY_C:
			_conti.alterna()
			if _conti.aperto():
				_aggiorna_i_conti()
			return true
		KEY_ESCAPE:
			if _modo != Modo.NAVIGA:
				return false
			if _conti.aperto():
				_conti.chiudi()
				return true
			if _barra.aperta():
				_barra.chiudi()
				return true
	return false


# --- Costruzione del mondo --------------------------------------------------

func _costruisci_mesh() -> void:
	_terreno_mesh.mesh = TerrainMesh.costruisci_terreno(terreno)
	_acqua_mesh.mesh = TerrainMesh.costruisci_acqua(terreno)
	_reticolo.mesh = TerrainMesh.costruisci_reticolo(terreno)
	# La collisione del terreno serve solo al raggio del mouse: senza, non c'è
	# modo di sapere quale cella si sta indicando.
	_forma_terreno.shape = _terreno_mesh.mesh.create_trimesh_shape()


## Rimette in piedi la città salvata. Restituisce quante costruzioni ha ripreso.
##
## Prima il terreno, poi quello che ci sta sopra: gli spianamenti sopravvivono
## alle demolizioni, quindi ce ne possono essere anche dove non c'è più niente.
## La mesh si ricostruisce una volta sola, alla fine.
func _ricostruisci_dal_salvataggio() -> int:
	_riapplica_le_quote_salvate()
	var ripresi := 0
	for tile in SaveManager.world_tiles():
		var pos: Array = tile.get("pos", [])
		if pos.size() != 2:
			continue
		var id := str(tile.get("type", ""))
		if not catalogo.esiste(id):
			push_warning("CityView: nel salvataggio c'è %s, che il catalogo non conosce." % id)
			continue
		var ancora := Vector2i(int(pos[0]), int(pos[1]))
		var rotazione := int(tile.get("rotation", 0))
		var footprint: Vector2i = catalogo.voce(id)["footprint"]
		var celle := griglia.celle_occupate(ancora, footprint, rotazione)
		var livello := int(tile.get("level", terreno.livello_piu_basso(celle)))
		if _costruisci(id, ancora, rotazione, livello, false):
			ripresi += 1
	return ripresi


## Rimette le quote scelte dal giocatore, spianamenti e scavi insieme.
##
## Non passa da spiana(), che è una regola di piazzamento e non scende mai sotto
## il livello del mare: una conca scavata apposta deve poter restare una conca.
## Biomi e acque si rifanno una volta sola, alla fine.
func _riapplica_le_quote_salvate() -> void:
	var quante := 0
	for modifica in SaveManager.world_terrain_edits():
		var pos: Array = modifica.get("pos", [])
		if pos.size() != 2 or not modifica.has("level"):
			continue
		terreno.imposta_livello(Vector2i(int(pos[0]), int(pos[1])), int(modifica["level"]))
		quante += 1
	if quante > 0:
		terreno.riclassifica()


## Scrive nel salvataggio le celle che un piazzamento ha spianato davvero: solo
## quelle che si scostano dal terreno del seme, così una casa 1x1 su terreno
## piatto non lascia traccia.
func _segna_le_quote_del_lotto(celle: Array[Vector2i]) -> void:
	for cella in celle:
		_registra_quota(cella)


## Nel salvataggio ci va solo quello che si scosta dal seme: riportare una cella
## alla quota di partenza la toglie dall'elenco, invece di lasciarci una riga
## che dice "come prima".
func _registra_quota(cella: Vector2i) -> void:
	var livello := terreno.livello(cella)
	if livello == terreno.livello_naturale(cella):
		SaveManager.clear_terrain_edit(cella)
	else:
		SaveManager.set_terrain_edit(cella, livello)


## Mette un oggetto sulla griglia e nel mondo. Non tocca né i crediti né il
## salvataggio: quelli li gestisce chi chiama, perché ricaricare una città già
## pagata non deve farla ripagare.
func _costruisci(id: String, ancora: Vector2i, rotazione: int, livello: int,
		rifai_la_mesh: bool = true) -> bool:
	var voce := catalogo.voce(id)
	if voce.is_empty():
		push_error("CityView: id assente dal catalogo: %s" % id)
		return false

	var footprint: Vector2i = voce["footprint"]
	if not griglia.libero(ancora, footprint, rotazione):
		push_warning("CityView: %s non entra in %s." % [id, ancora])
		return false

	var celle := griglia.celle_occupate(ancora, footprint, rotazione)
	if voce["regola"] == CityCatalog.Regola.TERRA and _serve_livellare(celle, livello):
		terreno.spiana(celle, livello)
		if rifai_la_mesh:
			_costruisci_mesh()

	var nodo := _istanzia(voce, ancora, rotazione, livello)
	if nodo == null:
		return false
	var id_piazzamento := griglia.piazza(ancora, footprint, rotazione, id)
	_costruzioni[id_piazzamento] = { "nodo": nodo, "livello": livello }
	_conta_i_servizi(voce, 1)
	return true


func _istanzia(voce: Dictionary, ancora: Vector2i, rotazione: int, livello: int) -> Node3D:
	var scena := load(CityCatalog.CARTELLA_MODELLI + str(voce["modello"])) as PackedScene
	if scena == null:
		push_error("CityView: modello mancante per %s" % voce["id"])
		return null

	var nodo: Node3D = scena.instantiate()
	nodo.position = griglia.posizione_mondo(ancora, voce["footprint"], rotazione)
	nodo.position.y = float(livello) * CityTerrain.PASSO_QUOTA
	nodo.rotation.y = deg_to_rad(-90.0 * rotazione)
	_spegni_collisioni(nodo)
	if voce["regola"] == CityCatalog.Regola.PONTE:
		_appoggia_la_campata(nodo, ancora, livello)
	_edifici.add_child(nodo)
	return nodo


## Infila la pila sotto una campata. Non è un piazzamento: non occupa la cella,
## non si compra e non finisce nel salvataggio, vive appesa al ponte che regge.
func _appoggia_la_campata(campata: Node3D, ancora: Vector2i, livello: int) -> void:
	var luce := float(livello) * CityTerrain.PASSO_QUOTA - terreno.quota(ancora)
	var id_pila := catalogo.sostegno_per_luce(luce)
	if id_pila.is_empty():
		return
	var scena := load(CityCatalog.CARTELLA_MODELLI + str(catalogo.voce(id_pila)["modello"])) as PackedScene
	if scena == null:
		return
	var pila: Node3D = scena.instantiate()
	pila.position = Vector3(0.0, -luce, 0.0)
	_spegni_collisioni(pila)
	campata.add_child(pila)


# --- Servizi ----------------------------------------------------------------

## Mette o toglie dal conto dei consumi quello che una costruzione prende.
##
## Prende anche quando non è servita: una casa al buio la corrente la vuole
## lo stesso, ed è quello che la tiene al buio. Toglierle il consumo perché è
## scoperta libererebbe la corrente che la accenderebbe, che la farebbe
## consumare di nuovo, che la rispegnerebbe — una domanda senza risposta
## stabile. Quello che si spegne di una costruzione in difetto è quello che dà,
## non quello che chiede.
func _conta_i_servizi(voce: Dictionary, verso: int) -> void:
	if voce.is_empty():
		return
	var servizi: Vector2i = voce["servizi"]
	_consumato += Vector2i(maxi(-servizi.x, 0), maxi(-servizi.y, 0)) * verso


## Quanta corrente e quanta acqua mettono in comune gli impianti che funzionano.
##
## Un impianto senza strada non produce niente: sta lì, l'hai pagato, ma non
## entra in funzione — che è esattamente quello che dice il punto esclamativo
## che ha sopra. Non è un totale che si aggiorna mentre si costruisce ma una
## somma che si rifà quando serve: basta demolire una strada tre celle più in là
## per cambiarla, e un numero tenuto a mano si sarebbe scollato dal mondo alla
## prima distrazione.
func _prodotto() -> Vector2i:
	var totale := Vector2i.ZERO
	for piazzamento in griglia.piazzamenti():
		var servizi := catalogo.servizi(str(piazzamento["modello"]))
		if servizi.x <= 0 and servizi.y <= 0:
			continue
		var celle := griglia.celle_occupate(
			piazzamento["ancora"], piazzamento["footprint"], piazzamento["rotazione"]
		)
		if not _tocca_una_strada(celle):
			continue
		totale += Vector2i(maxi(servizi.x, 0), maxi(servizi.y, 0))
	return totale


## Quanta corrente e quanta acqua la città ha in tutto: quella degli impianti che
## funzionano, più l'allacciamento di partenza se qualcuno gliene ha dato uno.
## Senza impianti è zero, ed è giusto così: non c'è niente che possa servire
## nessuno.
func _servizi_disponibili() -> Vector2i:
	return Config.service_base() + _prodotto()


## Se almeno una cella di un ingombro confina con una strada.
##
## Adiacenza e non raggiungibilità: chiedere che quella strada sia collegata a
## tutto il resto vorrebbe dire visitare il grafo stradale a ogni movimento del
## mouse, e soprattutto che tagliarne una in mezzo scollegherebbe mezza città in
## un colpo. Confinare basta a impedire la casa in mezzo al niente, che è la
## cosa che si voleva impedire.
func _tocca_una_strada(celle: Array[Vector2i]) -> bool:
	for cella in celle:
		for direzione in CityTerrain.VICINI:
			var vicina: Vector2i = cella + direzione
			if celle.has(vicina) or not griglia.in_griglia(vicina):
				continue
			var occupante := griglia.occupante(vicina)
			if not occupante.is_empty() and catalogo.e_strada(str(occupante["modello"])):
				return true
	return false


## Chi chiede un servizio e chi non ce l'ha. Restituisce
## { chiedono, scoperte, mancanti, scoperti }: `scoperti` sono gli id dei
## piazzamenti in difetto, `mancanti` le loro celle da accendere
## sul mondo. Solo quelle: le costruzioni a posto sono la maggioranza, e
## colorarle tutte di verde vorrebbe dire nascondere le tre che contano dentro
## una città intera dipinta.
func _copertura(servizio: String) -> Dictionary:
	var esito := {
		"chiedono": 0, "scoperte": 0,
		"mancanti": [] as Array[Vector2i], "scoperti": [] as Array[int],
	}
	var asse := 0 if servizio == "corrente" else 1
	var resta := 0
	if servizio != "strada":
		resta = _servizi_disponibili()[asse]

	# In ordine di posa: gli id crescono, e ordinarli è ordinare la storia della
	# città.
	var elenco := griglia.piazzamenti()
	elenco.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))

	for piazzamento in elenco:
		var modello := str(piazzamento["modello"])
		var voce := catalogo.voce(modello)
		if voce.is_empty():
			continue
		var celle := griglia.celle_occupate(
			piazzamento["ancora"], piazzamento["footprint"], piazzamento["rotazione"]
		)
		var chiede := false
		var servita := false
		if servizio == "strada":
			chiede = catalogo.vuole_la_strada(modello)
			servita = chiede and _tocca_una_strada(celle)
		else:
			var quanto: int = -(voce["servizi"] as Vector2i)[asse]
			chiede = quanto > 0
			if chiede:
				# Quando non basta per tutti, la rete serve prima quello che
				# c'era già: si stacca da dove il conto sfonda. Arbitrario come
				# ogni altra regola, ma stabile — riaprendo la partita restano
				# al buio le stesse case — ed è quella che ci si aspetta, visto
				# che è l'ultima cosa costruita ad aver fatto saltare il conto.
				servita = quanto <= resta
				if servita:
					resta -= quanto
		if not chiede:
			continue
		esito["chiedono"] = int(esito["chiedono"]) + 1
		if servita:
			continue
		esito["scoperte"] = int(esito["scoperte"]) + 1
		(esito["scoperti"] as Array[int]).append(int(piazzamento["id"]))
		var mancanti: Array[Vector2i] = esito["mancanti"]
		for cella in celle:
			mancanti.append(cella)
	return esito


## Rifà i numeri del pannello e, se un servizio è acceso, il colore sul mondo.
func _aggiorna_i_conti() -> void:
	var righe: Array[Dictionary] = []
	var in_difetto := {}
	for servizio in SERVIZI:
		var conto := _copertura(str(servizio["id"]))
		for id_piazzamento in conto["scoperti"]:
			in_difetto[id_piazzamento] = true
		righe.append({
			"id": servizio["id"], "nome": servizio["nome"],
			"chiedono": conto["chiedono"], "scoperte": conto["scoperte"],
		})
	_segna_chi_e_in_difetto(in_difetto)
	_conti.mostra(righe, "%d costruzioni in città · %s." % [
		griglia.piazzamenti().size(), _riepilogo_servizi()
	])
	if not _servizio_acceso.is_empty():
		_dipingi_il_servizio(_servizio_acceso)


## Mette il velo scuro e il punto esclamativo sopra chi ha qualcosa che non va,
## e li toglie a chi non ce l'ha più.
##
## Il velo è un `material_overlay`: disegna sopra il modello e lascia sotto
## quello che c'era, quindi la casa resta la sua casa, solo in ombra, e per
## rimetterla a posto basta togliere il velo — non c'è nessun materiale
## originale da ricordarsi.
func _segna_chi_e_in_difetto(in_difetto: Dictionary) -> void:
	for segnale in _segnali.get_children():
		_segnali.remove_child(segnale)
		segnale.queue_free()
	_segnali_per_id.clear()

	for piazzamento in griglia.piazzamenti():
		var id_piazzamento := int(piazzamento["id"])
		var costruzione: Dictionary = _costruzioni.get(id_piazzamento, {})
		if not costruzione.has("nodo"):
			continue
		var scoperta: bool = in_difetto.has(id_piazzamento)
		_stendi_il_velo(costruzione["nodo"], _velo if scoperta else null)
		if scoperta:
			_segnali_per_id[id_piazzamento] = _crea_segnale(piazzamento, int(costruzione["livello"]))


static func _stendi_il_velo(nodo: Node, materiale: Material) -> void:
	if nodo is GeometryInstance3D:
		(nodo as GeometryInstance3D).material_overlay = materiale
	for figlio in nodo.get_children():
		_stendi_il_velo(figlio, materiale)


## Il punto esclamativo che galleggia sopra una costruzione in difetto.
##
## Sta sempre rivolto alla camera e sempre della stessa misura sullo schermo:
## è un cartello, non un oggetto della città, e deve restare leggibile sia con
## la vista girata sia da lontano. Passa davanti a tutto (`no_depth_test`)
## perché un avviso nascosto dietro il tetto che avvisa non avvisa nessuno.
func _crea_segnale(piazzamento: Dictionary, livello: int) -> Label3D:
	var voce := catalogo.voce(str(piazzamento["modello"]))
	var segnale := Label3D.new()
	segnale.text = "!"
	segnale.font_size = 128
	segnale.outline_size = 34
	segnale.modulate = COLORE_SEGNALE
	segnale.outline_modulate = Color(0.05, 0.03, 0.06, 0.95)
	segnale.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	segnale.no_depth_test = true
	segnale.fixed_size = true
	segnale.pixel_size = 0.0006
	segnale.render_priority = 2
	segnale.outline_render_priority = 1
	segnale.position = griglia.posizione_mondo(
		piazzamento["ancora"], piazzamento["footprint"], piazzamento["rotazione"]
	)
	segnale.position.y = float(livello) * CityTerrain.PASSO_QUOTA \
		+ float(voce.get("altezza", 1.0)) + 0.8
	_segnali.add_child(segnale)
	return segnale


## Se un clic ha preso un punto esclamativo.
##
## Non passa dalla fisica: i segnali sono cartelli piatti sempre rivolti alla
## camera, e chiedere dove finiscono sullo schermo costa meno che dare a
## ciascuno un corpo da colpire — e non rischia di rubare il raggio al terreno,
## che è l'unica cosa che il mouse deve poter puntare.
func _segnale_sotto(punto: Vector2) -> bool:
	for id_piazzamento in _segnali_per_id:
		var segnale: Label3D = _segnali_per_id[id_piazzamento]
		if not is_instance_valid(segnale) or _camera.dietro(segnale.global_position):
			continue
		if punto.distance_to(_camera.punto_schermo(segnale.global_position)) <= RAGGIO_SEGNALE:
			return true
	return false


func _on_servizio_scelto(servizio: String) -> void:
	_servizio_acceso = servizio
	if servizio.is_empty():
		_evidenza.mesh = null
		return
	Sfx.suona("clic")
	_dipingi_il_servizio(servizio)


## Accende sul mondo chi chiede un servizio e non ce l'ha. Ogni cella alla sua
## quota, perché le costruzioni non stanno tutte allo stesso piano e un colore a
## quota unica finirebbe sottoterra o per aria.
func _dipingi_il_servizio(servizio: String) -> void:
	var conto := _copertura(servizio)
	_evidenza.mesh = TerrainMesh.costruisci_gruppi([{
		"celle": conto["mancanti"], "colore": COLORE_SCOPERTO,
		"quote": _quote_di(conto["mancanti"]),
	}])


func _quote_di(celle: Array[Vector2i]) -> PackedFloat32Array:
	var quote := PackedFloat32Array()
	for cella in celle:
		quote.append(terreno.quota(cella) + 0.03)
	return quote


func _mostra_i_servizi() -> void:
	_barra.aggiorna_servizi(_consumato, _servizi_disponibili())


func _serve_livellare(celle: Array[Vector2i], livello: int) -> bool:
	for cella in celle:
		if terreno.livello(cella) != livello:
			return true
	return false


## I modelli portano con sé le collisioni "-colonly" della pipeline. Qui non
## servono a niente e ruberebbero il raggio al terreno, quindi si spengono.
static func _spegni_collisioni(nodo: Node) -> void:
	if nodo is CollisionObject3D:
		var corpo := nodo as CollisionObject3D
		corpo.collision_layer = 0
		corpo.collision_mask = 0
	for figlio in nodo.get_children():
		_spegni_collisioni(figlio)


# --- Scelta del posto -------------------------------------------------------

## La cella sotto il cursore, o CELLA_NULLA se il raggio esce dal mondo.
func _cella_puntata() -> Vector2i:
	var punto_schermo := get_viewport().get_mouse_position()
	var origine := _camera.origine_raggio(punto_schermo)
	var query := PhysicsRayQueryParameters3D.create(
		origine, origine + _camera.direzione_raggio(punto_schermo) * 1000.0
	)
	query.collision_mask = LAYER_TERRENO
	var colpo := get_world_3d().direct_space_state.intersect_ray(query)
	if colpo.is_empty():
		return CELLA_NULLA
	var cella: Vector2i = griglia.cella_da_mondo(colpo["position"])
	return cella if griglia.in_griglia(cella) else CELLA_NULLA


## L'oggetto si centra sul cursore invece di crescergli a destra: puntando il
## posto dove si vuole una torre 4x4, la si vuole lì, non lì accanto.
func _ancora_da(cella: Vector2i, footprint: Vector2i, rotazione: int) -> Vector2i:
	var f := CityGrid.footprint_ruotato(footprint, rotazione)
	return cella - Vector2i((f.x - 1) / 2, (f.y - 1) / 2)


## Se e dove si può posare quello che si è scelto, e a che quota finirebbe.
## Restituisce { valido, celle, livello, motivo }.
##
## `alzata` è lo scostamento chiesto a mano, in gradini, e vale solo per ponti e
## rampe: gli unici che non spianano il lotto sono anche gli unici che possono
## stare a una quota diversa da quella del terreno che hanno sotto.
func _valuta(id: String, ancora: Vector2i, rotazione: int, alzata: int = 0) -> Dictionary:
	var voce := catalogo.voce(id)
	if voce.is_empty():
		return { "valido": false, "celle": [] as Array[Vector2i], "livello": 0,
			"motivo": "Oggetto sconosciuto: %s." % id }
	var celle := griglia.celle_occupate(ancora, voce["footprint"], rotazione)
	var esito := {
		"valido": false,
		"celle": celle,
		"livello": terreno.livello(ancora),
		"motivo": "",
	}

	for cella in celle:
		if not griglia.in_griglia(cella):
			esito["motivo"] = "Fuori dal mondo."
			return esito
	for cella in celle:
		if not griglia.occupante(cella).is_empty():
			esito["motivo"] = "Qui c'è già qualcosa."
			return esito

	if catalogo.vuole_la_strada(id) and not _tocca_una_strada(celle):
		esito["motivo"] = "Ci vuole una strada attaccata: qui non ci arriva nessuno."
		return esito

	# Ponti e rampe non hanno regole di terreno: dove la cella è libera si posano,
	# e a girarli come si vuole ci pensa R. L'unica cosa che resta da decidere è
	# la quota, che la si prende da quello che hanno intorno.
	match voce["regola"]:
		CityCatalog.Regola.PONTE:
			esito["livello"] = _con_alzata(_livello_impalcato(celle), alzata)

		CityCatalog.Regola.RAMPA:
			esito["livello"] = _con_alzata(_livello_rampa(celle, int(voce["salita"])), alzata)

		_:
			for cella in celle:
				if not terreno.costruibile(cella):
					esito["motivo"] = "Sull'acqua non si costruisce."
					return esito
			esito["livello"] = terreno.livello_piu_basso(celle)

	esito["valido"] = true
	return esito


## La quota dedotta più lo scostamento chiesto a mano, tenuta dentro il mondo.
## Zero è il fondo, e sopra il tetto del terreno non si va: più in su non ci
## sarebbe più niente a cui appoggiarsi, nemmeno in teoria.
static func _con_alzata(livello: int, alzata: int) -> int:
	return clampi(livello + alzata, 0, CityTerrain.LIVELLO_MASSIMO)


## Quanto è alto quello che una campata scavalca: il terreno dove è asciutto, il
## pelo dell'acqua dove non lo è. Un impalcato non deve finire né dentro la
## collina su cui lo si posa né sotto il fiume che attraversa.
func _livello_scavalcato(celle: Array[Vector2i]) -> int:
	var massimo := 0
	for cella in celle:
		if not griglia.in_griglia(cella):
			continue
		var q := CityTerrain.LIVELLO_MARE if terreno.e_acqua(cella) else terreno.livello(cella)
		massimo = maxi(massimo, q)
	return massimo


## A che quota va una campata: un gradino sopra la riva a cui si aggancia.
##
## È la composizione che la pipeline ha già verificato in Blender, in
## tools/blender/render_transport_demo.py: l'impalcato sta 0,5 m sopra il piano
## stradale della sponda, e la rampa colma esattamente quel dislivello. Una
## campata attaccata a un'altra campata ne eredita la quota, altrimenti un fiume
## largo non si attraverserebbe mai restando in piano.
##
## Senza né sponde né campate accanto — un ponte in mezzo al mare, un cavalcavia
## in cima a una collina — la campata non viene rifiutata: resta comunque un
## gradino sopra quello che scavalca.
func _livello_impalcato(celle: Array[Vector2i]) -> int:
	var da_campata := -1
	var da_riva := -1
	for cella in celle:
		for direzione in CityTerrain.VICINI:
			var vicina: Vector2i = cella + direzione
			if celle.has(vicina) or not griglia.in_griglia(vicina):
				continue
			var occupante := griglia.occupante(vicina)
			var e_campata: bool = not occupante.is_empty() \
				and catalogo.regola(str(occupante["modello"])) == CityCatalog.Regola.PONTE
			if e_campata:
				da_campata = maxi(da_campata, int(_costruzioni[occupante["id"]]["livello"]))
			elif terreno.costruibile(vicina):
				var candidato := terreno.livello(vicina) + 1
				da_riva = candidato if da_riva < 0 else mini(da_riva, candidato)
	var agganciato := da_campata if da_campata >= 0 else da_riva
	return maxi(agganciato, _livello_scavalcato(celle) + 1)


## A che quota si posa una rampa: sul terreno che ha sotto, la più bassa fra le
## celle che occupa. Sull'acqua di terreno da calpestare non ce n'è, e allora il
## piede va un gradino sotto l'impalcato che le sta accanto: è lì che la rampa
## deve arrivare.
func _livello_rampa(celle: Array[Vector2i], salita: int) -> int:
	var asciutto := -1
	for cella in celle:
		if not terreno.costruibile(cella):
			continue
		var q := terreno.livello(cella)
		asciutto = q if asciutto < 0 else mini(asciutto, q)
	if asciutto >= 0:
		return asciutto
	return maxi(_livello_impalcato(celle) - salita, 0)


# --- Modalità ---------------------------------------------------------------

func _on_voce_scelta(id: String) -> void:
	Sfx.suona("clic")
	_rimetti_dov_era()
	_modo = Modo.PIAZZA
	_scelto = id
	_rotazione = 0
	_alzata = 0
	_crea_fantasma()
	_cella = CELLA_NULLA
	_messaggio("")


func _on_strumento_scelto(strumento: String) -> void:
	Sfx.suona("clic")
	_rimetti_dov_era()
	if strumento.is_empty():
		_torna_a_navigare()
		return
	_scelto = ""
	_alzata = 0
	_libera_fantasma()
	_cella = CELLA_NULLA
	_quota_riferimento = -1
	match strumento:
		"sposta":
			_modo = Modo.SPOSTA
		"demolisci":
			_modo = Modo.DEMOLISCI
		"alza":
			_modo = Modo.TERRENO
			_attrezzo = Attrezzo.ALZA
		"abbassa":
			_modo = Modo.TERRENO
			_attrezzo = Attrezzo.ABBASSA
		"livella":
			_modo = Modo.TERRENO
			_attrezzo = Attrezzo.LIVELLA
	_messaggio("Prendi una quota col primo clic." if _attrezzo == Attrezzo.LIVELLA and _modo == Modo.TERRENO else "")


func _on_crediti_cambiati(crediti: int) -> void:
	_barra.aggiorna_saldo(crediti)


func _torna_a_navigare() -> void:
	_rimetti_dov_era()
	_modo = Modo.NAVIGA
	_scelto = ""
	_alzata = 0
	_quota_riferimento = -1
	_cella = CELLA_NULLA
	_esito = {}
	_libera_fantasma()
	_selezione.mesh = null
	_barra.deseleziona()
	_aggiorna_aiuto()


func _ruota_il_pezzo(verso: int) -> void:
	_rotazione = posmod(_rotazione + verso, 4)
	if _fantasma != null:
		_fantasma.rotation.y = deg_to_rad(-90.0 * _rotazione)
	_aggiorna_bersaglio()


## Sposta di un gradino la quota a cui il pezzo si poserebbe.
##
## La quota che il gioco deduce da solo — la sponda, l'impalcato accanto, il
## terreno sotto — è quella giusta quasi sempre, ma è un suggerimento e non un
## vincolo: una rampa o una campata si mettono anche dove non le aspetta
## nessuno. Chi spiana il lotto invece no, la sua quota è il lotto stesso.
func _alza_il_pezzo(gradini: int) -> void:
	if _scelto.is_empty() or catalogo.regola(_scelto) == CityCatalog.Regola.TERRA:
		return
	_alzata = clampi(_alzata + gradini, -CityTerrain.LIVELLO_MASSIMO, CityTerrain.LIVELLO_MASSIMO)
	Sfx.suona("clic")
	_aggiorna_bersaglio()
	if _cella == CELLA_NULLA:
		return
	var metri := float(_esito.get("livello", 0)) * CityTerrain.PASSO_QUOTA
	if _alzata == 0:
		_messaggio("Quota %.1f m, come la trova." % metri)
	else:
		_messaggio("Quota %.1f m (%+d gradini a mano)." % [metri, _alzata])


func _conferma() -> void:
	if _cella == CELLA_NULLA:
		return
	if _modo == Modo.SPOSTA and _in_mano.is_empty():
		_prendi_in_mano()
		return
	if _modo == Modo.DEMOLISCI:
		_demolisci_sotto_il_cursore()
		return
	if _modo == Modo.TERRENO:
		_modella_sotto_il_cursore()
		return

	if not bool(_esito.get("valido", false)):
		Sfx.suona("errore")
		_messaggio(str(_esito.get("motivo", "")))
		return

	# Quello che si ha in mano è già stato pagato quando lo si è comprato:
	# spostarlo non si ripaga, altrimenti nessuno cambierebbe mai idea.
	if not _in_mano.is_empty():
		_riposa_quello_in_mano()
		return

	var prezzo := catalogo.prezzo(_scelto)
	if not SaveManager.try_spend(prezzo):
		Sfx.suona("errore")
		_messaggio("Servono %d crediti, ne hai %d. Torna a fare focus." % [prezzo, SaveManager.credits])
		return

	var livello := int(_esito["livello"])
	if not _costruisci(_scelto, _ancora, _rotazione, livello):
		# Non è stato costruito niente: i crediti non si tengono.
		SaveManager.add_credits(prezzo)
		SaveManager.save_game()
		Sfx.suona("errore")
		_messaggio("Non si riesce a costruire qui.")
		return

	if catalogo.regola(_scelto) == CityCatalog.Regola.TERRA:
		_segna_le_quote_del_lotto(_esito["celle"])
	SaveManager.add_tile(_ancora, _scelto, _rotazione, livello)
	Sfx.suona("posa")
	_mostra_i_servizi()
	_aggiorna_i_conti()
	# Il bilancio si dice solo a chi lo ha appena mosso: dopo un albero sarebbe
	# rumore, dopo una palazzina è la cosa che si vuole sapere.
	_messaggio("%s: -%d crediti.%s" % [
		catalogo.voce(_scelto)["nome"], prezzo, _coda_dei_servizi(_scelto)
	])
	_aggiorna_bersaglio()


# --- Spostare ---------------------------------------------------------------

## Stacca una costruzione dalla città e la mette in mano al cursore.
##
## Sparisce davvero dalla griglia e dal bilancio dei servizi: finché sta in mano
## non c'è, e il posto che occupava è libero — che è quello che serve per poterla
## rimettere dov'era spostata di una cella.
##
## Dal salvataggio invece no, non ancora: ne esce solo quando si è posata da
## qualche altra parte. Così chiudere l'app con qualcosa in mano non la fa
## sparire, la lascia dov'era, che è l'unica risposta accettabile a una domanda
## che nessuno ha fatto. Quello che era stato spianato per lei resta spianato,
## come dopo una demolizione: sbancare è una modifica al mondo, non un pezzo
## dell'edificio.
func _prendi_in_mano() -> void:
	var occupante := griglia.occupante(_cella)
	if occupante.is_empty():
		Sfx.suona("errore")
		_messaggio("Qui non c'è niente da spostare.")
		return

	var id_piazzamento := int(occupante["id"])
	var costruzione: Dictionary = _costruzioni.get(id_piazzamento, {})
	var modello := str(occupante["modello"])
	_in_mano = {
		"modello": modello,
		"ancora": occupante["ancora"],
		"rotazione": int(occupante["rotazione"]),
		"livello": int(costruzione.get("livello", 0)),
	}

	if costruzione.has("nodo"):
		(costruzione["nodo"] as Node3D).queue_free()
	_costruzioni.erase(id_piazzamento)
	griglia.rimuovi(_cella)
	_conta_i_servizi(catalogo.voce(modello), -1)
	_mostra_i_servizi()
	_aggiorna_i_conti()

	_scelto = modello
	_rotazione = int(_in_mano["rotazione"])
	_alzata = 0
	_crea_fantasma()
	if _fantasma != null:
		_fantasma.rotation.y = deg_to_rad(-90.0 * _rotazione)

	Sfx.suona("clic")
	_messaggio("%s in mano: clic per riposarla, R la gira, Esc la rimette dov'era." % [
		catalogo.voce(modello)["nome"]
	])
	_aggiorna_bersaglio()


## Riposa dove punta il cursore quello che si ha in mano.
func _riposa_quello_in_mano() -> void:
	var livello := int(_esito["livello"])
	if not _costruisci(_scelto, _ancora, _rotazione, livello):
		Sfx.suona("errore")
		_messaggio("Non si riesce a posarla qui.")
		return
	if catalogo.regola(_scelto) == CityCatalog.Regola.TERRA:
		_segna_le_quote_del_lotto(_esito["celle"])
	# Adesso sì: esce dalla vecchia casella del salvataggio ed entra nella nuova.
	SaveManager.remove_tile(_in_mano["ancora"])
	SaveManager.add_tile(_ancora, _scelto, _rotazione, livello)
	SaveManager.save_game()

	var nome: String = catalogo.voce(_scelto)["nome"]
	_in_mano = {}
	_scelto = ""
	_alzata = 0
	_libera_fantasma()
	_mostra_i_servizi()
	_aggiorna_i_conti()
	Sfx.suona("posa")
	_messaggio("%s spostata. Spostare non costa niente." % nome)
	_aggiorna_bersaglio()


## Rimette dov'era quello che si ha in mano, e restituisce se c'era qualcosa.
##
## La chiama l'Esc, e la chiama anche chi cambia strumento o esce dalla città:
## una costruzione non deve poter sparire perché si è cliccato altrove.
func _rimetti_dov_era() -> bool:
	if _in_mano.is_empty():
		return false
	var modello := str(_in_mano["modello"])
	var ancora: Vector2i = _in_mano["ancora"]
	var rotazione := int(_in_mano["rotazione"])
	var livello := int(_in_mano["livello"])
	_in_mano = {}
	# Nel salvataggio non ha mai smesso di esserci: qui si rimette solo in piedi.
	if not _costruisci(modello, ancora, rotazione, livello):
		push_error("CityView: %s non è tornata al suo posto in %s." % [modello, ancora])
	_scelto = ""
	_alzata = 0
	_libera_fantasma()
	_mostra_i_servizi()
	_aggiorna_i_conti()
	return true


func _demolisci_sotto_il_cursore() -> void:
	var occupante := griglia.occupante(_cella)
	if occupante.is_empty():
		Sfx.suona("errore")
		_messaggio("Qui non c'è niente da demolire.")
		return

	var id_modello := str(occupante["modello"])
	var ancora: Vector2i = occupante["ancora"]
	var id_piazzamento := int(occupante["id"])
	var rimborso := catalogo.rimborso(id_modello)

	var costruzione: Dictionary = _costruzioni.get(id_piazzamento, {})
	if costruzione.has("nodo"):
		(costruzione["nodo"] as Node3D).queue_free()
	_costruzioni.erase(id_piazzamento)
	griglia.rimuovi(_cella)
	_conta_i_servizi(catalogo.voce(id_modello), -1)
	_mostra_i_servizi()
	_aggiorna_i_conti()

	# Il lotto resta spianato: sbancare è una modifica al mondo, non un pezzo
	# dell'edificio, e il terreno non deve rimbalzare su e giù ogni volta che si
	# cambia idea su cosa costruirci. Il salvataggio se ne ricorda per conto suo
	# (terrain_edits), quindi resta spianato anche riaprendo la partita.
	SaveManager.remove_tile(ancora)
	SaveManager.add_credits(rimborso)
	SaveManager.save_game()

	Sfx.suona("demolisci")
	_messaggio("%s demolita: +%d crediti. Il lotto resta spianato." % [
		catalogo.voce(id_modello)["nome"], rimborso
	])
	_aggiorna_bersaglio()


# --- Terreno ----------------------------------------------------------------

## Dove porterebbe la cella l'attrezzo in mano.
func _quota_bersaglio(attuale: int) -> int:
	match _attrezzo:
		Attrezzo.ALZA:
			return attuale + 1
		Attrezzo.ABBASSA:
			return attuale - 1
		_:
			return _quota_riferimento


## Se e come si può modellare una cella. Restituisce { valido, livello, costo,
## motivo }.
func _valuta_terreno(cella: Vector2i) -> Dictionary:
	var attuale := terreno.livello(cella)
	var nuovo := _quota_bersaglio(attuale)
	var esito := { "valido": false, "livello": nuovo, "costo": 0, "motivo": "" }

	if nuovo < 0:
		esito["motivo"] = "Prendi prima una quota da qualche parte."
		return esito
	if nuovo == attuale:
		esito["motivo"] = "Il terreno è già a questa quota."
		return esito
	if nuovo > CityTerrain.LIVELLO_MASSIMO:
		esito["motivo"] = "Più in alto di così il terreno non va."
		return esito
	# Il terreno sotto una costruzione non si tocca, e vale anche per una
	# campata: spostare il fondale sotto un ponte lo lascerebbe appeso.
	if not griglia.occupante(cella).is_empty():
		esito["motivo"] = "Sotto una costruzione il terreno non si tocca: demolisci prima."
		return esito
	if not terreno.dislivello_accettabile(cella, nuovo):
		esito["motivo"] = "Con una cella vicina il salto passerebbe i %d gradini." % CityTerrain.DISLIVELLO_MASSIMO
		return esito

	esito["costo"] = absi(nuovo - attuale) * Config.terrain_cost_per_level
	if not SaveManager.can_afford(esito["costo"]):
		esito["motivo"] = "Costa %d crediti, ne hai %d." % [esito["costo"], SaveManager.credits]
		return esito

	esito["valido"] = true
	return esito


func _modella_sotto_il_cursore() -> void:
	# Il primo clic del livellatore non muove niente: prende la quota da copiare.
	if _attrezzo == Attrezzo.LIVELLA and _quota_riferimento < 0:
		_quota_riferimento = terreno.livello(_cella)
		Sfx.suona("clic")
		_messaggio("Quota presa: %.1f m. Ora clicca dove portarla." % [
			float(_quota_riferimento) * CityTerrain.PASSO_QUOTA
		])
		_aggiorna_bersaglio()
		return

	var esito := _valuta_terreno(_cella)
	if not bool(esito["valido"]):
		Sfx.suona("errore")
		_messaggio(str(esito["motivo"]))
		return

	var costo := int(esito["costo"])
	if costo > 0 and not SaveManager.try_spend(costo):
		Sfx.suona("errore")
		_messaggio("Servono %d crediti, ne hai %d." % [costo, SaveManager.credits])
		return

	terreno.imposta_livello(_cella, int(esito["livello"]))
	terreno.riclassifica()
	_costruisci_mesh()
	_registra_quota(_cella)
	SaveManager.save_game()

	Sfx.suona("terreno")
	_messaggio("Terreno a %.1f m: -%d crediti." % [
		float(esito["livello"]) * CityTerrain.PASSO_QUOTA, costo
	])
	_aggiorna_bersaglio()


# --- Anteprima --------------------------------------------------------------

func _aggiorna_bersaglio() -> void:
	if _cella == CELLA_NULLA:
		_selezione.mesh = null
		if _fantasma != null:
			_fantasma.visible = false
		_aggiorna_aiuto()
		return

	match _modo:
		Modo.DEMOLISCI:
			_mostra_bersaglio(COLORE_DEMOLIZIONE)
		Modo.SPOSTA when _in_mano.is_empty():
			_mostra_bersaglio(COLORE_SPOSTAMENTO)
		Modo.TERRENO:
			_mostra_bersaglio_terreno()
		_:
			_mostra_bersaglio_piazzamento()
	_aggiorna_aiuto()


func _mostra_bersaglio_piazzamento() -> void:
	var voce := catalogo.voce(_scelto)
	# A mani vuote non c'è niente da mostrare. Oggi non ci si arriva — chi non ha
	# scelto niente non è in modalità di piazzamento — ma è la specie di cosa che
	# smette di essere vera al primo modo nuovo, e il prezzo di questa riga è
	# molto meno di quello di scoprirlo con un errore in mezzo alla città.
	if voce.is_empty():
		_selezione.mesh = null
		if _fantasma != null:
			_fantasma.visible = false
		return
	_ancora = _ancora_da(_cella, voce["footprint"], _rotazione)
	_esito = _valuta(_scelto, _ancora, _rotazione, _alzata)

	var valido: bool = _esito["valido"]
	var quota := float(_esito["livello"]) * CityTerrain.PASSO_QUOTA

	if _fantasma != null:
		_fantasma.visible = true
		_fantasma.position = griglia.posizione_mondo(_ancora, voce["footprint"], _rotazione)
		_fantasma.position.y = quota
		_tinge(_fantasma, _materiale_valido if valido else _materiale_invalido)

	_selezione.mesh = TerrainMesh.costruisci_selezione(
		_esito["celle"], quota + 0.02, COLORE_VALIDO if valido else COLORE_INVALIDO
	)


## Il riquadro sulla costruzione sotto il cursore: la stessa domanda — quale di
## queste — la fanno il demolitore e lo spostamento, e cambia solo il colore.
func _mostra_bersaglio(colore: Color) -> void:
	var occupante := griglia.occupante(_cella)
	if occupante.is_empty():
		var sola: Array[Vector2i] = [_cella]
		_selezione.mesh = TerrainMesh.costruisci_selezione(
			sola, terreno.quota(_cella) + 0.02, COLORE_INVALIDO
		)
		return
	var celle := griglia.celle_occupate(
		occupante["ancora"], occupante["footprint"], occupante["rotazione"]
	)
	var quota := float(_costruzioni[occupante["id"]]["livello"]) * CityTerrain.PASSO_QUOTA
	_selezione.mesh = TerrainMesh.costruisci_selezione(celle, quota + 0.02, colore)


## Il riquadro sta alla quota di arrivo, non a quella di adesso: si vede dove
## finirà il terreno prima di spendere.
func _mostra_bersaglio_terreno() -> void:
	var esito := _valuta_terreno(_cella)
	var quota := float(esito["livello"]) * CityTerrain.PASSO_QUOTA
	if int(esito["livello"]) < 0:
		quota = terreno.quota(_cella)
	var sola: Array[Vector2i] = [_cella]
	_selezione.mesh = TerrainMesh.costruisci_selezione(
		sola, quota + 0.02, COLORE_VALIDO if bool(esito["valido"]) else COLORE_INVALIDO
	)


func _crea_fantasma() -> void:
	_libera_fantasma()
	var voce := catalogo.voce(_scelto)
	var scena := load(CityCatalog.CARTELLA_MODELLI + str(voce["modello"])) as PackedScene
	if scena == null:
		return
	_fantasma = scena.instantiate()
	_fantasma.visible = false
	_spegni_collisioni(_fantasma)
	_anteprima.add_child(_fantasma)


func _libera_fantasma() -> void:
	if _fantasma != null:
		_fantasma.queue_free()
		_fantasma = null


## Il velo che si stende sopra una costruzione a cui manca qualcosa.
##
## Non e' il materiale del fantasma: quello sostituisce i colori del modello per
## dire "qui ci starebbe", questo ci si posa sopra per dire "questa non
## funziona", e sotto deve restare riconoscibile la casa che e'. Senza luce di
## proposito, altrimenti il sole lo schiarirebbe proprio dove batte, cioe' dove
## si guarda.
static func _materiale_velo() -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = VELO_SCOPERTO
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.grow = true
	materiale.grow_amount = 0.02
	materiale.render_priority = 1
	return materiale


static func _materiale_fantasma(colore: Color) -> StandardMaterial3D:
	var materiale := StandardMaterial3D.new()
	materiale.albedo_color = colore
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.cull_mode = BaseMaterial3D.CULL_DISABLED
	return materiale


## L'anteprima si vede attraverso: colorarla di verde o di rosso dice se il
## posto va bene senza doverlo leggere da nessuna parte.
static func _tinge(nodo: Node, materiale: Material) -> void:
	if nodo is MeshInstance3D:
		(nodo as MeshInstance3D).material_override = materiale
	for figlio in nodo.get_children():
		_tinge(figlio, materiale)


func _mouse_sul_pannello() -> bool:
	return _barra.sotto_il_mouse() or _conti.sotto_il_mouse()


# --- Testi ------------------------------------------------------------------

func _messaggio(testo: String) -> void:
	_messaggio_corrente = testo
	_aggiorna_aiuto()


## Due righe e non una: il suggerimento e' sempre lo stesso e sta in fondo, il
## messaggio cambia e sta sopra. Su una riga sola il riepilogo di un mondo
## appena nato arrivava a toccare tutti e due i bordi dello schermo.
func _aggiorna_aiuto() -> void:
	_aiuto.text = _suggerimento()
	_messaggio_label.text = _messaggio_corrente


func _suggerimento() -> String:
	match _modo:
		Modo.PIAZZA:
			if not _scelto.is_empty() and catalogo.regola(_scelto) != CityCatalog.Regola.TERRA:
				return "Clic per posare · R ruota · PagSu / PagGiù alza e abbassa · Esc annulla"
			return "Clic per posare · R ruota (Shift+R al contrario) · Esc annulla"
		Modo.SPOSTA:
			if _in_mano.is_empty():
				return "Clic su una costruzione per prenderla in mano · Esc annulla"
			return "Clic per riposarla · R gira · PagSu / PagGiù cambia quota · Esc la rimette dov'era"
		Modo.DEMOLISCI:
			return "Clic su una costruzione per demolirla · Esc annulla"
		Modo.TERRENO:
			if _attrezzo == Attrezzo.LIVELLA and _quota_riferimento < 0:
				return "Clic per prendere la quota da copiare · Esc annulla"
			return "Clic per modellare il terreno · Esc annulla"
		_:
			return "WASD scorre (Shift corre) · Q / E ruota · rotella zoom · B costruisci · C conti"


func _riepilogo_servizi() -> String:
	var disponibili := _servizi_disponibili()
	return "corrente %d/%d, acqua %d/%d" % [
		_consumato.x, disponibili.x, _consumato.y, disponibili.y
	]


## Quello che si aggiunge al messaggio dopo aver posato qualcosa.
##
## Chi non tocca i servizi non se ne merita una parola: dopo un albero il
## bilancio sarebbe rumore. Chi li tocca ne merita una sola, e se è appena
## rimasto al buio quella parola dev'essere questa e non un rapporto di due
## frazioni — è l'ultimo arrivato, quindi è lui quello scoperto.
func _coda_dei_servizi(id: String) -> String:
	var servizi := catalogo.servizi(id)
	if servizi == Vector2i.ZERO:
		return ""
	var avanzo := _servizi_disponibili() - _consumato
	var al_buio := PackedStringArray()
	if servizi.x < 0 and avanzo.x < 0:
		al_buio.append("corrente")
	if servizi.y < 0 and avanzo.y < 0:
		al_buio.append("acqua")
	if al_buio.is_empty():
		return " · " + _riepilogo_servizi()
	return " Ma resta senza %s: guarda i conti con C." % " e senza ".join(al_buio)


func _riepilogo_biomi() -> String:
	var conteggio := {}
	for i in terreno.biomi.size():
		var b: int = terreno.biomi[i]
		conteggio[b] = int(conteggio.get(b, 0)) + 1
	var nomi := ["mare", "lago", "fiume", "spiaggia", "pianura", "collina"]
	var pezzi: Array[String] = []
	for b in range(nomi.size()):
		if conteggio.has(b):
			pezzi.append("%s %d" % [nomi[b], conteggio[b]])
	return " · ".join(pezzi)
