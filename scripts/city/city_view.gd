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
## Il mondo della città: terreno procedurale, griglia, camera e banco di prova.
##
## Il terreno si rigenera dal seme salvato: non finisce su disco nemmeno una
## quota. Su disco vanno solo il seme e le celle che l'utente ha costruito.

const CATALOGO := "res://assets/models/generated/catalog.json"
const CARTELLA_MODELLI := "res://assets/models/generated/"

## Il quartiere di prova ha bisogno di terreno piano: questo rettangolo viene
## livellato prima di costruire la mesh. La Fase 4 farà lo stesso, un lotto
## alla volta, quando l'utente piazza qualcosa.
const LOTTO_DI_PROVA := Rect2i(8, 11, 16, 13)

@onready var _terreno_mesh: MeshInstance3D = $Terreno
@onready var _acqua_mesh: MeshInstance3D = $Acqua
@onready var _reticolo: MeshInstance3D = $Griglia
@onready var _edifici: Node3D = $Edifici
@onready var _camera: IsoCamera = $Camera
@onready var _sole: DirectionalLight3D = $Sole
@onready var _interfaccia: CanvasLayer = $Interfaccia
@onready var _aiuto: Label = %Aiuto

var griglia: CityGrid
var terreno: CityTerrain
var _voci: Dictionary = {}


func _ready() -> void:
	# Un CanvasLayer non eredita la visibilità dal Node3D che lo contiene:
	# senza questo, l'aiuto della città resterebbe stampato sopra la
	# schermata di focus quando si cambia modalità.
	visibility_changed.connect(_aggiorna_interfaccia)
	_aggiorna_interfaccia()

	_sole.rotation_degrees = Vector3(-52.0, -125.0, 0.0)

	var mondo: Dictionary = SaveManager.data.get("world", {})
	var dimensione: Array = mondo.get("size", [32, 32])
	var seme := int(mondo.get("seed", 0))
	griglia = CityGrid.new(Vector2i(int(dimensione[0]), int(dimensione[1])))
	terreno = CityTerrain.new(griglia.size, seme)

	_carica_catalogo()
	var quota_lotto := terreno.spiana(_celle_del_lotto(LOTTO_DI_PROVA))
	_costruisci_mesh()
	var piazzati := _costruisci_banco_di_prova()

	var centro := griglia.centro_cella(Vector2i(16, 17))
	centro.y = float(quota_lotto) * CityTerrain.PASSO_QUOTA
	_camera.inquadra(centro)
	_aiuto.text = "Q / E ruota · trascina col tasto destro · rotella per lo zoom      seme %d · %d oggetti · %s" % [
		seme, piazzati, _riepilogo_biomi()
	]


func _aggiorna_interfaccia() -> void:
	_interfaccia.visible = is_visible_in_tree()


# --- Costruzione del mondo --------------------------------------------------

func _carica_catalogo() -> void:
	var testo := FileAccess.get_file_as_string(CATALOGO)
	var dati: Variant = JSON.parse_string(testo)
	if typeof(dati) != TYPE_DICTIONARY or not (dati as Dictionary).has("assets"):
		push_error("CityView: catalogo illeggibile in %s" % CATALOGO)
		return
	for voce in (dati as Dictionary)["assets"]:
		_voci[str(voce["id"])] = voce


func _costruisci_mesh() -> void:
	_terreno_mesh.mesh = TerrainMesh.costruisci_terreno(terreno)
	_acqua_mesh.mesh = TerrainMesh.costruisci_acqua(terreno)
	_reticolo.mesh = TerrainMesh.costruisci_reticolo(terreno)


func _celle_del_lotto(rettangolo: Rect2i) -> Array[Vector2i]:
	var celle: Array[Vector2i] = []
	for dz in rettangolo.size.y:
		for dx in rettangolo.size.x:
			celle.append(Vector2i(rettangolo.position.x + dx, rettangolo.position.y + dz))
	return celle


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


# --- Banco di prova ---------------------------------------------------------

