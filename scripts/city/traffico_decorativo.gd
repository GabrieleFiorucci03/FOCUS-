class_name TrafficoDecorativo
extends Node3D
## Traffico ambientale limitato e disegnato in batch. Nessun corpo fisico,
## salvataggio, missione o dipendenza dai servizi della citta.

const MAX_AUTO := 32
const MAX_PEDONI := 64
const MODELLI := ["VEH_COMPACT_TEAL", "VEH_SEDAN_CORAL", "VEH_WAGON_OCHRE",
	"VEH_AMBULANCE", "VEH_FIRE_ENGINE", "VEH_POLICE"]
const DIMENSIONI := [Vector2(.324, .566), Vector2(.324, .656), Vector2(.324, .686),
	Vector2(.354, .746), Vector2(.354, .816), Vector2(.324, .656)]
const VESTITI := [Color("538c86"), Color("c16f59"), Color("c7a458"), Color("416a90"), Color("989e8d")]
const PELLE := [Color("e2b89a"), Color("b8805d"), Color("79533f")]

var rete := ReteTraffico.new()
var auto: Array[Dictionary] = []
var pedoni: Array[Dictionary] = []
var _griglia: CityGrid
var _catalogo: CityCatalog
var _costruzioni: Dictionary
var _fuoco: Node3D
var _caso := RandomNumberGenerator.new()
var _sporca := true
var _firma := 0
var _attesa_spawn := 0.0
var _seriale := 0
var _incroci: Dictionary = {}
var _carrozzerie: Array[MultiMesh] = []
var _ruote: MultiMesh
var _fari: MultiMesh
var _teste: MultiMesh
var _busti: MultiMesh
var _gambe: MultiMesh
var _pos_ruote: Array[Array] = []
var _pos_fari: Array[Array] = []


func configura(griglia: CityGrid, catalogo: CityCatalog, costruzioni: Dictionary, fuoco: Node3D) -> void:
	_griglia = griglia
	_catalogo = catalogo
	_costruzioni = costruzioni
	_fuoco = fuoco
	_caso.seed = 87123
	_griglia.changed.connect(invalida)
	_prepara_mesh()


func invalida() -> void:
	_sporca = true


func _aggiorna_rete() -> void:
	_sporca = false
	var descrizione: Array = []
	for p in _griglia.piazzamenti():
		if _catalogo.e_strada(str(p.modello)) and _costruzioni.has(p.id):
			descrizione.append([p.id, p.modello, p.ancora, p.rotazione, _costruzioni[p.id].livello])
	var firma := hash(descrizione)
	if firma == _firma:
		return
	_firma = firma
	rete.ricostruisci(_griglia, _catalogo, _costruzioni)
	# Una modifica strutturale invalida anche le curve gia impegnate: nessun
	# mezzo continua a viaggiare su una strada demolita o spostata.
	auto.clear()
	pedoni.clear()
	_incroci.clear()
	_attesa_spawn = 0


func _process(delta: float) -> void:
	if _griglia == null or not is_visible_in_tree():
		return
	if _sporca:
		_aggiorna_rete()
	_attesa_spawn -= delta
	if _attesa_spawn <= 0:
		_popola()
		_attesa_spawn = .8
	# Passi corti anche dopo uno scatto del frame: niente attraversamenti
	# istantanei delle altre auto e nessun recupero illimitato in background.
	var tempo := minf(delta, .1)
	while tempo > .00001:
		var passo := minf(tempo, 1.0 / 60.0)
		avanza(passo)
		tempo -= passo
	_disegna()


func _raggio() -> float:
	var camera := get_viewport().get_camera_3d()
	return maxf(16.0, camera.size * .95) if camera != null else 60.0


func _popola() -> void:
	var vicini: Array[int] = []
	var marciapiedi: Array[int] = []
	var centro := _fuoco.position if is_instance_valid(_fuoco) else Vector3.ZERO
	var raggio := _raggio()
	for id in rete.tratti:
		var t: Dictionary = rete.tratti[id]
		if Vector2(t.centro.x - centro.x, t.centro.z - centro.z).length() > raggio:
			continue
		if not t.vicini.is_empty():
			vicini.append(id)
		if t.pedoni:
			marciapiedi.append(id)
	for i in range(auto.size() - 1, -1, -1):
		var p: Vector3 = auto[i].posa.origin
		if Vector2(p.x - centro.x, p.z - centro.z).length() > raggio * 1.5:
			_ritira(i)
	for i in range(pedoni.size() - 1, -1, -1):
		var p: Vector3 = pedoni[i].posa.origin
		if Vector2(p.x - centro.x, p.z - centro.z).length() > raggio * 1.5:
			pedoni.remove_at(i)
	var desiderate := mini(MAX_AUTO, ceili(vicini.size() * .48))
	for _i in 8:
		if auto.size() >= desiderate or vicini.is_empty():
			break
		_crea_auto(vicini[_caso.randi_range(0, vicini.size() - 1)])
	var persone := mini(MAX_PEDONI, marciapiedi.size())
	for _i in 10:
		if pedoni.size() >= persone or marciapiedi.is_empty():
			break
		_crea_pedone(marciapiedi[_caso.randi_range(0, marciapiedi.size() - 1)])


