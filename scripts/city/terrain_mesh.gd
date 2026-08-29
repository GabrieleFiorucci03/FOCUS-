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

class_name TerrainMesh
extends RefCounted
## Trasforma i dati di CityTerrain in mesh. Solo presentazione: qui non si
## decide niente sul mondo, si disegna quello che il generatore ha deciso.
##
## Il colore del bioma viaggia nei vertici invece che in un materiale per tipo:
## tutto il terreno diventa così una sola superficie e un solo draw call, e
## aggiungere un bioma non aggiunge un materiale.

## Godot considera fronte le facce con avvolgimento orario.
const AVVOLGIMENTO_ORARIO := true

const COLORI := {
	CityTerrain.Bioma.MARE: Color(0.220, 0.298, 0.353),
	CityTerrain.Bioma.LAGO: Color(0.243, 0.333, 0.353),
	CityTerrain.Bioma.FIUME: Color(0.416, 0.404, 0.353),
	CityTerrain.Bioma.SPIAGGIA: Color(0.816, 0.741, 0.545),
	CityTerrain.Bioma.PIANURA: Color(0.353, 0.510, 0.271),
	CityTerrain.Bioma.COLLINA: Color(0.259, 0.396, 0.220),
}

## Terra battuta esposta sul fianco dei gradini.
const COLORE_SCARPATA := Color(0.443, 0.376, 0.286)
const COLORE_ACQUA := Color(0.153, 0.435, 0.549, 0.88)

## Quanto il colore di una cella può scostarsi, per non avere campiture piatte.
const VARIAZIONE := 0.05

# I colori qui sopra sono scritti in sRGB, come si leggono da un color picker,
# ma Godot usa i colori dei vertici come se fossero già lineari: senza
# conversione il terreno viene fuori slavato. Si converte al momento dell'uso.


static func costruisci_terreno(terreno: CityTerrain) -> ArrayMesh:
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in terreno.size.y:
		for x in terreno.size.x:
			var coord := Vector2i(x, z)
			var y := terreno.quota(coord)
			var x0 := float(x) * cella - mezza
			var x1 := float(x) * cella + mezza
			var z0 := float(z) * cella - mezza
			var z1 := float(z) * cella + mezza
			var colore := _colore_cella(terreno, coord)

			_quad(st,
				Vector3(x0, y, z0), Vector3(x0, y, z1),
				Vector3(x1, y, z1), Vector3(x1, y, z0),
				Vector3.UP, colore)

			# Fianchi verso i vicini più bassi. Fuori mappa il terreno cala
			# comunque, altrimenti il bordo del mondo si vede in trasparenza.
			var quota_est := _quota_vicina(terreno, coord + Vector2i(1, 0))
			if quota_est < y:
				_quad(st,
					Vector3(x1, quota_est, z0), Vector3(x1, y, z0),
					Vector3(x1, y, z1), Vector3(x1, quota_est, z1),
					Vector3.RIGHT, COLORE_SCARPATA.srgb_to_linear())

			var quota_ovest := _quota_vicina(terreno, coord + Vector2i(-1, 0))
			if quota_ovest < y:
				_quad(st,
					Vector3(x0, quota_ovest, z1), Vector3(x0, y, z1),
					Vector3(x0, y, z0), Vector3(x0, quota_ovest, z0),
					Vector3.LEFT, COLORE_SCARPATA.srgb_to_linear())

			var quota_sud := _quota_vicina(terreno, coord + Vector2i(0, 1))
			if quota_sud < y:
				_quad(st,
					Vector3(x1, quota_sud, z1), Vector3(x1, y, z1),
					Vector3(x0, y, z1), Vector3(x0, quota_sud, z1),
					Vector3.BACK, COLORE_SCARPATA.srgb_to_linear())

			var quota_nord := _quota_vicina(terreno, coord + Vector2i(0, -1))
			if quota_nord < y:
				_quad(st,
					Vector3(x0, quota_nord, z0), Vector3(x0, y, z0),
					Vector3(x1, y, z0), Vector3(x1, quota_nord, z0),
					Vector3.FORWARD, COLORE_SCARPATA.srgb_to_linear())

	st.set_material(_materiale_terreno())
	return st.commit()


static func costruisci_acqua(terreno: CityTerrain) -> ArrayMesh:
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quadri := 0

	for z in terreno.size.y:
		for x in terreno.size.x:
			var coord := Vector2i(x, z)
			if not terreno.e_acqua(coord):
				continue
			var y: float = terreno.quota_acqua[terreno.indice(coord)]
			var x0 := float(x) * cella - mezza
			var x1 := float(x) * cella + mezza
			var z0 := float(z) * cella - mezza
			var z1 := float(z) * cella + mezza
			_quad(st,
				Vector3(x0, y, z0), Vector3(x0, y, z1),
				Vector3(x1, y, z1), Vector3(x1, y, z0),
				Vector3.UP, COLORE_ACQUA.srgb_to_linear())
			quadri += 1

	if quadri == 0:
		return ArrayMesh.new()
	st.set_material(_materiale_acqua())
	return st.commit()


