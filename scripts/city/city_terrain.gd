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

class_name CityTerrain
extends RefCounted
## Il terreno procedurale: quote a gradini, biomi e fiumi, tutto da un seme.
##
## Le quote sono discrete, non continue. In un mondo a griglia dare a ogni cella
## una quota intera fa sì che un edificio appoggi in piano senza compenetrare il
## suolo, e rende immediato dire se un lotto è pianeggiante. Un terreno liscio
## costringerebbe a deformare o a sollevare ogni singolo edificio.
##
## Del terreno non si salva niente se non il seme: si rigenera identico.

enum Bioma { MARE, LAGO, FIUME, SPIAGGIA, PIANURA, COLLINA }

## Altezza di un gradino, in metri. Una cella è 2 x 2 m (vedi CityGrid).
const PASSO_QUOTA := 0.5
const LIVELLO_MASSIMO := 9
## Fin qui è sott'acqua.
const LIVELLO_MARE := 3
const LIMITE_SPIAGGIA := 4
const LIMITE_PIANURA := 6

const FIUMI := 3
const LUNGHEZZA_MINIMA_FIUME := 8
## Quante celle può allagare al massimo la conca in cui muore un fiume.
const AMPIEZZA_MASSIMA_LAGO := 14

const VICINI: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var size: Vector2i
var seme: int
var livelli: PackedInt32Array
var biomi: PackedByteArray
## Quota in metri del pelo dell'acqua, cella per cella. Zero sulla terraferma.
var quota_acqua: PackedFloat32Array


func _init(dimensione: Vector2i, seme_iniziale: int) -> void:
	size = dimensione
	seme = seme_iniziale
	_genera()


# --- Interrogazioni ---------------------------------------------------------

func dentro(cella: Vector2i) -> bool:
	return cella.x >= 0 and cella.y >= 0 and cella.x < size.x and cella.y < size.y


func indice(cella: Vector2i) -> int:
	return cella.y * size.x + cella.x


func livello(cella: Vector2i) -> int:
	if not dentro(cella):
		return 0
	return livelli[indice(cella)]


func bioma(cella: Vector2i) -> Bioma:
	if not dentro(cella):
		return Bioma.MARE
	return biomi[indice(cella)] as Bioma


## Quota in metri della faccia superiore della cella.
func quota(cella: Vector2i) -> float:
	return float(livello(cella)) * PASSO_QUOTA


func e_acqua(cella: Vector2i) -> bool:
	var b := bioma(cella)
	return b == Bioma.MARE or b == Bioma.LAGO or b == Bioma.FIUME


func costruibile(cella: Vector2i) -> bool:
	return dentro(cella) and not e_acqua(cella)


## Un lotto va bene se è tutto asciutto, dentro i bordi e a una quota sola.
func lotto_piano(celle: Array[Vector2i]) -> bool:
	if celle.is_empty():
		return false
	var riferimento := livello(celle[0])
	for cella in celle:
		if not costruibile(cella) or livello(cella) != riferimento:
			return false
	return true


## Livella un lotto e restituisce la quota scelta.
##
## Senza un livello esplicito usa la mediana delle celle, che regge meglio della
## media quando il lotto prende in mezzo un dirupo.
func spiana(celle: Array[Vector2i], livello_scelto: int = -1) -> int:
	if celle.is_empty():
		return 0
	var scelto := livello_scelto
	if scelto < 0:
		var quote: Array[int] = []
		for cella in celle:
			if dentro(cella):
				quote.append(livello(cella))
		if quote.is_empty():
			return 0
		quote.sort()
		scelto = quote[quote.size() / 2]
	scelto = maxi(scelto, LIVELLO_MARE + 1)
	for cella in celle:
		if not dentro(cella):
			continue
		var i := indice(cella)
		livelli[i] = scelto
		quota_acqua[i] = 0.0
		biomi[i] = Bioma.PIANURA if scelto <= LIMITE_PIANURA else Bioma.COLLINA
	return scelto


# --- Generazione ------------------------------------------------------------

