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

## PRATERIA è la pianura al riparo, dove piove meno: si costruisce come sulla
## pianura, ma non è verde, e serve a far vedere che il clima non dipende solo
## da quanto si è in alto.
##
## Il mare non c'è: le distese grandi sono laghi grandi. La vecchia definizione
## — è mare l'acqua che si tocca partendo dal bordo mappa — in un mondo senza
## bordo non vuol dire niente, e ogni modo di salvarla voleva una soglia
## inventata che il giocatore non può vedere. Un lago e un mare si comportavano
## già allo stesso modo: stessa quota, stessi ponti, stesso badile. L'unica
## differenza vera era il colore.
enum Bioma { LAGO, FIUME, SPIAGGIA, PIANURA, COLLINA, PRATERIA }

## Altezza di un gradino, in metri. Una cella è 2 x 2 m (vedi CityGrid).
const PASSO_QUOTA := 0.5
const LIVELLO_MASSIMO := 9
## Fin qui è sott'acqua. È la quota di riferimento di tutta l'acqua bassa: le
## distese sotto questo livello stanno tutte allo stesso pelo, che siano
## attaccate fra loro o no.
const LIVELLO_ACQUA := 3
const LIMITE_SPIAGGIA := 4
const LIMITE_PIANURA := 6

## Il reticolo idrografico sta su una griglia rada: un nodo ogni PASSO_FIUMI
## celle. È sessantaquattro volte più piccolo della mappa vera, quindi ci si può
## permettere di guardarne un pezzo grande — abbastanza da far scendere un fiume
## per centinaia di celle — al prezzo di qualche migliaio di nodi.
const PASSO_FIUMI := 8
## Quanti nodi radi ha una tessera del reticolo, e quanti se ne guardano attorno
## per sapere quanta acqua le arriva da fuori. Ogni nodo appartiene a una
## tessera sola: è quello che rende la risposta indipendente da chi l'ha
## chiesta.
const TESSERA_FIUMI := 32
const MARGINE_FIUMI := 24
## Quanti nodi devono drenare in un nodo perché lì ci sia un fiume. Più alta, e
## restano solo i corsi grandi; più bassa, e il mondo si riempie di rigagnoli.
const SOGLIA_FIUME := 40
## Di quanto il riempimento deve aver alzato un nodo perché lì ci sia una conca
## vera e non il pelo che serve a dare una pendenza a un pianoro.
const CONCA_MINIMA := 0.004
## Quante celle può allagare al massimo la conca in cui muore un fiume.
const AMPIEZZA_MASSIMA_LAGO := 14

## Quanti gradini possono separare due celle vicine. Oltre, il terreno non è
## più un paesaggio ma una scacchiera di torri.
const DISLIVELLO_MASSIMO := 4

## Il salto oltre il quale una parete frana. L'erosione termica fa quello che fa
## la gravità in mille anni: sbriciola gli strapiombi e appoggia il materiale
## sotto, e da un mosaico di scalini vengono fuori dei versanti.
const TALUS := 2
const PASSATE_EROSIONE := 3

## Sotto questa umidità la pianura è prateria invece che prato. Non è una soglia
## fisica: è dove il verde comincia a sembrare fuori posto.
const UMIDITA_SECCA := 0.46

## Segna una cella che non ha un'etichetta da ricordare.
const SENZA_ETICHETTA := 255

## Quanto è largo un blocco di generazione. È anche la misura della zona che si
## compra, e non per caso: la zona è l'unità che il giocatore vede comparire, e
## generare esattamente quella evita di tenere in vita mezze zone.
const BLOCCO := 32

## Quante celle di margine servono per generare un blocco senza sapere niente di
## quello che gli sta attorno.
##
## Il conto lo fa l'erosione. Una passata propaga di **due** celle e non di una:
## una cella cambia perché è franata lei, oppure perché le è franato addosso un
## vicino — e quel vicino ha deciso guardando i propri vicini, che stanno a due
## passi da qui. Tre passate fanno sei, l'appianamento ne aggiunge una: sette.
## Otto è il numero tondo sopra, e su un blocco da trentadue costa un anello di
## celle in più, non un ordine di grandezza.
##
## Se il margine bastasse, il blocco viene identico comunque lo si chieda. Non è
## una speranza: è la verifica che gira in `_prova_blocchi`, che genera il mondo
## a blocchi e in un pezzo solo e pretende le stesse quote cella per cella.
const MARGINE := 8

## Sopra questa massa del rumore del continente comincia la terra.
const SOGLIA_TERRA := 0.22

## L'oceano: dove il rumore a grandissima scala sta sotto il taglio, la terra
## non emerge comunque il continente si sforzi.
##
## È l'erede della discesa verso i bordi della mappa. Quella garantiva l'acqua
## tutto attorno perché sapeva dov'era il bordo; questa non lo sa e non le serve,
## perché fa la stessa cosa — modulare la massa a scala molto più grande del
## continente — con una funzione delle sole coordinate. La frequenza è sette
## volte più bassa di quella del continente: un bacino misura centinaia di celle,
## cioè parecchie zone, e non lo si scambia per un lago.
const OCEANO_FREQUENZA := 0.004
const OCEANO_TAGLIO := 0.30
const OCEANO_SFUMATURA := 0.25