## Reticolo delle celle, appoggiato alla quota di ciascuna. Solo sull'asciutto:
## sull'acqua non si costruisce, quindi disegnarlo sarebbe una bugia.
static func costruisci_reticolo(terreno: CityTerrain) -> Mesh:
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5

	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.albedo_color = Color(1.0, 1.0, 1.0, 0.10)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, materiale)
	for z in terreno.size.y:
		for x in terreno.size.x:
			var coord := Vector2i(x, z)
			if terreno.e_acqua(coord):
				continue
			# Un filo sopra la faccia, altrimenti le linee sfarfallano.
			var y := terreno.quota(coord) + 0.012
			var x0 := float(x) * cella - mezza
			var x1 := float(x) * cella + mezza
			var z0 := float(z) * cella - mezza
			var z1 := float(z) * cella + mezza
			var angoli := [
				Vector3(x0, y, z0), Vector3(x1, y, z0),
				Vector3(x1, y, z1), Vector3(x0, y, z1),
			]
			for i in 4:
				mesh.surface_add_vertex(angoli[i])
				mesh.surface_add_vertex(angoli[(i + 1) % 4])
	mesh.surface_end()
	return mesh


## Riquadri traslucidi sulle celle che un oggetto occuperebbe, alla quota a cui
## finirebbe davvero.
##
## Disegnarli alla quota di arrivo e non a quella attuale fa vedere in anticipo
## anche lo spianamento: se il lotto sta per scendere di un gradino, l'anteprima
## è già là sotto. Per questo il materiale ignora la profondità — altrimenti il
## terreno che sta per essere scavato coprirebbe proprio il riquadro che spiega
## cosa succederà.
static func costruisci_selezione(celle: Array[Vector2i], quota: float, colore: Color) -> Mesh:
	var mesh := ImmediateMesh.new()
	if celle.is_empty():
		return mesh

	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.no_depth_test = true
	materiale.cull_mode = BaseMaterial3D.CULL_DISABLED
	materiale.albedo_color = colore
	materiale.render_priority = 1

	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, materiale)
	for coord in celle:
		var x0 := float(coord.x) * cella - mezza
		var x1 := float(coord.x) * cella + mezza
		var z0 := float(coord.y) * cella - mezza
		var z1 := float(coord.y) * cella + mezza
		var a := Vector3(x0, quota, z0)
		var b := Vector3(x0, quota, z1)
		var c := Vector3(x1, quota, z1)
		var d := Vector3(x1, quota, z0)
		for vertice in [a, b, c, a, c, d]:
			mesh.surface_add_vertex(vertice)
	mesh.surface_end()
	return mesh


# --- Dettagli ---------------------------------------------------------------

static func _materiale_terreno() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


static func _materiale_acqua() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	m.roughness = 0.15
	m.metallic = 0.2
	return m


## Fuori dai bordi il terreno scende sotto il livello del mare, così la mappa
## finisce con una scogliera invece che con un buco.
static func _quota_vicina(terreno: CityTerrain, cella: Vector2i) -> float:
	if not terreno.dentro(cella):
		return -2.0 * CityTerrain.PASSO_QUOTA
	return terreno.quota(cella)


static func _colore_cella(terreno: CityTerrain, cella: Vector2i) -> Color:
	var base: Color = COLORI[terreno.bioma(cella)]
	var scarto := (_rumore_intero(cella.x, cella.y) - 0.5) * 2.0 * VARIAZIONE
	return Color(
		clampf(base.r + scarto, 0.0, 1.0),
		clampf(base.g + scarto, 0.0, 1.0),
		clampf(base.b + scarto, 0.0, 1.0)
	).srgb_to_linear()


## Hash deterministico: la stessa cella ha sempre la stessa sfumatura.
static func _rumore_intero(x: int, z: int) -> float:
	var h := (x * 73856093) ^ (z * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1024) / 1023.0


## I quattro angoli vanno passati in senso antiorario guardando da +normale.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normale: Vector3, colore: Color) -> void:
	if AVVOLGIMENTO_ORARIO:
		_tri(st, a, d, c, normale, colore)
		_tri(st, a, c, b, normale, colore)
	else:
		_tri(st, a, b, c, normale, colore)
		_tri(st, a, c, d, normale, colore)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		normale: Vector3, colore: Color) -> void:
	for punto in [a, b, c]:
		st.set_color(colore)
		st.set_normal(normale)
		st.add_vertex(punto)