func _genera() -> void:
	var celle := size.x * size.y
	livelli = PackedInt32Array()
	livelli.resize(celle)
	biomi = PackedByteArray()
	biomi.resize(celle)
	quota_acqua = PackedFloat32Array()
	quota_acqua.resize(celle)

	_rilievo()
	_appiana_asperita()
	_classifica_acque()
	_scava_fiumi()
	_assegna_biomi_terrestri()
	_calcola_quote_acqua()


## Rumore frattale smorzato verso i bordi, così la terra sta al centro e il mare
## circonda la mappa invece di essere tagliato di netto dal bordo.
func _rilievo() -> void:
	var rumore := FastNoiseLite.new()
	rumore.seed = seme
	rumore.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rumore.frequency = 0.045
	rumore.fractal_octaves = 4
	rumore.fractal_lacunarity = 2.1

	var centro := Vector2(float(size.x - 1) * 0.5, float(size.y - 1) * 0.5)
	var raggio := minf(centro.x, centro.y)

	for z in size.y:
		for x in size.x:
			var n := (rumore.get_noise_2d(float(x), float(z)) + 1.0) * 0.5
			var distanza := Vector2(float(x), float(z)).distance_to(centro) / maxf(1.0, raggio)
			var smorzamento := clampf(1.0 - pow(distanza * 0.78, 3.0), 0.0, 1.0)
			var h := clampf(n * 1.55 * smorzamento, 0.0, 1.0)
			livelli[z * size.x + x] = int(round(h * float(LIVELLO_MASSIMO)))


## Toglie le guglie da una cella sola: se una cella non è alla stessa quota di
## nessuno dei suoi vicini, si allinea alla loro mediana.
##
## Quantizzare del rumore continuo produce un mosaico pieno di scalini isolati:
## brutto da vedere e, soprattutto, pieno di lotti che non sono pianeggianti.
func _appiana_asperita() -> void:
	var copia := livelli.duplicate()
	for z in size.y:
		for x in size.x:
			var cella := Vector2i(x, z)
			var mia := livelli[indice(cella)]
			var intorno: Array[int] = []
			var uguale := false
			for passo in VICINI:
				var vicino := cella + passo
				if not dentro(vicino):
					continue
				var q := livelli[indice(vicino)]
				intorno.append(q)
				if q == mia:
					uguale = true
			if uguale or intorno.size() < 3:
				continue
			intorno.sort()
			copia[indice(cella)] = intorno[intorno.size() / 2]
	livelli = copia


## Separa mare e lago: è mare l'acqua che si raggiunge partendo dal bordo mappa.
## Quello che resta sotto il livello del mare ma è chiuso da terra è un lago.
func _classifica_acque() -> void:
	for i in livelli.size():
		biomi[i] = Bioma.LAGO if livelli[i] <= LIVELLO_MARE else Bioma.PIANURA

	var coda: Array[Vector2i] = []
	for x in size.x:
		coda.append(Vector2i(x, 0))
		coda.append(Vector2i(x, size.y - 1))
	for z in size.y:
		coda.append(Vector2i(0, z))
		coda.append(Vector2i(size.x - 1, z))

	var visti := {}
	while not coda.is_empty():
		var cella: Vector2i = coda.pop_back()
		if visti.has(cella) or not dentro(cella):
			continue
		var i := indice(cella)
		if biomi[i] != Bioma.LAGO:
			continue
		visti[cella] = true
		biomi[i] = Bioma.MARE
		for passo in VICINI:
			coda.append(cella + passo)


