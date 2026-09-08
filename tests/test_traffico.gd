extends Node3D
## Fixture autonoma: non carica CityView e non scrive dati di partita.
## -- --preview produce una scena reale per la verifica visuale.

var griglia := CityGrid.new()
var catalogo: CityCatalog
var costruzioni: Dictionary = {}
var traffico: TrafficoDecorativo
var fallimenti: Array[String] = []
var visuale := false


func _ready() -> void:
	visuale = "--preview" in OS.get_cmdline_user_args()
	catalogo = CityCatalog.new()
	_prova_quote()
	_crea_quartiere()
	traffico = TrafficoDecorativo.new()
	add_child(traffico)
	traffico.configura(griglia, catalogo, costruzioni, self)
	traffico.set_process(false)
	traffico._aggiorna_rete()
	if visuale:
		_anteprima()
		return
	_prova_percorsi()
	# Saturazione iniziale per esercitare anche il tetto di 32 veicoli.
	for _i in 300:
		if traffico.auto.size() == traffico.MAX_AUTO:
			break
		var ids: Array = traffico.rete.tratti.keys()
		traffico._crea_auto(ids[_i % ids.size()])
	var passaggi := 0
	var fermate := 0
	var spawn := 0
	for tick in 7200:
		if tick % 48 == 0:
			traffico._popola()
			spawn = maxi(spawn, traffico.auto.size())
		var prima: Dictionary = {}
		for a in traffico.auto:
			prima[a.seriale] = a.id
		traffico.avanza(1.0 / 60.0)
		for i in traffico.auto.size():
			var a: Dictionary = traffico.auto[i]
			if prima.get(a.seriale, a.id) != a.id:
				passaggi += 1
			if a.ferma > .1:
				fermate += 1
			for j in range(i):
				var b: Dictionary = traffico.auto[j]
				if TrafficoDecorativo.sovrapposte(a.posa, traffico.DIMENSIONI[a.modello], b.posa, traffico.DIMENSIONI[b.modello], 0):
					fallimenti.append("Collisione al tick %d tra %d e %d" % [tick, a.seriale, b.seriale])
					_concludi()
					return
		if tick % 120 == 0:
			traffico._disegna()
	verifica(spawn > 8, "La prova deve includere abbastanza veicoli.")
	verifica(passaggi > 100, "Il traffico deve continuare a circolare, non solo restare fermo.")
	verifica(fermate > 0, "La prova deve esercitare l'attesa fra veicoli.")
	verifica(not traffico.pedoni.is_empty(), "Devono esserci pedoni sui marciapiedi.")
	verifica(traffico.auto.size() <= traffico.MAX_AUTO and traffico.pedoni.size() <= traffico.MAX_PEDONI, "Limiti di popolazione.")
	var identita := Transform3D.IDENTITY
	verifica(TrafficoDecorativo.sovrapposte(identita, Vector2(.354, .816), identita.translated(Vector3(0, 0, .7)), Vector2(.354, .816)), "Rilevare paraurti sovrapposti.")
	verifica(not TrafficoDecorativo.sovrapposte(identita, Vector2(.354, .816), identita.translated(Vector3(.46, 0, 0)), Vector2(.354, .816)), "Corsie opposte libere.")
	verifica(not TrafficoDecorativo.sovrapposte(identita, Vector2(.354, .816), identita.translated(Vector3(0, .5, 0)), Vector2(.354, .816)), "Livelli separati liberi.")
	# Demolizione mentre le curve sono in uso; anche l'ultima strada sparisce.
	for p in griglia.piazzamenti():
		costruzioni.erase(p.id)
		griglia.rimuovi(p.ancora)
	verifica(traffico._sporca, "Le modifiche della griglia devono invalidare il traffico.")
	traffico._aggiorna_rete()
	traffico._disegna()
	verifica(traffico.auto.is_empty() and traffico.pedoni.is_empty() and traffico.rete.tratti.is_empty(), "Nessun traffico su strade demolite.")
	print("TRAFFICO: 120 secondi, picco %d auto, %d passaggi, %d attese, zero collisioni." % [spawn, passaggi, fermate])
	_concludi()


func verifica(ok: bool, messaggio: String) -> void:
	if not ok:
		fallimenti.append(messaggio)


func _concludi() -> void:
	for messaggio in fallimenti:
		push_error(messaggio)
	get_tree().quit(0 if fallimenti.is_empty() else 1)


func _posa_modello(modello: String, cella: Vector2i, rotazione: int = 0, livello: int = 0) -> int:
	var voce := catalogo.voce(modello)
	var id := griglia.piazza(cella, voce.footprint, rotazione, modello)
	assert(id != 0)
	costruzioni[id] = {"livello": livello}
	if visuale:
		var nodo := (load(voce.percorso) as PackedScene).instantiate() as Node3D
		add_child(nodo)
		nodo.position = griglia.posizione_mondo(cella, voce.footprint, rotazione)
		nodo.position.y = livello * .5
		nodo.rotation.y = -PI * .5 * rotazione
	return id