const VICINI: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var size: Vector2i
var seme: int
var livelli: PackedInt32Array
var biomi: PackedByteArray
## Quota in metri del pelo dell'acqua, cella per cella. Zero sulla terraferma.
var quota_acqua: PackedFloat32Array
## Quanto piove su ogni cella, da 0 a 1. Non si salva e non si mostra: serve
## solo a decidere il bioma insieme alla quota, ed è il motivo per cui due
## pianure alla stessa altezza possono essere una verde e una secca.
var umidita: PackedFloat32Array

## Com'era il terreno appena uscito dal seme, prima che ci costruissero sopra.
## Serve a dire quali celle sono state modellate davvero: sono quelle, e solo
## quelle, che vanno scritte nel salvataggio.
var _naturale: PackedInt32Array = PackedInt32Array()

## Le tessere del reticolo idrografico gia' calcolate: chiave -> { nodo -> nodo
## a valle }. Si tengono perche' un blocco ne interroga sempre le stesse due o
## tre, e calcolarne una costa un ordinamento di qualche migliaio di nodi.
var _tessere_fiumi: Dictionary = {}

## L'acqua che il flood fill non saprebbe rimettere al suo posto: i fiumi, che
## scorrono anche sopra il livello dell'acqua, e i laghi rimasti in collina.
##
## Le conche sotto il livello dell'acqua non stanno qui apposta: quelle si
## rideducono ogni volta da sole, ed è esattamente ciò che fa funzionare
## l'innalzamento di un fondale.
var _etichetta_naturale: PackedByteArray = PackedByteArray()


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
		return Bioma.LAGO
	return biomi[indice(cella)] as Bioma


## Quota in metri della faccia superiore della cella.
func quota(cella: Vector2i) -> float:
	return float(livello(cella)) * PASSO_QUOTA


func e_acqua(cella: Vector2i) -> bool:
	var b := bioma(cella)
	return b == Bioma.LAGO or b == Bioma.FIUME


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


## La quota a cui va spianato un lotto: la più bassa fra le celle che occupa,
## mai sotto il livello dell'acqua.
##
## Livellare al minimo invece che alla mediana ha una conseguenza comoda: un
## oggetto che sta in una cella sola trova il terreno già a quella quota e non
## lo tocca. Il suolo si muove solo dove serve davvero, cioè sotto le
## costruzioni larghe che prendono in mezzo un gradino.
func livello_piu_basso(celle: Array[Vector2i]) -> int:
	var minimo := LIVELLO_MASSIMO
	for cella in celle:
		if dentro(cella):
			minimo = mini(minimo, livello(cella))
	return maxi(minimo, LIVELLO_ACQUA + 1)


## Porta una cella a una quota, senza rifare biomi e acque: chi la chiama
## chiude con riclassifica(), così una modifica di venti celle rifà i conti una
## volta sola invece di venti.
func imposta_livello(cella: Vector2i, livello_nuovo: int) -> void:
	if not dentro(cella):
		return
	livelli[indice(cella)] = clampi(livello_nuovo, 0, LIVELLO_MASSIMO)


## Rifà biomi e acque su tutta la mappa a partire dalle quote di adesso.
##
## Una cella tornata alla quota del seme si riprende la propria etichetta: un
## fiume ridiventa fiume. Una cella modellata invece la perde, e cosa diventa lo
## decide la sola quota — che è quello che rende gratis due casi: la conca
## scavata sotto il livello dell'acqua si riempie, e il fondale alzato sopra il
## pelo dell'acqua diventa un'isola.
##
## Da quando il mare non esiste più non c'è nemmeno il terzo caso, il canale che
## collegava una conca alla costa: la conca era già acqua allo stesso pelo prima
## di essere collegata, e scavare il canale adesso non cambia un'etichetta ma
## unisce due specchi d'acqua che stavano già alla stessa altezza. Si vede
## uguale, e costa un flood fill su tutta la mappa in meno.
func riclassifica() -> void:
	for i in livelli.size():
		var etichetta := _etichetta_naturale[i] if livelli[i] == _naturale[i] else SENZA_ETICHETTA
		if etichetta != SENZA_ETICHETTA:
			biomi[i] = etichetta
		else:
			biomi[i] = Bioma.LAGO if livelli[i] <= LIVELLO_ACQUA else Bioma.PIANURA
	_assegna_biomi_terrestri()
	_calcola_quote_acqua()


## Se portare una cella a quella quota lascerebbe un salto troppo alto con
## qualche vicina. I dirupi ci stanno, i grattacieli di terra no.
func dislivello_accettabile(cella: Vector2i, livello_nuovo: int) -> bool:
	for passo in VICINI:
		var vicina := cella + passo
		if dentro(vicina) and absi(livello_nuovo - livello(vicina)) > DISLIVELLO_MASSIMO:
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
	scelto = maxi(scelto, LIVELLO_ACQUA + 1)
	for cella in celle:
		imposta_livello(cella, scelto)
	riclassifica()
	return scelto


## Una fotografia di quello che del terreno si vede: quote, biomi e pelo
## dell'acqua. Confrontarne due dice quali celle vanno ridisegnate.
##
## Serve perché una modifica non si ferma dove la si fa: riclassifica() rifa i
## conti su tutta la mappa, e un canale scavato qui può spostare una riva
## dall'altra parte del mondo. Le celle toccate a mano non sono l'elenco di
## quelle cambiate.
func fotografia() -> Dictionary:
	return {
		"livelli": livelli.duplicate(),
		"biomi": biomi.duplicate(),
		"quota_acqua": quota_acqua.duplicate(),
	}