func _crea_auto(id: int) -> void:
	var t: Dictionary = rete.tratti[id]
	# Gli incroci si raggiungono in movimento, non sono punti di apparizione.
	if t.porti.size() > 2:
		return
	var entrate: Array = t.vicini.keys()
	var entrata := int(entrate[_caso.randi_range(0, entrate.size() - 1)])
	var modello := _caso.randi_range(0, 2) if _caso.randf() < .72 else _caso.randi_range(3, 5)
	_seriale += 1
	var a := {"seriale": _seriale, "id": id, "entrata": entrata, "modello": modello,
		"distanza": 0.0, "velocita": 0.0, "massima": _caso.randf_range(.48, .95),
		"ferma": 0.0, "ruota": 0.0, "posa": Transform3D.IDENTITY}
	_scegli_percorso(a)
	var lunghezza: float = a.curva.get_baked_length()
	# Entrambi i paraurti rimangono sul pezzo durante lo spawn.
	if lunghezza < 1.1:
		return
	a.distanza = _caso.randf_range(.48, lunghezza - .48)
	a.posa = _posa(a.curva, a.distanza)
	if _libera(a, a.posa):
		auto.append(a)


func _scegli_percorso(a: Dictionary) -> void:
	var uscite := rete.uscite(a.id, a.entrata)
	a.uscita = -1 if uscite.is_empty() else int(uscite[_caso.randi_range(0, uscite.size() - 1)])
	a.curva = rete.percorso(a.id, a.entrata, a.uscita)


static func _posa(curva: Curve3D, distanza: float) -> Transform3D:
	var lunghezza := curva.get_baked_length()
	distanza = clampf(distanza, 0, lunghezza)
	var p := curva.sample_baked(distanza)
	var verso := curva.sample_baked(minf(lunghezza, distanza + .025)) - curva.sample_baked(maxf(0, distanza - .025))
	if verso.length_squared() < .000001:
		verso = Vector3.FORWARD
	return Transform3D(Basis.looking_at(verso.normalized(), Vector3.UP, true), p)


## Separazione fra rettangoli orientati, con margine su tutti i lati.
## L'ingombro include ruote e paraurti, anche durante le svolte.
static func sovrapposte(a: Transform3D, da: Vector2, b: Transform3D, db: Vector2, margine: float = .045) -> bool:
	# Intervalli verticali conservativi, compreso lo sbalzo sulle rampe.
	var ya := absf(a.basis.z.y) * da.y * .5 + absf(a.basis.x.y) * da.x * .5 + absf(a.basis.y.y) * .175
	var yb := absf(b.basis.z.y) * db.y * .5 + absf(b.basis.x.y) * db.x * .5 + absf(b.basis.y.y) * .175
	if absf(a.origin.y + a.basis.y.y * .175 - b.origin.y - b.basis.y.y * .175) > ya + yb + .02:
		return false
	var delta := Vector2(b.origin.x - a.origin.x, b.origin.z - a.origin.z)
	if delta.length_squared() > 2.25:
		return false
	var ax := Vector2(a.basis.x.x, a.basis.x.z).normalized()
	var az := Vector2(a.basis.z.x, a.basis.z.z).normalized()
	var bx := Vector2(b.basis.x.x, b.basis.x.z).normalized()
	var bz := Vector2(b.basis.z.x, b.basis.z.z).normalized()
	var ha := da * .5 + Vector2.ONE * margine
	var hb := db * .5 + Vector2.ONE * margine
	for asse in [ax, az, bx, bz]:
		var ra: float = absf(asse.dot(ax)) * ha.x + absf(asse.dot(az)) * ha.y
		var rb: float = absf(asse.dot(bx)) * hb.x + absf(asse.dot(bz)) * hb.y
		if absf(delta.dot(asse)) >= ra + rb:
			return false
	return true


func _libera(a: Dictionary, posa: Transform3D, margine: float = .045) -> bool:
	for b in auto:
		if b.seriale != a.seriale and sovrapposte(posa, DIMENSIONI[a.modello], b.posa, DIMENSIONI[b.modello], margine):
			return false
	return true