func _crea_quartiere() -> void:
	var celle: Dictionary = {}
	for x in range(-4, 5):
		for z in [-3, 0, 3]:
			celle[Vector2i(x, z)] = true
	for z in range(-4, 5):
		for x in [-4, 0, 4]:
			celle[Vector2i(x, z)] = true
	for cella in celle:
		var maschera := 0
		for d in 4:
			if celle.has(cella + ReteStradale.DIREZIONI[d]):
				maschera |= 1 << d
		var pezzo := ReteStradale.pezzo(maschera)
		_posa_modello("ROAD_LOCAL_1x1_" + str(pezzo.variante), cella, pezzo.rotazione)


func _prova_quote() -> void:
	# Rampe in entrambe le direzioni e ruotate; il ponte non si aggancia
	# alla strada sottostante. Si usano gli stessi metadata del gioco.
	for rot in 4:
		for suffisso in ["UP", "DOWN"]:
			var c := Vector2i(rot * 10 + 30, 30 if suffisso == "UP" else 40)
			var id := _posa_modello("ROAD_LOCAL_SLOPE_1x2_%s_050" % suffisso, c, rot, 3)
			var r := ReteTraffico.new()
			r.ricostruisci(griglia, catalogo, costruzioni)
			var t: Dictionary = r.tratti[id]
			var altezze: Array = []
			for punto in t.porti.values():
				altezze.append(punto.y)
			altezze.sort()
			verifica(is_equal_approx(altezze[0], 1.53) and is_equal_approx(altezze[1], 2.03), "Quote della rampa " + suffisso)
			var porti: Array = t.porti.keys()
			var curva := r.percorso(id, porti[0], porti[1])
			verifica(curva.get_baked_length() > 4.0, "La rampa 1x2 deve coprire quattro unita.")
	var a := _posa_modello("ROAD_LOCAL_1x1_STRAIGHT", Vector2i(50, 50))
	var b := _posa_modello("BRG_LOCAL_DECK_1x1_STRAIGHT", Vector2i(50, 51), 0, 2)
	var r := ReteTraffico.new()
	r.ricostruisci(griglia, catalogo, costruzioni)
	verifica(r.tratti[a].vicini.is_empty() and r.tratti[b].vicini.is_empty(), "Quote incompatibili non devono collegarsi.")
	# Strada, rampa di ponte e impalcato: punti condivisi per auto e pedoni.
	var strada := _posa_modello("ROAD_LOCAL_1x1_STRAIGHT", Vector2i(60, 61))
	var rampa := _posa_modello("BRG_LOCAL_RAMP_1x1_UP_050", Vector2i(60, 60))
	var ponte := _posa_modello("BRG_LOCAL_DECK_1x1_STRAIGHT", Vector2i(60, 59), 0, 1)
	r.ricostruisci(griglia, catalogo, costruzioni)
	verifica(r.tratti[rampa].vicini.get(0) == strada and r.tratti[rampa].vicini.get(2) == ponte, "Rampa di ponte collegata ai livelli corretti.")
	for coppia in [[strada, 2, rampa, 0], [rampa, 2, ponte, 0]]:
		for lato in [-1, 1]:
			var fine := r._bordo_pedonale(coppia[0], coppia[1], lato)
			var inizio := r._bordo_pedonale(coppia[2], coppia[3], -lato)
			verifica(fine.distance_to(inizio) < .001, "Continuita dei pedoni fra strada e ponte.")
	for p in griglia.piazzamenti():
		griglia.rimuovi(p.ancora)
	costruzioni.clear()


func _prova_percorsi() -> void:
	for id in traffico.rete.tratti:
		var t: Dictionary = traffico.rete.tratti[id]
		for entrata in t.porti:
			for lato in [-1, 1]:
				var uscita := traffico.rete.uscita_pedone(id, entrata, lato)
				var curva := traffico.rete.percorso(id, entrata, uscita, lato)
				for campione in 40:
					var p := curva.sample_baked(curva.get_baked_length() * campione / 39.0) - Vector3(t.centro)
					var su_asfalto := absf(p.x) < .47 and absf(p.z) < .47
					for d in t.porti:
						var asse: Vector3 = ReteTraffico.DIR[d]
						if p.dot(asse) > 0 and absf(p.dot(asse.cross(Vector3.UP))) < .47:
							su_asfalto = true
					verifica(not su_asfalto, "Pedone fuori dal marciapiede.")
			for uscita in t.vicini:
				if uscita == entrata:
					continue
				var curva := traffico.rete.percorso(id, entrata, uscita)
				var next: int = t.vicini[uscita]
				var uscite := traffico.rete.uscite(next, posmod(uscita + 2, 4))
				var c2 := traffico.rete.percorso(next, posmod(uscita + 2, 4), -1 if uscite.is_empty() else uscite[0])
				verifica(curva.sample_baked(curva.get_baked_length()).distance_to(c2.sample_baked(0)) < .001, "Continuita fra corsie.")


func _anteprima() -> void:
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("b9c6c7")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color.WHITE
	ambiente.environment.ambient_light_energy = .6
	add_child(ambiente)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, -35, 0)
	sole.light_energy = 1.2
	add_child(sole)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(13, 18, 19)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.current = true
	for _i in 12:
		traffico._popola()
	for _i in 180:
		traffico.avanza(1.0 / 60.0)
	traffico._disegna()
	traffico.set_process(true)
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://assets/previews/vehicles/traffic_in_game.png")
	print("TRAFFIC_PREVIEW_OK")
	get_tree().quit()