## Le celle che si vedono diverse da come stavano nella fotografia.
func celle_cambiate(prima: Dictionary) -> Array[Vector2i]:
	var cambiate: Array[Vector2i] = []
	if prima.is_empty():
		return cambiate
	var quote: PackedInt32Array = prima["livelli"]
	var etichette: PackedByteArray = prima["biomi"]
	var acque: PackedFloat32Array = prima["quota_acqua"]
	if quote.size() != livelli.size():
		return cambiate
	for i in livelli.size():
		if livelli[i] == quote[i] and biomi[i] == etichette[i] 				and is_equal_approx(quota_acqua[i], acque[i]):
			continue
		cambiate.append(Vector2i(i % size.x, i / size.x))
	return cambiate


## La quota che il seme aveva dato a questa cella, prima che ci si costruisse.
## Confrontarla con quella di adesso dice se la cella è stata spianata.
func livello_naturale(cella: Vector2i) -> int:
	if not dentro(cella):
		return 0
	return _naturale[indice(cella)]


## Quanta terra emersa c'è in un riquadro, da 0 a 1, guardando il solo rilievo:
## niente erosione, niente fiumi, nessun array del mondo. L'erosione sposta i
## gradini ma non fa emergere un continente, quindi per la domanda «qui c'è da
## costruire?» il rilievo grezzo basta e costa mille volte meno.
##
## Serve a scegliere dove far cominciare una città. Da quando l'oceano è un
## rumore a grande scala invece di una discesa verso i bordi, un punto qualunque
## può capitare in mezzo all'acqua, e piazzarci la prima zona vorrebbe dire dare
## al giocatore una partita da buttare.
static func frazione_di_terra(seme: int, riquadro: Rect2i) -> float:
	var quote := _rilievo(seme, riquadro)
	if quote.is_empty():
		return 0.0
	var asciutte := 0
	for q in quote:
		if q > LIVELLO_ACQUA:
			asciutte += 1
	return float(asciutte) / float(quote.size())


# --- Generazione ------------------------------------------------------------

func _genera() -> void:
	var celle := size.x * size.y
	livelli = PackedInt32Array()
	livelli.resize(celle)
	biomi = PackedByteArray()
	biomi.resize(celle)
	quota_acqua = PackedFloat32Array()
	quota_acqua.resize(celle)
	umidita = PackedFloat32Array()
	umidita.resize(celle)

	# Il mondo nasce un blocco per volta, ognuno col suo margine, anche se qui
	# sarebbe ancora possibile farlo tutto insieme: è il modo in cui dovrà
	# nascere quando i blocchi arriveranno uno alla volta, e farlo già adesso
	# vuol dire che la strada è quella verificata e non quella immaginata.
	for bz in range(0, size.y, BLOCCO):
		for bx in range(0, size.x, BLOCCO):
			_genera_blocco(Rect2i(bx, bz,
				mini(BLOCCO, size.x - bx), mini(BLOCCO, size.y - bz)))
	_assegna_biomi_terrestri()
	_calcola_quote_acqua()

	_naturale = livelli.duplicate()
	_aggiorna_etichette()

	# La classificazione ha l'ultima parola anche qui, non solo dopo. Fiumi e
	# laghi vengono scavati a valle della prima, e le quote che si muovono
	# scavandoli cambiano cosa sta sotto il pelo dell'acqua. Passare di qui
	# adesso fa sì che il mondo appena nato sia già quello che si otterrebbe
	# riclassificandolo: senza, il primo colpo di badile andrebbe a cambiare
	# qualche cella lontana da dove si è scavato.
	riclassifica()
	_aggiorna_etichette()


## Fotografa l'acqua che il flood fill non saprebbe rimettere al suo posto.
func _aggiorna_etichette() -> void:
	_etichetta_naturale = PackedByteArray()
	_etichetta_naturale.resize(livelli.size())
	for i in livelli.size():
		var b := biomi[i]
		var da_ricordare := b == Bioma.FIUME or (b == Bioma.LAGO and livelli[i] > LIVELLO_ACQUA)
		_etichetta_naturale[i] = b if da_ricordare else SENZA_ETICHETTA


## Il rilievo, da tre rumori che fanno tre mestieri diversi.
##
## Il primo disegna la **forma del continente**: dove finisce la terra e comincia
## l'acqua. Prima era un cerchio — una distanza dal centro — e si vedeva: la
## costa era una curva di livello. Adesso è del rumore a bassa frequenza,
## moltiplicato per una discesa verso i bordi che serve solo a garantire che
## l'acqua chiuda la mappa: dentro quel vincolo la costa fa promontori e
## insenature per conto suo. Quella discesa è l'ultima cosa che guarda il bordo
## della mappa, e il giorno del mondo infinito dovrà andarsene anche lei.
##
## Il secondo fa le **colline**: rumore frattale normale, morbido, che riempie
## l'entroterra di alti e bassi.
##
## Il terzo fa le **creste**: rumore ridged, che invece di colline tonde produce
## dorsali che si diramano. Pesa quanto è alta la cella — in riva all'acqua non se
## ne accorge nessuno, in cima cambia tutto — ed è quello che distingue un
## paesaggio da un mucchio di dossi.
## I quattro rumori del rilievo, costruiti una volta sola.
static func _rumori(seme: int) -> Array:
	var oceano := FastNoiseLite.new()
	oceano.seed = seme + 15013
	oceano.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	oceano.frequency = OCEANO_FREQUENZA
	oceano.fractal_octaves = 2

	var continente := FastNoiseLite.new()
	continente.seed = seme
	continente.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continente.frequency = 0.028
	continente.fractal_octaves = 3

	var colline := FastNoiseLite.new()
	colline.seed = seme + 977
	colline.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	colline.frequency = 0.055
	colline.fractal_octaves = 4
	colline.fractal_lacunarity = 2.1

	var creste := FastNoiseLite.new()
	creste.seed = seme + 4231
	creste.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	creste.frequency = 0.07
	creste.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	creste.fractal_octaves = 4
	creste.fractal_lacunarity = 2.3

	return [oceano, continente, colline, creste]


