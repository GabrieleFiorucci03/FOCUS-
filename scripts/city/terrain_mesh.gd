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
	CityTerrain.Bioma.LAGO: Color(0.232, 0.315, 0.353),
	CityTerrain.Bioma.FIUME: Color(0.416, 0.404, 0.353),
	CityTerrain.Bioma.SPIAGGIA: Color(0.816, 0.741, 0.545),
	CityTerrain.Bioma.PIANURA: Color(0.353, 0.510, 0.271),
	CityTerrain.Bioma.COLLINA: Color(0.259, 0.396, 0.220),
	CityTerrain.Bioma.PRATERIA: Color(0.612, 0.596, 0.353),
}

## Terra battuta esposta sul fianco dei gradini.
const COLORE_SCARPATA := Color(0.443, 0.376, 0.286)
const COLORE_ACQUA := Color(0.153, 0.435, 0.549, 0.88)

## Quanto il colore di una cella può scostarsi, per non avere campiture piatte.
const VARIAZIONE := 0.05

# I colori qui sopra sono scritti in sRGB, come si leggono da un color picker,
# ma Godot usa i colori dei vertici come se fossero già lineari: senza
# conversione il terreno viene fuori slavato. Si converte al momento dell'uso.


## Il terreno di un riquadro. `zone` sono le zone che si vedono, `riquadro` le
## celle che questa mesh ha il compito di disegnare.
##
## Restano due cose diverse: `zone` dice cosa esiste, `riquadro` di chi è il
## compito. Una cella fuori dal riquadro va guardata comunque, per sapere se il
## vicino dentro il riquadro ha un fianco scoperto — e se la sua zona non si
## vede, quel fianco si chiude a scogliera come faceva sul bordo della mappa,
## che ormai non c'è più.
static func costruisci_terreno(terreno: CityTerrain,
		zone: Dictionary, riquadro: Rect2i) -> ArrayMesh:
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quadri := 0

	for z in range(riquadro.position.y, riquadro.end.y):
		for x in range(riquadro.position.x, riquadro.end.x):
			var coord := Vector2i(x, z)
			if not _visibile(coord, zone):
				continue
			quadri += 1
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

			# Fianchi verso i vicini più bassi. Dove non si disegna — fuori
			# mappa o fuori dalla maschera — il terreno cala comunque,
			# altrimenti il bordo si vede in trasparenza.
			var quota_est := _quota_vicina(terreno, coord + Vector2i(1, 0), zone)
			if quota_est < y:
				_quad(st,
					Vector3(x1, quota_est, z0), Vector3(x1, y, z0),
					Vector3(x1, y, z1), Vector3(x1, quota_est, z1),
					Vector3.RIGHT, COLORE_SCARPATA.srgb_to_linear())

			var quota_ovest := _quota_vicina(terreno, coord + Vector2i(-1, 0), zone)
			if quota_ovest < y:
				_quad(st,
					Vector3(x0, quota_ovest, z1), Vector3(x0, y, z1),
					Vector3(x0, y, z0), Vector3(x0, quota_ovest, z0),
					Vector3.LEFT, COLORE_SCARPATA.srgb_to_linear())

			var quota_sud := _quota_vicina(terreno, coord + Vector2i(0, 1), zone)
			if quota_sud < y:
				_quad(st,
					Vector3(x1, quota_sud, z1), Vector3(x1, y, z1),
					Vector3(x0, y, z1), Vector3(x0, quota_sud, z1),
					Vector3.BACK, COLORE_SCARPATA.srgb_to_linear())

			var quota_nord := _quota_vicina(terreno, coord + Vector2i(0, -1), zone)
			if quota_nord < y:
				_quad(st,
					Vector3(x0, quota_nord, z0), Vector3(x0, y, z0),
					Vector3(x1, y, z0), Vector3(x1, quota_nord, z0),
					Vector3.FORWARD, COLORE_SCARPATA.srgb_to_linear())

	if quadri == 0:
		return ArrayMesh.new()
	st.set_material(_materiale_terreno())
	return st.commit()