## Ogni fiume parte da una cella alta e scende verso il vicino più basso.
##
## Su un terreno a gradini la discesa stretta si ferma al primo pianoro, quindi
## a parità di quota il corso prosegue di lato invece di arrendersi. Se finisce
## comunque in un avvallamento chiuso, quell'avvallamento diventa un lago:
## è come si comporta l'acqua vera, e regala i laghi senza inventarli a mano.
func _scava_fiumi() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme + 977

	var sorgenti: Array[Vector2i] = []
	for z in size.y:
		for x in size.x:
			var cella := Vector2i(x, z)
			if livello(cella) > LIMITE_PIANURA:
				sorgenti.append(cella)
	if sorgenti.is_empty():
		return

	var scavati := 0
	var tentativi := 0
	while scavati < FIUMI and tentativi < FIUMI * 20:
		tentativi += 1
		var cella: Vector2i = sorgenti[rng.randi_range(0, sorgenti.size() - 1)]
		var percorso: Array[Vector2i] = []
		var visti := {}
		var sfociato := false
		while true:
			if not dentro(cella) or visti.has(cella):
				break
			visti[cella] = true
			if e_acqua(cella):
				sfociato = true
				break
			percorso.append(cella)
			var prossima := _passo_a_valle(cella, visti, rng)
			if prossima == cella:
				break
			cella = prossima

		if percorso.size() < LUNGHEZZA_MINIMA_FIUME:
			continue
		for c in percorso:
			var i := indice(c)
			biomi[i] = Bioma.FIUME
			livelli[i] = maxi(livelli[i] - 1, LIVELLO_MARE)
		if not sfociato:
			_allaga(percorso[percorso.size() - 1])
		scavati += 1


## Il passo successivo del corso d'acqua: il vicino più basso se c'è, altrimenti
## uno alla stessa quota non ancora attraversato, altrimenti nessuno.
func _passo_a_valle(cella: Vector2i, visti: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var mia_quota := livello(cella)
	var piu_basso := cella
	var quota_minima := mia_quota
	var pari: Array[Vector2i] = []
	for passo in VICINI:
		var vicino := cella + passo
		if not dentro(vicino) or visti.has(vicino):
			continue
		var q := livello(vicino)
		if q < quota_minima:
			quota_minima = q
			piu_basso = vicino
		elif q == mia_quota:
			pari.append(vicino)
	if piu_basso != cella:
		return piu_basso
	if not pari.is_empty():
		return pari[rng.randi_range(0, pari.size() - 1)]
	return cella


## Trasforma in lago la conca in cui si è fermato un fiume.
func _allaga(centro: Vector2i) -> void:
	var quota_lago := livello(centro)
	var coda: Array[Vector2i] = [centro]
	var visti := {}
	var allagate := 0
	while not coda.is_empty() and allagate < AMPIEZZA_MASSIMA_LAGO:
		var cella: Vector2i = coda.pop_front()
		if visti.has(cella) or not dentro(cella):
			continue
		if livello(cella) > quota_lago:
			continue
		visti[cella] = true
		var i := indice(cella)
		if biomi[i] != Bioma.MARE:
			biomi[i] = Bioma.LAGO
			livelli[i] = quota_lago
			allagate += 1
		for passo in VICINI:
			coda.append(cella + passo)


func _vicino_piu_basso(cella: Vector2i) -> Vector2i:
	var migliore := cella
	var quota_migliore := livello(cella)
	for passo in VICINI:
		var vicino := cella + passo
		if not dentro(vicino):
			continue
		if livello(vicino) < quota_migliore:
			quota_migliore = livello(vicino)
			migliore = vicino
	return migliore


func _assegna_biomi_terrestri() -> void:
	for i in livelli.size():
		if biomi[i] == Bioma.MARE or biomi[i] == Bioma.LAGO or biomi[i] == Bioma.FIUME:
			continue
		if livelli[i] <= LIMITE_SPIAGGIA:
			biomi[i] = Bioma.SPIAGGIA
		elif livelli[i] <= LIMITE_PIANURA:
			biomi[i] = Bioma.PIANURA
		else:
			biomi[i] = Bioma.COLLINA


## Mare e laghi stanno tutti alla stessa quota; un fiume invece scende a gradini
## seguendo il proprio letto, col pelo dell'acqua poco sopra il fondo.
func _calcola_quote_acqua() -> void:
	var quota_mare := float(LIVELLO_MARE) * PASSO_QUOTA
	for i in livelli.size():
		match biomi[i]:
			Bioma.MARE:
				quota_acqua[i] = quota_mare
			Bioma.LAGO, Bioma.FIUME:
				# Un bacino sotto il livello del mare è tutt'uno col mare; uno in
				# collina sta alla propria quota, col pelo poco sopra il fondo.
				quota_acqua[i] = maxf(quota_mare, float(livelli[i]) * PASSO_QUOTA + PASSO_QUOTA * 0.55)
			_:
				quota_acqua[i] = 0.0