## L'altezza continua in un punto, da 0 a 1. È la funzione che il terreno
## davvero è: dipende solo dal seme e dalle coordinate, non guarda nessun
## vicino, e non sa che esista una mappa.
##
## Continua e non a gradini perché il reticolo idrografico ha bisogno di sapere
## da che parte scende: su quote intere troverebbe pianori dappertutto e
## l'acqua non saprebbe dove andare.
static func _altezza(rumori: Array, punto: Vector2) -> float:
	# La terra c'è dove il rumore del continente sta sopra la sua soglia, e
	# sfuma dove ci sta appena sopra: è quello che fa le spiagge larghe e le
	# scogliere strette. L'oceano ha l'ultima parola: dove sta sotto il suo
	# taglio la massa va a zero, e lì la terra non emerge per quanto il
	# continente si sforzi.
	var massa: float = (rumori[1].get_noise_2dv(punto) + 1.0) * 0.5
	var emerso: float = (rumori[0].get_noise_2dv(punto) + 1.0) * 0.5
	massa *= clampf((emerso - OCEANO_TAGLIO) / OCEANO_SFUMATURA, 0.0, 1.0)
	var terra := clampf((massa - SOGLIA_TERRA) / 0.32, 0.0, 1.0)

	var dolce: float = (rumori[2].get_noise_2dv(punto) + 1.0) * 0.5
	var acuto: float = (rumori[3].get_noise_2dv(punto) + 1.0) * 0.5
	# Il fondale parte da 0,20 e la terra sale da lì: la costa cade dove la
	# somma passa il livello dell'acqua, e non su una curva di livello. Le
	# creste contano dove si è già in alto — pesano come il quadrato della terra
	# emersa — così le spiagge restano dolci e l'interno no.
	var h := 0.20 + terra * (0.36 + 0.28 * dolce) + terra * terra * 0.20 * acuto
	return clampf(h, 0.0, 1.0)


## Le quote a gradini di una finestra: l'altezza continua, quantizzata.
static func _rilievo(seme: int, finestra: Rect2i) -> PackedInt32Array:
	var rumori := _rumori(seme)
	var quote := PackedInt32Array()
	quote.resize(finestra.size.x * finestra.size.y)
	for z in finestra.size.y:
		for x in finestra.size.x:
			var punto := Vector2(
				float(finestra.position.x + x), float(finestra.position.y + z))
			quote[z * finestra.size.x + x] = int(
				round(_altezza(rumori, punto) * float(LIVELLO_MASSIMO)))
	return quote


## L'erosione termica: quello che la gravità fa in mille anni.
##
## Dove il salto verso il vicino più basso supera il talus, la parete frana: la
## cella scende di un gradino e quella sotto sale di uno, se le resta spazio. Il
## materiale non sparisce, si sposta — che è poi la differenza fra erodere e
## limare, e si vede: le valli si allargano verso il basso invece di restare
## incisioni a picco.
##
## Si lavora su una copia e si applica alla fine di ogni passata, altrimenti
## l'ordine di scansione conterebbe e il versante a est verrebbe diverso da
## quello a ovest.
##
## Fuori dalla finestra non si guarda: è lì che il margine si paga il posto,
## perché le celle sul bordo della finestra vengono sbagliate e vanno buttate.
static func _erosione(quote: PackedInt32Array, finestra: Rect2i) -> PackedInt32Array:
	var larghezza := finestra.size.x
	var altezza := finestra.size.y
	for _passata in PASSATE_EROSIONE:
		var dopo := quote.duplicate()
		for z in altezza:
			for x in larghezza:
				var i := z * larghezza + x
				var mia := quote[i]
				var giu := -1
				var minimo := mia
				for passo in VICINI:
					var vx := x + passo.x
					var vz := z + passo.y
					if vx < 0 or vz < 0 or vx >= larghezza or vz >= altezza:
						continue
					var j := vz * larghezza + vx
					if quote[j] < minimo:
						minimo = quote[j]
						giu = j
				if giu < 0 or mia - minimo <= TALUS:
					continue
				dopo[i] = dopo[i] - 1
				dopo[giu] = mini(dopo[giu] + 1, LIVELLO_MASSIMO)
		quote = dopo
	return quote


