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

const CARTELLA_MODELLI := "res://assets/models/generated/"

## Le coordinate di griglia non sono mai negative, quindi questa vale "nessuna".
const CELLA_NULLA := Vector2i(-1, -1)

## Il terreno è l'unica cosa che il raggio del mouse deve colpire. Gli edifici
## restano fuori da ogni layer: puntando una casa si vuole la cella su cui
## poggia, non la sua grondaia.
const LAYER_TERRENO := 1

const COLORE_VALIDO := Color(0.36, 0.84, 0.47, 0.55)
const COLORE_INVALIDO := Color(0.90, 0.31, 0.26, 0.50)
const COLORE_DEMOLIZIONE := Color(0.95, 0.47, 0.20, 0.45)

enum Modo { NAVIGA, PIAZZA, DEMOLISCI, TERRENO }

## Gli attrezzi della modalità terreno.
enum Attrezzo { ALZA, ABBASSA, LIVELLA }

@onready var _terreno_mesh: MeshInstance3D = $Terreno
@onready var _forma_terreno: CollisionShape3D = $Terreno/Corpo/Forma
@onready var _acqua_mesh: MeshInstance3D = $Acqua
@onready var _reticolo: MeshInstance3D = $Griglia
@onready var _selezione: MeshInstance3D = $Selezione
@onready var _edifici: Node3D = $Edifici
@onready var _anteprima: Node3D = $Anteprima
@onready var _camera: IsoCamera = $Camera
@onready var _sole: DirectionalLight3D = $Sole
@onready var _interfaccia: CanvasLayer = $Interfaccia
@onready var _negozio: ShopPanel = %Negozio
@onready var _aiuto: Label = %Aiuto
@onready var _messaggio_label: Label = %Messaggio

var griglia: CityGrid
var terreno: CityTerrain
var catalogo: CityCatalog

var _modo: Modo = Modo.NAVIGA
## Cosa si sta per costruire, e come.
var _scelto: String = ""
var _rotazione: int = 0
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

	catalogo = CityCatalog.new()
	griglia = CityGrid.new(SaveManager.world_size())
	terreno = CityTerrain.new(griglia.size, SaveManager.world_seed())

	_negozio.voce_scelta.connect(_on_voce_scelta)
	_negozio.strumento_scelto.connect(_on_strumento_scelto)
	SaveManager.credits_changed.connect(_on_crediti_cambiati)
	_negozio.mostra_catalogo(catalogo)
	_negozio.aggiorna_saldo(SaveManager.credits)

	var costruiti := _ricostruisci_dal_salvataggio()
	_costruisci_mesh()

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
			KEY_ESCAPE:
				_torna_a_navigare()
				get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		if clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
			_conferma()
			get_viewport().set_input_as_handled()


func _aggiorna_interfaccia() -> void:
	_interfaccia.visible = is_visible_in_tree()


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
	return true


func _istanzia(voce: Dictionary, ancora: Vector2i, rotazione: int, livello: int) -> Node3D:
	var scena := load(CARTELLA_MODELLI + str(voce["modello"])) as PackedScene
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
	var scena := load(CARTELLA_MODELLI + str(catalogo.voce(id_pila)["modello"])) as PackedScene
	if scena == null:
		return
	var pila: Node3D = scena.instantiate()
	pila.position = Vector3(0.0, -luce, 0.0)
	_spegni_collisioni(pila)
	campata.add_child(pila)


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
func _valuta(id: String, ancora: Vector2i, rotazione: int) -> Dictionary:
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

	match voce["regola"]:
		CityCatalog.Regola.PONTE:
			for cella in celle:
				if not terreno.e_acqua(cella):
					esito["motivo"] = "Una campata va sull'acqua: a terra ci vuole una strada."
					return esito
			var livello := _livello_impalcato(celle)
			if livello < 0:
				esito["motivo"] = "Un ponte parte da una riva o da un'altra campata."
				return esito
			esito["livello"] = livello

		CityCatalog.Regola.RAMPA:
			for cella in celle:
				if not terreno.costruibile(cella):
					esito["motivo"] = "Una rampa si posa all'asciutto."
					return esito
			var piede := terreno.livello(celle[0])
			for cella in celle:
				if terreno.livello(cella) != piede:
					esito["motivo"] = "Il piede della rampa vuole il terreno in piano."
					return esito
			var passo := CityCatalog.ruota_passo(voce["passo_alto"], rotazione)
			var quota_alta := _quota_oltre(celle, passo)
			if quota_alta < 0:
				esito["motivo"] = "Di là non c'è niente a cui salire: girala con R."
				return esito
			var salita := int(voce["salita"])
			if quota_alta != piede + salita:
				esito["motivo"] = "Una rampa sale di un gradino solo: qui il salto è di %d." % (quota_alta - piede)
				return esito
			esito["livello"] = piede

		_:
			for cella in celle:
				if not terreno.costruibile(cella):
					esito["motivo"] = "Sull'acqua non si costruisce."
					return esito
			esito["livello"] = terreno.livello_piu_basso(celle)

	esito["valido"] = true
	return esito


