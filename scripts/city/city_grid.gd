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

class_name CityGrid
extends RefCounted
## La griglia della città: converte coordinate e tiene il conto di chi occupa cosa.
##
## Non si usa GridMap di proposito. GridMap vuole una MeshLibrary e ragiona per
## celle 1x1, mentre il catalogo arriva a footprint 4x4: gli ingombri multi-cella
## e la rotazione andrebbero reimplementati sopra di lui comunque.
##
## Convenzione ereditata dalla pipeline Blender: una cella è 2 x 2 m e l'origine
## di ogni modello sta al centro della sua base. La cella (0, 0) ha il centro
## nell'origine del mondo, quindi il centro della cella (x, z) sta a
## (x * 2, 0, z * 2). Le coordinate di griglia sono Vector2i(x, z): la y di
## Vector2i è la profondità del mondo, non l'altezza.

const CELL_SIZE := 2.0

var size: Vector2i

## Vector2i -> id del piazzamento che occupa quella cella.
var _occupanti: Dictionary = {}
## id -> { ancora, footprint, rotazione, modello }
var _piazzamenti: Dictionary = {}
var _prossimo_id: int = 1


func _init(dimensione: Vector2i = Vector2i(32, 32)) -> void:
	size = dimensione


## Ruotando di 90° o 270° larghezza e profondità si scambiano.
static func footprint_ruotato(footprint: Vector2i, rotazione: int) -> Vector2i:
	if posmod(rotazione, 2) == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint


func in_griglia(cella: Vector2i) -> bool:
	return cella.x >= 0 and cella.y >= 0 and cella.x < size.x and cella.y < size.y


## Le celle che un oggetto occuperebbe, ancorato con l'angolo a coordinate minori.
func celle_occupate(ancora: Vector2i, footprint: Vector2i, rotazione: int) -> Array[Vector2i]:
	var f := footprint_ruotato(footprint, rotazione)
	var celle: Array[Vector2i] = []
	for dx in f.x:
		for dz in f.y:
			celle.append(ancora + Vector2i(dx, dz))
	return celle


func libero(ancora: Vector2i, footprint: Vector2i, rotazione: int) -> bool:
	for cella in celle_occupate(ancora, footprint, rotazione):
		if not in_griglia(cella) or _occupanti.has(cella):
			return false
	return true


## Occupa le celle. Restituisce l'id del piazzamento, oppure 0 se non ci sta.
func piazza(ancora: Vector2i, footprint: Vector2i, rotazione: int, modello: String) -> int:
	if not libero(ancora, footprint, rotazione):
		return 0
	var id := _prossimo_id
	_prossimo_id += 1
	_piazzamenti[id] = {
		"ancora": ancora,
		"footprint": footprint,
		"rotazione": posmod(rotazione, 4),
		"modello": modello,
	}
	for cella in celle_occupate(ancora, footprint, rotazione):
		_occupanti[cella] = id
	return id


## Rimuove l'intero oggetto che tocca quella cella, non solo la cella.
func rimuovi(cella: Vector2i) -> bool:
	if not _occupanti.has(cella):
		return false
	var id: int = _occupanti[cella]
	var p: Dictionary = _piazzamenti[id]
	for c in celle_occupate(p["ancora"], p["footprint"], p["rotazione"]):
		_occupanti.erase(c)
	_piazzamenti.erase(id)
	return true


## Dati del piazzamento che occupa la cella, oppure {} se è libera.
func occupante(cella: Vector2i) -> Dictionary:
	if not _occupanti.has(cella):
		return {}
	return _piazzamenti[_occupanti[cella]]


func piazzamenti() -> Array:
	return _piazzamenti.values()


## Dove va messo il nodo: centro della base dell'oggetto, y a zero.
func posizione_mondo(ancora: Vector2i, footprint: Vector2i, rotazione: int) -> Vector3:
	var f := footprint_ruotato(footprint, rotazione)
	return Vector3(
		(float(ancora.x) + float(f.x - 1) * 0.5) * CELL_SIZE,
		0.0,
		(float(ancora.y) + float(f.y - 1) * 0.5) * CELL_SIZE
	)


func centro_cella(cella: Vector2i) -> Vector3:
	return Vector3(float(cella.x) * CELL_SIZE, 0.0, float(cella.y) * CELL_SIZE)


func cella_da_mondo(punto: Vector3) -> Vector2i:
	return Vector2i(roundi(punto.x / CELL_SIZE), roundi(punto.z / CELL_SIZE))


## Centro geometrico della griglia, comodo per puntarci la camera.
func centro_mondo() -> Vector3:
	return Vector3(
		float(size.x - 1) * 0.5 * CELL_SIZE,
		0.0,
		float(size.y - 1) * 0.5 * CELL_SIZE
	)