## Toglie le guglie da una cella sola: se una cella non è alla stessa quota di
## nessuno dei suoi vicini, si allinea alla loro mediana.
##
## Quantizzare del rumore continuo produce un mosaico pieno di scalini isolati:
## brutto da vedere e, soprattutto, pieno di lotti che non sono pianeggianti.
static func _appiana_asperita(quote: PackedInt32Array, finestra: Rect2i) -> PackedInt32Array:
	var larghezza := finestra.size.x
	var altezza := finestra.size.y
	var copia := quote.duplicate()
	for z in altezza:
		for x in larghezza:
			var i := z * larghezza + x
			var mia := quote[i]
			var intorno: Array[int] = []
			var uguale := false
			for passo in VICINI:
				var vx := x + passo.x
				var vz := z + passo.y
				if vx < 0 or vz < 0 or vx >= larghezza or vz >= altezza:
					continue
				var q := quote[vz * larghezza + vx]
				intorno.append(q)
				if q == mia:
					uguale = true
			if uguale or intorno.size() < 3:
				continue
			intorno.sort()
			copia[i] = intorno[intorno.size() / 2]
	return copia


## Quanto piove, cella per cella.
##
## Un rumore suo, più largo di quello delle colline perché il clima cambia più
## lentamente del terreno, corretto dalla quota: in alto piove di più, che è il
## motivo per cui le creste restano verdi e le conche interne no.
static func _pioggia(seme: int, quote: PackedInt32Array, finestra: Rect2i) -> PackedFloat32Array:
	var rumore := FastNoiseLite.new()
	rumore.seed = seme + 6421
	rumore.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rumore.frequency = 0.048
	rumore.fractal_octaves = 2
	var pioggia := PackedFloat32Array()
	pioggia.resize(quote.size())
	for z in finestra.size.y:
		for x in finestra.size.x:
			var i := z * finestra.size.x + x
			var n := (rumore.get_noise_2d(
				float(finestra.position.x + x), float(finestra.position.y + z)) + 1.0) * 0.5
			var alto := float(quote[i]) / float(LIVELLO_MASSIMO)
			pioggia[i] = clampf(n * 0.82 + alto * 0.22, 0.0, 1.0)
	return pioggia


## Genera quote e umidità di un riquadro senza sapere niente del resto del
## mondo: si lavora su una finestra più larga di MARGINE per lato, ci si fanno
## girare sopra i processi locali, e si tiene solo il centro.
##
## Costa: la finestra di un blocco da 32 ne misura 48, quindi si calcolano due
## celle e un quarto per ognuna che si tiene, e le celle di confine vengono
## calcolate una volta per ogni blocco che le guarda. È il prezzo del non dover
## cucire niente — perché non c'è niente da cucire: due blocchi vicini vedono la
## stessa cella e le danno lo stesso valore, avendo fatto lo stesso conto.
func _genera_blocco(riquadro: Rect2i) -> void:
	var margine := Vector2i(MARGINE, MARGINE)
	var finestra := Rect2i(riquadro.position - margine, riquadro.size + margine * 2)
	var quote := _rilievo(seme, finestra)
	quote = _erosione(quote, finestra)
	quote = _appiana_asperita(quote, finestra)
	var pioggia := _pioggia(seme, quote, finestra)

	# I fiumi arrivano dal reticolo rado invece che da una passeggiata sul
	# mondo: si chiede quali celle lo attraversano, e si scava lì. La domanda
	# non dipende da chi la fa — un nodo appartiene a una tessera sola — quindi
	# due blocchi vicini scavano lo stesso fiume nello stesso posto senza
	# doversi parlare.
	#
	# Si scava su tutta la finestra e non solo sul riquadro: il lago di una
	# conca appena fuori può entrare qui, e per allagarlo servono le quote già
	# scavate anche là fuori.
	var reticolo := _reticolo_sul_riquadro(finestra)
	var corsi: Dictionary = reticolo["celle"]
	for z in finestra.size.y:
		for x in finestra.size.x:
			var cella := finestra.position + Vector2i(x, z)
			var j := z * finestra.size.x + x
			# Il letto sta un gradino sotto la riva, e non scende mai sotto il
			# pelo dell'acqua: un fiume che arriva al lago ci finisce dentro,
			# non ci scava sotto.
			if corsi.has(cella) and quote[j] > LIVELLO_ACQUA:
				quote[j] = maxi(quote[j] - 1, LIVELLO_ACQUA)

	var laghi := {}
	for conca in reticolo["conche"]:
		_allaga(conca, quote, finestra, laghi)

	for z in riquadro.size.y:
		for x in riquadro.size.x:
			var cella := riquadro.position + Vector2i(x, z)
			if not dentro(cella):
				continue
			var locale := cella - finestra.position
			var j := locale.y * finestra.size.x + locale.x
			var i := indice(cella)
			umidita[i] = pioggia[j]
			if laghi.has(cella):
				livelli[i] = laghi[cella]
				biomi[i] = Bioma.LAGO
			elif corsi.has(cella) and quote[j] > LIVELLO_ACQUA:
				livelli[i] = quote[j]
				biomi[i] = Bioma.FIUME
			else:
				livelli[i] = quote[j]
				biomi[i] = Bioma.LAGO if quote[j] <= LIVELLO_ACQUA else Bioma.PIANURA


# --- Fiumi ------------------------------------------------------------------

## L'altezza continua sotto la quale una cella è già acqua. Il reticolo non
## traccia fiumi dentro un lago: ci arriva e si ferma.
const ALTEZZA_ACQUA := (float(LIVELLO_ACQUA) + 0.5) / float(LIVELLO_MASSIMO)

## Quanto pesa l'altezza del terreno, contro la distanza dalla meta, nello
## scegliere dove passa un tratto di fiume. Zero dà una linea retta; troppo alto
## dà un corso che gira in tondo e non arriva.
const PESO_TERRENO_CORSO := 45.0