func _passaggio(a: Dictionary) -> bool:
	if a.uscita < 0:
		return true
	var prossimo: int = rete.tratti[a.id].vicini[a.uscita]
	if rete.tratti[prossimo].porti.size() < 3:
		return true
	if a.curva.get_baked_length() - a.distanza > .68:
		return true
	if _incroci.has(prossimo) and _incroci[prossimo] != a.seriale:
		return false
	_incroci[prossimo] = a.seriale
	return true


func _ritira(i: int) -> void:
	var a: Dictionary = auto[i]
	for id in _incroci.keys():
		if _incroci[id] == a.seriale:
			_incroci.erase(id)
	auto.remove_at(i)


func avanza(delta: float) -> void:
	for i in range(auto.size() - 1, -1, -1):
		var a: Dictionary = auto[i]
		var libera := _passaggio(a)
		var avanti := _posa(a.curva, a.distanza + .20)
		var obiettivo: float = a.massima if libera and _libera(a, avanti) else 0.0
		a.velocita = move_toward(a.velocita, obiettivo, delta * 1.8)
		var proposta := a.duplicate()
		var movimento: float = a.velocita * delta if libera else 0.0
		proposta.distanza += movimento
		if proposta.distanza >= a.curva.get_baked_length():
			if a.uscita < 0:
				_ritira(i)
				continue
			proposta.distanza -= a.curva.get_baked_length()
			proposta.id = rete.tratti[a.id].vicini[a.uscita]
			proposta.entrata = posmod(a.uscita + 2, 4)
			_scegli_percorso(proposta)
		proposta.posa = _posa(proposta.curva, proposta.distanza)
		if movimento > .000001 and _libera(a, proposta.posa):
			proposta.ruota += movimento / .054
			proposta.ferma = 0.0
			for id in _incroci.keys():
				if _incroci[id] != proposta.seriale or id == proposta.id:
					continue
				var t: Dictionary = rete.tratti[id]
				var p: Vector3 = proposta.posa.origin - t.centro
				var prossimo: int = rete.tratti[proposta.id].vicini.get(proposta.uscita, -1)
				if prossimo != id and (absf(p.x) > t.f.x + .6 or absf(p.z) > t.f.y + .6):
					_incroci.erase(id)
			auto[i] = proposta
		else:
			a.velocita = 0.0
			a.ferma += delta
			# Un raro ingorgo circolare non blocca per sempre una decorazione.
			if a.ferma > 18.0:
				_ritira(i)
	for p in pedoni:
		p.distanza += p.velocita * delta
		p.fase += p.velocita * delta * 30.0
		if p.distanza >= p.curva.get_baked_length():
			p.distanza -= p.curva.get_baked_length()
			var prossimo: int = rete.tratti[p.id].vicini.get(p.uscita, -1)
			if prossimo >= 0 and rete.tratti[prossimo].pedoni:
				p.id = prossimo
				p.entrata = posmod(p.uscita + 2, 4)
			else:
				p.entrata = p.uscita
				p.lato = -p.lato
			p.uscita = rete.uscita_pedone(p.id, p.entrata, p.lato)
			p.curva = rete.percorso(p.id, p.entrata, p.uscita, p.lato)
		p.posa = _posa(p.curva, p.distanza)


func _crea_pedone(id: int) -> void:
	var porti: Array = rete.tratti[id].porti.keys()
	var entrata := int(porti[_caso.randi_range(0, porti.size() - 1)])
	var lato := 1 if _caso.randf() > .5 else -1
	var uscita := rete.uscita_pedone(id, entrata, lato)
	var curva := rete.percorso(id, entrata, uscita, lato)
	var distanza := _caso.randf() * curva.get_baked_length()
	pedoni.append({"id": id, "entrata": entrata, "uscita": uscita, "lato": lato,
		"curva": curva, "distanza": distanza, "posa": _posa(curva, distanza),
		"velocita": _caso.randf_range(.12, .24), "fase": _caso.randf() * TAU,
		"vestito": VESTITI[_caso.randi_range(0, VESTITI.size() - 1)],
		"pelle": PELLE[_caso.randi_range(0, PELLE.size() - 1)]})


func _materiale() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = .8
	return m


