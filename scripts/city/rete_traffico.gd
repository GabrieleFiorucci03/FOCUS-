class_name ReteTraffico
extends RefCounted
## Percorsi visuali ricavati dalle aperture e dalle quote dei modelli reali.
## Nessun NavigationServer, collisione fisica o dato nel salvataggio.

const DIR := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
var tratti: Dictionary = {}
var _percorsi: Dictionary = {}


func ricostruisci(griglia: CityGrid, catalogo: CityCatalog, costruzioni: Dictionary) -> void:
	tratti.clear()
	_percorsi.clear()
	var bordi: Dictionary = {}
	for p in griglia.piazzamenti():
		var modello := str(p.modello)
		if not catalogo.e_strada(modello) or not costruzioni.has(p.id):
			continue
		var v := catalogo.voce(modello)
		var rampa := str(v.kind) == "sloped_road" or str(v.variante) == "ramp"
		var maschera: int = ReteStradale.BRACCIA.get(str(v.variante).to_upper(), 5)
		if rampa:
			maschera = 5
		maschera = ReteStradale.maschera_ruotata(maschera, int(p.rotazione))
		var centro := griglia.posizione_mondo(p.ancora, p.footprint, p.rotazione)
		centro.y = float(costruzioni[p.id].livello) * CityTerrain.PASSO_QUOTA
		var f := CityGrid.footprint_ruotato(p.footprint, p.rotazione)
		var ponte := str(v.kind) == "bridge"
		var salita := float(v.salita) * .5 if rampa else 0.0
		var alto := Vector3(0, 0, -1).rotated(Vector3.UP, -PI * .5 * int(p.rotazione))
		if modello.contains("_DOWN_"):
			alto = -alto
		var tratto := {"centro": centro, "f": f, "maschera": maschera,
			"alto": alto, "salita": salita, "ponte": ponte, "rampa": rampa,
			"pedoni": not modello.contains("_DIRT_"), "vicini": {}, "porti": {}}
		tratti[p.id] = tratto
		for d in 4:
			if maschera & (1 << d) == 0:
				continue
			var punto: Vector3 = centro + DIR[d] * (f.x if d % 2 else f.y)
			punto.y = quota(tratto, punto, false)
			tratto.porti[d] = punto
			var chiave := Vector2i(roundi(punto.x), roundi(punto.z))
			if not bordi.has(chiave):
				bordi[chiave] = []
			bordi[chiave].append([p.id, d, punto.y])
	for gruppo in bordi.values():
		if gruppo.size() != 2:
			continue
		var a: Array = gruppo[0]
		var b: Array = gruppo[1]
		# Le altezze di asfalto/impalcato differiscono di pochi centimetri;
		# un gradino intero o due braccia non opposte non sono un collegamento.
		if posmod(int(a[1]) + 2, 4) == b[1] and absf(float(a[2]) - float(b[2])) < .13:
			tratti[a[0]].vicini[a[1]] = b[0]
			tratti[b[0]].vicini[b[1]] = a[0]
			var quota_comune := (float(a[2]) + float(b[2])) * .5
			tratti[a[0]].porti[a[1]].y = quota_comune
			tratti[b[0]].porti[b[1]].y = quota_comune


func quota(t: Dictionary, punto: Vector3, pedone: bool) -> float:
	var base: float = t.centro.y
	if t.rampa:
		var semilunghezza: float = t.f.x if absf(t.alto.x) > .5 else t.f.y
		base += t.salita * clampf(.5 + (punto - t.centro).dot(t.alto) / (2.0 * semilunghezza), 0, 1)
	if pedone:
		return base + (.006 if t.rampa or t.ponte else .076)
	return base + (.036 if t.ponte else (.03 if t.rampa else .106))


func uscite(id: int, entrata: int) -> Array:
	var result: Array = []
	for d in tratti[id].vicini:
		if d != entrata:
			result.append(d)
	return result


func percorso(id: int, entrata: int, uscita: int, lato: int = 0) -> Curve3D:
	var chiave := Vector4i(id, entrata, uscita, lato)
	if _percorsi.has(chiave):
		return _percorsi[chiave]
	var t: Dictionary = tratti[id]
	var curva := Curve3D.new()
	curva.bake_interval = .035
	var centro: Vector3 = t.centro
	var a: Vector3 = DIR[entrata]
	if lato == 0:
		var inizio: Vector3 = t.porti[entrata] - a.cross(Vector3.UP) * .23
		var fine: Vector3
		var c1: Vector3
		var c2: Vector3
		if uscita < 0:
			fine = centro - a.cross(Vector3.UP) * .23 + a * .05
			c1 = inizio.lerp(fine, .33)
			c2 = inizio.lerp(fine, .66)
		else:
			var b: Vector3 = DIR[uscita]
			fine = t.porti[uscita] + b.cross(Vector3.UP) * .23
			c1 = inizio - a * (t.f.x if entrata % 2 else t.f.y)
			c2 = fine - b * (t.f.x if uscita % 2 else t.f.y)
		for i in 33:
			var s := float(i) / 32.0
			var punto := inizio.bezier_interpolate(c1, c2, fine, s)
			punto.y = quota(t, punto, false)
			# Raccordo dolce ai capi fra superfici con spessori diversi.
			punto.y += (inizio.y - quota(t, inizio, false)) * pow(1.0 - s, 8)
			if uscita >= 0:
				punto.y += (fine.y - quota(t, fine, false)) * pow(s, 8)
			curva.add_point(punto)
	else:
		# Si segue il bordo dell'asfalto: nessun attraversamento pedonale
		# implicito al centro di un incrocio. Sui ponti si resta dentro le ringhiere.
		var r := .55 if t.ponte else .79
		var inizio := _bordo_pedonale(id, entrata, lato)
		var punti: Array[Vector3] = [inizio]
		var d := entrata
		punti.append(centro + a * r + a.cross(Vector3.UP) * r * lato)
		for _i in 4:
			var prossimo := posmod(d - lato, 4)
			if prossimo == uscita:
				break
			d = prossimo
			punti.append(centro + DIR[d] * r + DIR[d].cross(Vector3.UP) * r * lato)
		var b: Vector3 = DIR[uscita]
		punti.append(centro + b * r - b.cross(Vector3.UP) * r * lato)
		punti.append(_bordo_pedonale(id, uscita, -lato))
		for i in punti.size():
			var punto: Vector3 = punti[i]
			if i > 0 and i < punti.size() - 1:
				punto.y = quota(t, punto, true)
			if curva.point_count == 0 or punto.distance_to(curva.get_point_position(curva.point_count - 1)) > .001:
				curva.add_point(punto)
	_percorsi[chiave] = curva
	return curva


func uscita_pedone(id: int, entrata: int, lato: int) -> int:
	for passo in range(1, 5):
		var d := posmod(entrata - lato * passo, 4)
		if int(tratti[id].maschera) & (1 << d):
			return d
	return entrata


func _bordo_pedonale(id: int, d: int, lato: int) -> Vector3:
	var t: Dictionary = tratti[id]
	var r := .55 if t.ponte else .79
	var punto: Vector3 = t.porti[d]
	var y := quota(t, punto, true)
	var vicino: int = t.vicini.get(d, -1)
	if vicino >= 0 and tratti[vicino].pedoni:
		var altro: Dictionary = tratti[vicino]
		# Un punto comune dentro le ringhiere, anche fra marciapiedi diversi.
		r = minf(r, .55 if altro.ponte else .79)
		y = (y + quota(altro, punto, true)) * .5
	punto += DIR[d].cross(Vector3.UP) * r * lato
	punto.y = y
	return punto