## Quanto pesa, nell'altezza che guarda il reticolo, la massa grezza del
## continente.
##
## L'altezza vera ha dei pianori: dove la terra satura a uno, o dove l'oceano
## l'ha azzerata, la formula dà lo stesso numero per nodi lontanissimi. Su un
## pianoro ogni nodo è una conca e l'acqua non sa dove andare — misurato: il 38 %
## dei nodi senza sbocco, e nemmeno un fiume. La massa grezza non satura mai,
## quindi ridà una pendenza dove la formula l'aveva appiattita, e le conche
## scendono al 7 %. Il resto lo fa il riempimento.
const PESO_IDROGRAFICO := 0.25

## Le otto direzioni. Il reticolo scende in otto e non in quattro: a un nodo
## ogni otto celle, un corso vincolato agli assi verrebbe una scaletta, e si
## vedrebbe.
const OTTO_VICINI: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


## L'altezza che il reticolo idrografico guarda: quella vera più la massa
## grezza, che non satura. Non è la quota del terreno e non deve esserlo: serve
## solo a dire da che parte scende l'acqua, e dove il terreno scende davvero è
## il terreno a decidere, perché quel termine è piccolo e liscio.
static func _altezza_idrografica(rumori: Array, punto: Vector2) -> float:
	var massa: float = (rumori[1].get_noise_2dv(punto) + 1.0) * 0.5
	return _altezza(rumori, punto) + PESO_IDROGRAFICO * massa


## Un mucchio binario minimo su un Array di coppie [quota, indice].
##
## GDScript non ne ha uno e qui serve: il riempimento tira fuori sempre il nodo
## più basso fra qualche migliaio, e farlo con un ordinamento costerebbe un
## ordinamento per nodo. Un Array e non un PackedArray perché i primi si passano
## per riferimento, e questi due li si vuole modificare.
static func _mucchio_dentro(mucchio: Array, quota: float, indice: int) -> void:
	mucchio.append([quota, indice])
	var i := mucchio.size() - 1
	while i > 0:
		var padre := (i - 1) / 2
		if mucchio[padre][0] <= mucchio[i][0]:
			break
		var scambio: Array = mucchio[padre]
		mucchio[padre] = mucchio[i]
		mucchio[i] = scambio
		i = padre


static func _mucchio_fuori(mucchio: Array) -> Array:
	var primo: Array = mucchio[0]
	var ultimo: Array = mucchio.pop_back()
	if mucchio.is_empty():
		return primo
	mucchio[0] = ultimo
	var i := 0
	while true:
		var piccolo := i
		var sinistro := i * 2 + 1
		var destro := sinistro + 1
		if sinistro < mucchio.size() and mucchio[sinistro][0] < mucchio[piccolo][0]:
			piccolo = sinistro
		if destro < mucchio.size() and mucchio[destro][0] < mucchio[piccolo][0]:
			piccolo = destro
		if piccolo == i:
			break
		var scambio: Array = mucchio[i]
		mucchio[i] = mucchio[piccolo]
		mucchio[piccolo] = scambio
		i = piccolo
	return primo


## Riempie le depressioni, così che da ogni nodo l'acqua arrivi al bordo della
## finestra. È il priority-flood: si parte dal bordo, si tira fuori sempre il
## nodo più basso ancora da sistemare, e si alzano i suoi vicini almeno fino
## alla sua quota più un pelo.
##
## Senza, i corsi si spezzano alla prima conca e non raccolgono mai abbastanza
## da chiamarsi fiumi: misurato, accumulo massimo 19 su una soglia di 90. Di
## regalo, i nodi che il riempimento ha alzato davvero sono le conche chiuse —
## cioè i laghi — e non c'è bisogno di cercarli a parte.
static func _riempi_le_conche(altezze: PackedFloat32Array, lato: int) -> PackedFloat32Array:
	var pelo := 0.00001
	var riempite := altezze.duplicate()
	var visti := {}
	var mucchio: Array = []
	for z in lato:
		for x in lato:
			if x > 0 and z > 0 and x < lato - 1 and z < lato - 1:
				continue
			var i := z * lato + x
			visti[i] = true
			_mucchio_dentro(mucchio, riempite[i], i)

	while not mucchio.is_empty():
		var cima := _mucchio_fuori(mucchio)
		var quota: float = cima[0]
		var i: int = cima[1]
		var x := i % lato
		var z := i / lato
		for passo in OTTO_VICINI:
			var vx := x + passo.x
			var vz := z + passo.y
			if vx < 0 or vz < 0 or vx >= lato or vz >= lato:
				continue
			var j := vz * lato + vx
			if visti.has(j):
				continue
			visti[j] = true
			riempite[j] = maxf(riempite[j], quota + pelo)
			_mucchio_dentro(mucchio, riempite[j], j)
	return riempite


## La tessera del reticolo a cui appartiene un nodo. Ogni nodo ne ha una sola,
## ed è quello che rende il fiume una proprietà del posto e non della domanda.
static func _tessera_di(nodo: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(nodo.x) / float(TESSERA_FIUMI)),
		floori(float(nodo.y) / float(TESSERA_FIUMI)))