## Piazza un pezzo di quartiere con tutte le taglie di footprint del catalogo.
##
## Non è contenuto di gioco: serve a verificare che la convenzione della
## pipeline (cella 2 x 2 m, origine al centro della base) regga dentro Godot,
## che gli ingombri multi-cella non si sovrappongano e che gli edifici appoggino
## alla quota giusta. La Fase 4 lo sostituirà con quello che l'utente costruisce.
func _costruisci_banco_di_prova() -> int:
	var piazzati := 0

	# Strada principale che taglia il quartiere.
	for x in range(8, 24):
		piazzati += _piazza("ROAD_LOCAL_1x1_STRAIGHT", Vector2i(x, 16))

	# A nord: dal footprint più piccolo al più grande, tutti allineati alla strada.
	piazzati += _piazza("RES_LOW_1x1_001", Vector2i(8, 14))
	piazzati += _piazza("RES_LOW_1x1_003", Vector2i(9, 14))
	piazzati += _piazza("RES_LOW_2x1_007", Vector2i(10, 14))
	piazzati += _piazza("RES_LOW_1x2_006", Vector2i(12, 13))
	piazzati += _piazza("RES_MID_2x2_001", Vector2i(13, 13))
	piazzati += _piazza("RES_TOWER_3x3_001", Vector2i(15, 12))
	piazzati += _piazza("RES_TOWER_4x4_003", Vector2i(18, 11))
	piazzati += _piazza("NAT_TREE_OAK_1x1_001", Vector2i(22, 14))
	piazzati += _piazza("NAT_TREE_PINE_1x1_001", Vector2i(23, 14))

	# A sud: servizi e industria.
	piazzati += _piazza("PARK_2x2_001", Vector2i(8, 17))
	piazzati += _piazza("EDU_SCHOOL_3x3_001", Vector2i(11, 17))
	piazzati += _piazza("COM_LOW_1x1_001", Vector2i(15, 17))
	piazzati += _piazza("COM_MID_2x2_005", Vector2i(16, 17))
	piazzati += _piazza("IND_MID_3x3_003", Vector2i(19, 17))
	piazzati += _piazza("UTIL_WIND_2x2_001", Vector2i(22, 17))

	# Vetrina dei moduli stradali, per controllare che gli spigoli combacino.
	var moduli := ["STRAIGHT", "CORNER", "T", "CROSS", "END"]
	for i in moduli.size():
		piazzati += _piazza("ROAD_LOCAL_1x1_%s" % moduli[i], Vector2i(8 + i * 2, 21))
		piazzati += _piazza("ROAD_DIRT_1x1_%s" % moduli[i], Vector2i(8 + i * 2, 23))

	return piazzati


## Mette un modello sulla griglia. Restituisce 1 se ce l'ha fatta, 0 altrimenti.
func _piazza(id: String, cella: Vector2i, rotazione: int = 0) -> int:
	if not _voci.has(id):
		push_error("CityView: id assente dal catalogo: %s" % id)
		return 0

	var voce: Dictionary = _voci[id]
	var f: Array = voce["footprint"]
	var footprint := Vector2i(int(f[0]), int(f[1]))
	var celle := griglia.celle_occupate(cella, footprint, rotazione)

	if not terreno.lotto_piano(celle):
		push_error("CityView: %s in %s finisce in acqua o a cavallo di un dislivello" % [id, cella])
		return 0
	if griglia.piazza(cella, footprint, rotazione, id) == 0:
		push_error("CityView: %s non entra in %s (fuori griglia o celle occupate)" % [id, cella])
		return 0

	var scena: Resource = load(CARTELLA_MODELLI + str(voce["model"]))
	if scena == null or not scena is PackedScene:
		push_error("CityView: modello mancante per %s" % id)
		return 0

	var nodo: Node3D = (scena as PackedScene).instantiate()
	nodo.position = griglia.posizione_mondo(cella, footprint, rotazione)
	nodo.position.y = terreno.quota(cella)
	nodo.rotation.y = deg_to_rad(-90.0 * rotazione)
	_edifici.add_child(nodo)
	return 1