## A che quota si cammina su una cella: l'impalcato se c'è un ponte, il terreno
## se è asciutto. -1 se lì c'è acqua libera o si esce dalla mappa.
func _quota_calpestabile(cella: Vector2i) -> int:
	if not griglia.in_griglia(cella):
		return -1
	var occupante := griglia.occupante(cella)
	if not occupante.is_empty() and catalogo.regola(str(occupante["modello"])) == CityCatalog.Regola.PONTE:
		return int(_costruzioni[occupante["id"]]["livello"])
	if terreno.costruibile(cella):
		return terreno.livello(cella)
	return -1


## La quota di quello che sta appena oltre il lato alto della rampa. Può essere
## terreno o l'impalcato di un ponte: le rampe da ponte servono proprio a quello.
## -1 se di là non c'è niente su cui salire, o se il bordo alto affaccia su due
## quote diverse.
func _quota_oltre(celle: Array[Vector2i], passo: Vector2i) -> int:
	if passo == Vector2i.ZERO:
		return -1
	var estremo := -0x7FFFFFFF
	for cella in celle:
		estremo = maxi(estremo, cella.x * passo.x + cella.y * passo.y)
	var quota := -1
	for cella in celle:
		if cella.x * passo.x + cella.y * passo.y != estremo:
			continue
		var q := _quota_calpestabile(cella + passo)
		if q < 0 or (quota >= 0 and q != quota):
			return -1
		quota = q
	return quota


## A che quota va una campata: un gradino sopra la riva a cui si aggancia.
##
## È la composizione che la pipeline ha già verificato in Blender, in
## tools/blender/render_transport_demo.py: l'impalcato sta 0,5 m sopra il piano
## stradale della sponda, e la rampa colma esattamente quel dislivello. Una
## campata attaccata a un'altra campata ne eredita la quota, altrimenti un fiume
## largo non si attraverserebbe mai restando in piano.
##
## Restituisce -1 se non c'è niente a cui agganciarsi: un ponte in mezzo al mare
## che non parte da nessuna parte non è un ponte.
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
	return da_campata if da_campata >= 0 else da_riva


# --- Modalità ---------------------------------------------------------------

func _on_voce_scelta(id: String) -> void:
	Sfx.suona("clic")
	_modo = Modo.PIAZZA
	_scelto = id
	_rotazione = 0
	_crea_fantasma()
	_cella = CELLA_NULLA
	_messaggio("")


func _on_strumento_scelto(strumento: String) -> void:
	Sfx.suona("clic")
	if strumento.is_empty():
		_torna_a_navigare()
		return
	_scelto = ""
	_libera_fantasma()
	_cella = CELLA_NULLA
	_quota_riferimento = -1
	match strumento:
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
	_negozio.aggiorna_saldo(crediti)


func _torna_a_navigare() -> void:
	_modo = Modo.NAVIGA
	_scelto = ""
	_quota_riferimento = -1
	_cella = CELLA_NULLA
	_esito = {}
	_libera_fantasma()
	_selezione.mesh = null
	_negozio.deseleziona()
	_aggiorna_aiuto()


func _ruota_il_pezzo(verso: int) -> void:
	_rotazione = posmod(_rotazione + verso, 4)
	if _fantasma != null:
		_fantasma.rotation.y = deg_to_rad(-90.0 * _rotazione)
	_aggiorna_bersaglio()