## I nodi di fiume di una tessera, ognuno col nodo a valle. Un nodo che non ha
## dove scendere sta a valle di sé stesso: è una conca, e lì il fiume muore.
func _fiumi_della_tessera(chiave: Vector2i) -> Dictionary:
	if _tessere_fiumi.has(chiave):
		return _tessere_fiumi[chiave]

	var lato := TESSERA_FIUMI + MARGINE_FIUMI * 2
	var origine := chiave * TESSERA_FIUMI - Vector2i(MARGINE_FIUMI, MARGINE_FIUMI)
	var rumori := _rumori(seme)
	# Due altezze per nodo: quella vera, che dice se lì c'è già acqua, e quella
	# idrografica, che dice da che parte scende.
	var vere := PackedFloat32Array()
	vere.resize(lato * lato)
	var idro := PackedFloat32Array()
	idro.resize(lato * lato)
	for z in lato:
		for x in lato:
			var nodo := origine + Vector2i(x, z)
			var punto := Vector2(
				float(nodo.x * PASSO_FIUMI), float(nodo.y * PASSO_FIUMI))
			vere[z * lato + x] = _altezza(rumori, punto)
			idro[z * lato + x] = _altezza_idrografica(rumori, punto)

	var riempite := _riempi_le_conche(idro, lato)

	# A valle: il vicino più basso fra gli otto. Otto e non quattro perché a un
	# nodo ogni otto celle un corso vincolato agli assi verrebbe una scaletta.
	# Dopo il riempimento un nodo interno ne ha sempre uno.
	var valle := PackedInt32Array()
	valle.resize(lato * lato)
	for z in lato:
		for x in lato:
			var i := z * lato + x
			var scelto := -1
			var minima := riempite[i]
			for passo in OTTO_VICINI:
				var vx := x + passo.x
				var vz := z + passo.y
				if vx < 0 or vz < 0 or vx >= lato or vz >= lato:
					continue
				var j := vz * lato + vx
				if riempite[j] < minima:
					minima = riempite[j]
					scelto = j
			valle[i] = scelto

	# L'area drenata. Si scende dal nodo più alto al più basso e ognuno passa a
	# valle quello che ha raccolto: una passata sola basta, perché un nodo non
	# può drenare in uno più alto di lui, e quando arriva il suo turno ha già
	# ricevuto tutto. È il pezzo che rende i fiumi grossi in fondo e piccoli in
	# cima senza doverlo dire.
	var ordine := range(lato * lato)
	ordine.sort_custom(func(a, b): return riempite[a] > riempite[b])
	var area := PackedInt32Array()
	area.resize(lato * lato)
	area.fill(1)
	for i in ordine:
		var g: int = valle[i]
		if g >= 0:
			area[g] += area[i]

	var a_valle := {}
	var conche := {}
	for z in range(MARGINE_FIUMI, MARGINE_FIUMI + TESSERA_FIUMI):
		for x in range(MARGINE_FIUMI, MARGINE_FIUMI + TESSERA_FIUMI):
			var i := z * lato + x
			if area[i] < SOGLIA_FIUME or vere[i] <= ALTEZZA_ACQUA:
				continue
			var nodo := origine + Vector2i(x, z)
			var g: int = valle[i]
			a_valle[nodo] = nodo if g < 0 else origine + Vector2i(g % lato, g / lato)
			# Un nodo che il riempimento ha alzato davvero sta **sotto il pelo**
			# di una conca chiusa: lì c'è un lago. Il fiume non si ferma per
			# questo — ci entra, lo attraversa e ne esce dall'emissario — ed è
			# l'errore che avevo fatto la prima volta: trattare ogni nodo alzato
			# come un capolinea spezzava tutti i corsi al primo avvallamento e
			# lasciava otto celle di fiume su un mondo intero.
			if riempite[i] - idro[i] > CONCA_MINIMA:
				conche[nodo] = true

	var tessera := { "a_valle": a_valle, "conche": conche }
	_tessere_fiumi[chiave] = tessera
	return tessera


## Le celle attraversate dai fiumi che passano per un riquadro, e le conche in
## cui muoiono.
##
## Si guardano i nodi del riquadro allargato di un passo, perché un tratto lungo
## un passo può entrare da fuori. Restituisce { celle_di_fiume, conche }.
func _reticolo_sul_riquadro(riquadro: Rect2i) -> Dictionary:
	var da := Vector2i(
		floori(float(riquadro.position.x - PASSO_FIUMI) / float(PASSO_FIUMI)),
		floori(float(riquadro.position.y - PASSO_FIUMI) / float(PASSO_FIUMI)))
	var a := Vector2i(
		floori(float(riquadro.end.x + PASSO_FIUMI) / float(PASSO_FIUMI)),
		floori(float(riquadro.end.y + PASSO_FIUMI) / float(PASSO_FIUMI)))

	var rumori := _rumori(seme)
	var celle := {}
	var conche: Array[Vector2i] = []
	for nx in range(da.x, a.x + 1):
		for nz in range(da.y, a.y + 1):
			var nodo := Vector2i(nx, nz)
			var tessera := _fiumi_della_tessera(_tessera_di(nodo))
			var a_valle: Dictionary = tessera["a_valle"]
			if not a_valle.has(nodo):
				continue
			var partenza := nodo * PASSO_FIUMI
			# Una conca si allaga solo se il suo centro sta dentro il riquadro
			# chiesto: più in là il lago non ci arriverebbe comunque, e allagare
			# a metà fuori vorrebbe dire dipendere da quanto in là si è guardato.
			if (tessera["conche"] as Dictionary).has(nodo) and riquadro.has_point(partenza):
				conche.append(partenza)
			for cella in _corso(rumori, partenza, (a_valle[nodo] as Vector2i) * PASSO_FIUMI):
				celle[cella] = true
	return { "celle": celle, "conche": conche }