func _batch(mesh: Mesh, quanti: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = quanti
	mm.visible_instance_count = 0
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = mm
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	return mm


## Unifica le superfici colorate dei GLB in una sola superficie a colori per
## vertice: sei batch per le carrozzerie, uno per tutte le ruote e uno per i fari.
func _unisci(mesh: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertici: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normali: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indici: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var mat := mesh.surface_get_material(s) as BaseMaterial3D
		var colore := mat.albedo_color if mat != null else Color.WHITE
		for j in (indici.size() if not indici.is_empty() else vertici.size()):
			var k: int = indici[j] if not indici.is_empty() else j
			st.set_color(colore)
			st.set_normal(normali[k])
			st.add_vertex(vertici[k])
	st.set_material(_materiale())
	return st.commit()


func _cubo(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _materiale()
	return mesh


func _prepara_mesh() -> void:
	for modello in MODELLI:
		var scena := load("res://assets/models/vehicles/%s.glb" % modello) as PackedScene
		var nodo := scena.instantiate() as Node3D
		var body := nodo.find_child("Body", true, false) as MeshInstance3D
		_carrozzerie.append(_batch(_unisci(body.mesh), MAX_AUTO))
		var ruote: Array = []
		var fari: Array = []
		for nome in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
			var ruota := nodo.find_child(nome, true, false) as MeshInstance3D
			ruote.append(ruota.transform)
			if _ruote == null:
				_ruote = _batch(_unisci(ruota.mesh), MAX_AUTO * 4)
		for nome in ["Beacon_L", "Beacon_R"]:
			var faro := nodo.find_child(nome, true, false) as MeshInstance3D
			if faro != null:
				fari.append(faro.transform)
				if _fari == null:
					var mesh := _unisci(faro.mesh)
					var mat := mesh.surface_get_material(0) as StandardMaterial3D
					mat.emission_enabled = true
					mat.emission = Color(.04, .15, .5)
					_fari = _batch(mesh, MAX_AUTO * 2)
		_pos_ruote.append(ruote)
		_pos_fari.append(fari)
		nodo.free()
	_teste = _batch(_cubo(Vector3(.055, .055, .055)), MAX_PEDONI)
	_busti = _batch(_cubo(Vector3(.066, .08, .045)), MAX_PEDONI)
	_gambe = _batch(_cubo(Vector3(.024, .075, .028)), MAX_PEDONI * 2)


func _disegna() -> void:
	var conteggi := [0, 0, 0, 0, 0, 0]
	var ruote := 0
	var fari := 0
	for a in auto:
		var m: int = a.modello
		var posa: Transform3D = a.posa
		_carrozzerie[m].set_instance_transform(conteggi[m], posa)
		_carrozzerie[m].set_instance_color(conteggi[m], Color.WHITE)
		conteggi[m] += 1
		for locale in _pos_ruote[m]:
			var tr: Transform3D = locale
			tr.basis = tr.basis * Basis(Vector3.RIGHT, a.ruota)
			_ruote.set_instance_transform(ruote, posa * tr)
			_ruote.set_instance_color(ruote, Color.WHITE)
			ruote += 1
		for locale in _pos_fari[m]:
			_fari.set_instance_transform(fari, posa * locale)
			# Colore alternato, nessuna luce dinamica o sirena sonora.
			var acceso := sin(Time.get_ticks_msec() * .009 + fari * PI) > .2
			_fari.set_instance_color(fari, Color.WHITE if acceso else Color(.3, .3, .3))
			fari += 1
	for m in MODELLI.size():
		_carrozzerie[m].visible_instance_count = conteggi[m]
	_ruote.visible_instance_count = ruote
	_fari.visible_instance_count = fari
	for i in pedoni.size():
		var p: Dictionary = pedoni[i]
		var posa: Transform3D = p.posa
		# Le persone rimangono verticali anche sulle salite.
		posa.basis = Basis(Vector3.UP, atan2(posa.basis.z.x, posa.basis.z.z))
		_teste.set_instance_transform(i, posa.translated_local(Vector3(0, .183, 0)))
		_teste.set_instance_color(i, p.pelle)
		_busti.set_instance_transform(i, posa.translated_local(Vector3(0, .115, 0)))
		_busti.set_instance_color(i, p.vestito)
		for lato in 2:
			var segno := 1.0 if lato else -1.0
			var gamba := Transform3D(Basis(Vector3.RIGHT, sin(p.fase) * .43 * segno), Vector3(segno * .019, .076, 0))
			gamba = gamba.translated_local(Vector3(0, -.0375, 0))
			_gambe.set_instance_transform(i * 2 + lato, posa * gamba)
			_gambe.set_instance_color(i * 2 + lato, Color("354c56"))
	_teste.visible_instance_count = pedoni.size()
	_busti.visible_instance_count = pedoni.size()
	_gambe.visible_instance_count = pedoni.size() * 2