func _conferma() -> void:
	if _cella == CELLA_NULLA:
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
	_messaggio("%s: -%d crediti." % [catalogo.voce(_scelto)["nome"], prezzo])
	_aggiorna_bersaglio()


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
	var impegnato := _terreno_impegnato(cella)
	if not impegnato.is_empty():
		esito["motivo"] = impegnato
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


## Se una costruzione vicina ha bisogno di questa cella cosi' com'e'.
##
## Proteggere la cella sotto un edificio non basta: ponti e rampe si agganciano
## a quello che hanno accanto, e la loro quota viene decisa al piazzamento e poi
## non si muove piu'. Alzare la sponda di un metro lascerebbe la campata a
## mezz'aria, e la rampa che ci saliva punterebbe in mezzo al nulla — tutto
## senza un messaggio, perche' il terreno da solo non sa cosa regge.
##
## Restituisce il motivo del rifiuto, oppure "" se la cella e' libera di
## muoversi.
func _terreno_impegnato(cella: Vector2i) -> String:
	for direzione in CityTerrain.VICINI:
		var vicina: Vector2i = cella + direzione
		if not griglia.in_griglia(vicina):
			continue
		var occupante := griglia.occupante(vicina)
		if occupante.is_empty():
			continue
		match catalogo.regola(str(occupante["modello"])):
			CityCatalog.Regola.PONTE:
				# La sponda di una campata sta esattamente un gradino sotto
				# l'impalcato: se questa cella e' li', e' quella che lo regge.
				var id_piazzamento := int(occupante["id"])
				if not _costruzioni.has(id_piazzamento):
					continue
				var impalcato := int(_costruzioni[id_piazzamento]["livello"])
				if terreno.costruibile(cella) and terreno.livello(cella) == impalcato - 1:
					return "Di qui una campata prende la sponda: demolisci il ponte prima."
			CityCatalog.Regola.RAMPA:
				if _rampa_sale_verso(occupante, cella):
					return "Una rampa sale proprio qui: demoliscila prima."
			_:
				continue
	return ""


## Se il lato alto di quella rampa affaccia proprio su questa cella.
##
## Stesso conto che fa _quota_oltre quando la rampa viene posata, guardato
## dall'altra parte: li' si cerca la quota di la', qui si chiede se il "di la'"
## e' questa cella.
func _rampa_sale_verso(occupante: Dictionary, cella: Vector2i) -> bool:
	var voce := catalogo.voce(str(occupante["modello"]))
	if voce.is_empty():
		return false
	var rotazione := int(occupante["rotazione"])
	var passo := CityCatalog.ruota_passo(voce["passo_alto"], rotazione)
	if passo == Vector2i.ZERO:
		return false
	var celle := griglia.celle_occupate(occupante["ancora"], voce["footprint"], rotazione)
	var estremo := -0x7FFFFFFF
	for c in celle:
		estremo = maxi(estremo, c.x * passo.x + c.y * passo.y)
	for c in celle:
		if c.x * passo.x + c.y * passo.y == estremo and c + passo == cella:
			return true
	return false


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
			_mostra_bersaglio_demolizione()
		Modo.TERRENO:
			_mostra_bersaglio_terreno()
		_:
			_mostra_bersaglio_piazzamento()
	_aggiorna_aiuto()


func _mostra_bersaglio_piazzamento() -> void:
	var voce := catalogo.voce(_scelto)
	_ancora = _ancora_da(_cella, voce["footprint"], _rotazione)
	_esito = _valuta(_scelto, _ancora, _rotazione)

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


func _mostra_bersaglio_demolizione() -> void:
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
	_selezione.mesh = TerrainMesh.costruisci_selezione(celle, quota + 0.02, COLORE_DEMOLIZIONE)


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
	var scena := load(CARTELLA_MODELLI + str(voce["modello"])) as PackedScene
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
	return _negozio.get_global_rect().has_point(get_viewport().get_mouse_position())


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
			return "Clic per posare · R ruota (Shift+R al contrario) · Esc annulla"
		Modo.DEMOLISCI:
			return "Clic su una costruzione per demolirla · Esc annulla"
		Modo.TERRENO:
			if _attrezzo == Attrezzo.LIVELLA and _quota_riferimento < 0:
				return "Clic per prendere la quota da copiare · Esc annulla"
			return "Clic per modellare il terreno · Esc annulla"
		_:
			return "Q / E ruota la vista · trascina col tasto destro · rotella per lo zoom"


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