## Il tratto di fiume fra due nodi del reticolo, cella per cella.
##
## Non un segmento dritto: a otto celle di distanza una diagonale perfetta non
## sembra un fiume, sembra un righello — e si vede, l'ho guardata. Si cammina
## dal nodo di monte a quello di valle scegliendo a ogni passo il vicino che
## costa meno: la sua altezza più quanto resta da fare. Così il corso aggira i
## dossi e ci arriva lo stesso.
##
## Non si torna indietro e non ci si allontana mai dalla meta, quindi il
## cammino finisce sempre. E dipende solo dai due nodi e dall'altezza, che è
## una funzione delle coordinate: due blocchi che vedono lo stesso tratto lo
## tracciano uguale senza doversi parlare.
static func _corso(rumori: Array, da: Vector2i, a: Vector2i) -> Array[Vector2i]:
	var celle: Array[Vector2i] = [da]
	var visti := { da: true }
	var punto := da
	var resta := _lontananza(punto, a)
	var tetto := resta * 3 + 2
	while punto != a and celle.size() < tetto:
		var migliore := punto
		var costo_migliore := INF
		for passo in OTTO_VICINI:
			var prossimo: Vector2i = punto + passo
			if visti.has(prossimo):
				continue
			var quanto := _lontananza(prossimo, a)
			if quanto > resta:
				continue
			var costo := _altezza(rumori, Vector2(prossimo)) * PESO_TERRENO_CORSO 				+ float(quanto)
			if costo < costo_migliore:
				costo_migliore = costo
				migliore = prossimo
		if migliore == punto:
			break
		punto = migliore
		resta = _lontananza(punto, a)
		visti[punto] = true
		celle.append(punto)
	return celle


## La distanza di Chebyshev: quanti passi in otto direzioni servono ad arrivare.
static func _lontananza(da: Vector2i, a: Vector2i) -> int:
	return maxi(absi(a.x - da.x), absi(a.y - da.y))


## Allaga la conca in cui muore un fiume, scrivendo in `laghi` la quota del pelo
## per ogni cella coperta.
##
## Si lavora sulle quote della finestra e non su quelle del mondo: quando un
## blocco si genera, i blocchi accanto possono non esistere ancora, e leggere di
## là darebbe risposte diverse a seconda dell'ordine in cui sono nati.
##
## L'allagamento parte dal nodo del reticolo e non da dove è arrivata una
## passeggiata: è ancorato a un punto che dipende dal solo seme, quindi due
## blocchi che vedono la stessa conca ne allagano le stesse celle. Il tetto di
## AMPIEZZA_MASSIMA_LAGO tiene il lago dentro il margine con cui la finestra è
## stata generata.
func _allaga(centro: Vector2i, quote: PackedInt32Array, finestra: Rect2i,
		laghi: Dictionary) -> void:
	if not finestra.has_point(centro):
		return
	var locale := centro - finestra.position
	var quota_lago := quote[locale.y * finestra.size.x + locale.x]
	if quota_lago <= LIVELLO_ACQUA:
		return
	var coda: Array[Vector2i] = [centro]
	var visti := {}
	var allagate := 0
	while not coda.is_empty() and allagate < AMPIEZZA_MASSIMA_LAGO:
		var cella: Vector2i = coda.pop_front()
		if visti.has(cella) or not finestra.has_point(cella):
			continue
		var l := cella - finestra.position
		if quote[l.y * finestra.size.x + l.x] > quota_lago:
			continue
		visti[cella] = true
		allagate += 1
		laghi[cella] = quota_lago
		for passo in VICINI:
			coda.append(cella + passo)


func _assegna_biomi_terrestri() -> void:
	for i in livelli.size():
		if biomi[i] == Bioma.LAGO or biomi[i] == Bioma.FIUME:
			continue
		if livelli[i] <= LIMITE_SPIAGGIA:
			biomi[i] = Bioma.SPIAGGIA
		elif i < umidita.size() and umidita[i] < UMIDITA_SECCA:
			# L'umidità viene prima della quota, e non dopo: se contasse solo
			# sotto una certa altezza il mondo tornerebbe a essere colorato a
			# fasce, che è esattamente quello che si voleva togliere. Un versante
			# al riparo è secco che stia a cinque metri o a quaranta.
			biomi[i] = Bioma.PRATERIA
		elif livelli[i] > LIMITE_PIANURA:
			biomi[i] = Bioma.COLLINA
		else:
			biomi[i] = Bioma.PIANURA


## L'acqua bassa sta tutta alla stessa quota; un fiume invece scende a gradini
## seguendo il proprio letto, col pelo dell'acqua poco sopra il fondo.
func _calcola_quote_acqua() -> void:
	var quota_bassa := float(LIVELLO_ACQUA) * PASSO_QUOTA
	for i in livelli.size():
		match biomi[i]:
			Bioma.LAGO, Bioma.FIUME:
				# Un bacino sotto il livello dell'acqua sta al pelo comune; uno
				# in collina sta alla propria quota, poco sopra il fondo.
				quota_acqua[i] = maxf(quota_bassa, float(livelli[i]) * PASSO_QUOTA + PASSO_QUOTA * 0.55)
			_:
				quota_acqua[i] = 0.0