static func costruisci_acqua(terreno: CityTerrain,
		zone: Dictionary, riquadro: Rect2i) -> ArrayMesh:
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quadri := 0

	for z in range(riquadro.position.y, riquadro.end.y):
		for x in range(riquadro.position.x, riquadro.end.x):
			var coord := Vector2i(x, z)
			if not terreno.e_acqua(coord) or not _visibile(coord, zone):
				continue
			var y: float = terreno.pelo_acqua(coord)
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
static func costruisci_reticolo(terreno: CityTerrain,
		zone: Dictionary, riquadro: Rect2i) -> Mesh:
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5

	var materiale := StandardMaterial3D.new()
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiale.albedo_color = Color(1.0, 1.0, 1.0, 0.10)

	# I punti prima, la superficie poi: una zona tutta d'acqua non ha una sola
	# cella da reticolare, e apire una superficie per non metterci niente è un
	# errore di Godot, non una mesh vuota.
	var punti := PackedVector3Array()
	for z in range(riquadro.position.y, riquadro.end.y):
		for x in range(riquadro.position.x, riquadro.end.x):
			var coord := Vector2i(x, z)
			if terreno.e_acqua(coord) or not _visibile(coord, zone):
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
				punti.append(angoli[i])
				punti.append(angoli[(i + 1) % 4])

	var mesh := ImmediateMesh.new()
	if punti.is_empty():
		return mesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, materiale)
	for punto in punti:
		mesh.surface_add_vertex(punto)
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
	var quote := PackedFloat32Array()
	quote.resize(celle.size())
	quote.fill(quota)
	return costruisci_gruppi([{ "celle": celle, "quote": quote, "colore": colore }])


## Celle colorate a gruppi, ognuno col suo colore, in una mesh sola.
##
## Un gruppo è { celle: Array[Vector2i], quote: PackedFloat32Array, colore }, e
## le quote stanno in parallelo alle celle e non una per tutte: evidenziando le
## costruzioni di mezza città ognuna sta alla propria, e una quota sola le
## seppellirebbe o le farebbe volare. Una mesh sola perché sono la stessa
## informazione detta in due colori — chi ha il servizio e chi no.
static func costruisci_gruppi(gruppi: Array) -> Mesh:
	var mesh := ImmediateMesh.new()
	var cella := CityGrid.CELL_SIZE
	var mezza := cella * 0.5
	for gruppo in gruppi:
		var celle: Array = gruppo["celle"]
		if celle.is_empty():
			continue
		var quote: PackedFloat32Array = gruppo["quote"]

		var materiale := StandardMaterial3D.new()
		materiale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materiale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		materiale.no_depth_test = true
		materiale.cull_mode = BaseMaterial3D.CULL_DISABLED
		materiale.albedo_color = gruppo["colore"]
		materiale.render_priority = 1

		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, materiale)
		for i in celle.size():
			var coord: Vector2i = celle[i]
			var quota := quote[i]
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


## Fuori dai bordi — quelli della mappa e quelli di ciò che si disegna — il
## terreno scende sotto il livello dell'acqua, così il mondo finisce con una
## scogliera invece che con un buco.
static func _quota_vicina(terreno: CityTerrain, cella: Vector2i,
		zone: Dictionary) -> float:
	if not _visibile(cella, zone):
		return -2.0 * CityTerrain.PASSO_QUOTA
	return terreno.quota(cella)


## Se una cella va disegnata: lo dice la zona a cui appartiene.
##
## Era una maschera con un byte per cella, e in un mondo senza bordo non poteva
## restarlo: non c'è un array grande quanto il mondo su cui indicizzare. La
## visibilità però non è mai stata una faccenda di celle — si compra e si vede
## per zone — quindi la domanda vera è sempre stata questa.
static func _visibile(cella: Vector2i, zone: Dictionary) -> bool:
	return zone.has(CityTerrain.blocco_di(cella))


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
