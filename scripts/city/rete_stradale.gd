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


class_name ReteStradale
extends RefCounted
## Come si sceglie il pezzo di strada di una cella, e che forma ha un percorso.
##
## Sta fuori da CityView di proposito. La tabella dei sedici casi — dalla
## maschera dei quattro vicini al modello e a quanto va girato — non è una
## faccenda di strade: è la stessa domanda che si faranno i muri e i ponti il
## giorno che si vorranno tracciare anche loro. Vale la pena che la risposta sia
## una funzione con un nome, e non un match sepolto dentro il piazzatore.
##
## Qui dentro non si tocca né la griglia né il terreno né il salvataggio: si
## risponde a domande di geometria. Chi paga, chi spiana e chi posa è CityView.


## Le quattro direzioni, nell'ordine dei bit della maschera: nord, est, sud,
## ovest. Il nord dei modelli guarda +z nel mondo, che in coordinate di griglia
## è +y — la y di un Vector2i di griglia è la profondità, non l'altezza.
const DIREZIONI: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
]

## Le braccia di ogni pezzo a rotazione zero.
##
## Sono i versi che gli ha dato la pipeline Blender (`ROAD_CONNECTIONS` in
## tools/blender/generate_mvp_assets.py) riletti nelle coordinate di Godot. Non
## sono stati dedotti: si è misurato dove arriva l'asfalto nei .glb veri, perché
## una tabella di sedici casi costruita su una convenzione sbagliata compila
## benissimo e mette curve al posto di incroci.
const BRACCIA := {
	"STRAIGHT": 0b0101,  # nord e sud
	"CORNER": 0b0011,  # nord ed est
	"T": 0b1011,  # nord, est e ovest
	"CROSS": 0b1111,
	"END": 0b0001,  # solo nord
}

## Il pezzo di una cella che non ha niente attaccato. Un dritto e non una
## testata: una strada isolata è un pezzo di strada, mentre la testata dice
## «di qui non si passa», e in mezzo al niente non è quello che si vuol dire.
const PEZZO_SOLITARIO := { "variante": "STRAIGHT", "rotazione": 0 }

## Le due strade che si tracciano, e come la pipeline nomina i loro pezzi.
##
## I nomi dei modelli stanno qui e non nel catalogo perché il catalogo descrive
## un pezzo per volta, e quello che serve a tracciare è la famiglia intera: dato
## un incrocio sterrato, la sua curva. Sono gli id di focus_asset_specs.py.
const FAMIGLIE := {
	"asfaltata": {
		"nome": "Strada asfaltata",
		"pezzo": "ROAD_LOCAL_1x1_%s",
		"rampa": "ROAD_LOCAL_SLOPE_1x1_UP_050",
	},
	"sterrata": {
		"nome": "Strada sterrata",
		"pezzo": "ROAD_DIRT_1x1_%s",
		"rampa": "ROAD_DIRT_SLOPE_1x1_UP_050",
	},
}

## L'id con cui una famiglia compare nel negozio. Non è un modello: è la voce
## che, invece di posare qualcosa, accende la modalità con cui si traccia.
const PREFISSO_VOCE := "STRADA_"

## Da maschera dei vicini a { variante, rotazione }. Si riempie alla prima
## domanda: sono sedici casi, e calcolarli costa meno che scriverli a mano.
static var _tabella: Dictionary = {}


# --- Geometria --------------------------------------------------------------

## Gira una direzione di griglia di `quarti` scatti di 90°, nello stesso verso
## in cui CityView gira un modello posato (rotation.y = -90° per scatto).
static func ruota(direzione: Vector2i, quarti: int) -> Vector2i:
	var girata := direzione
	for _i in posmod(quarti, 4):
		girata = Vector2i(-girata.y, girata.x)
	return girata


## L'indice di una direzione fra le quattro, cioè il suo bit nella maschera.
static func indice(direzione: Vector2i) -> int:
	return DIREZIONI.find(direzione)


## La maschera di un pezzo girato: ogni braccio finisce a guardare la direzione
## a cui la rotazione lo porta.
static func maschera_ruotata(maschera: int, quarti: int) -> int:
	var girata := 0
	for i in 4:
		if maschera & (1 << i) == 0:
			continue
		girata |= 1 << indice(ruota(DIREZIONI[i], quarti))
	return girata


## Il pezzo da mettere dove i vicini sono messi così: { variante, rotazione }.
##
## Sedici maschere, cinque modelli, quattro rotazioni: le venti combinazioni
## coprono i sedici casi con qualche doppione — un dritto girato di mezzo giro è
## lo stesso dritto — e chi arriva primo vince. L'ordine in cui si provano le
## varianti non cambia niente perché due varianti diverse non fanno mai la
## stessa maschera: è il numero di braccia a distinguerle.
static func pezzo(maschera: int) -> Dictionary:
	if _tabella.is_empty():
		_tabella = _costruisci_tabella()
	return _tabella.get(maschera & 0b1111, PEZZO_SOLITARIO)


static func _costruisci_tabella() -> Dictionary:
	var tabella := {}
	for variante in BRACCIA:
		for quarti in 4:
			var maschera := maschera_ruotata(int(BRACCIA[variante]), quarti)
			if not tabella.has(maschera):
				tabella[maschera] = { "variante": str(variante), "rotazione": quarti }
	tabella[0] = PEZZO_SOLITARIO
	return tabella


## Quanto va girata una rampa perché la sua parte alta guardi `verso`.
##
## Il modello sale verso sud — il capo nord sta a quota zero, quello sud un
## gradino più su — quindi a rotazione zero la salita guarda -y. Nella libreria
## c'è anche una rampa «in discesa», ma è questa vista dall'altra parte: girarne
## una sola vuol dire una tabella in meno da tenere d'accordo con i modelli.
static func rotazione_della_rampa(verso: Vector2i) -> int:
	for quarti in 4:
		if ruota(Vector2i(0, -1), quarti) == verso:
			return quarti
	return 0


# --- Il percorso ------------------------------------------------------------

## Il percorso a elle fra due celle: un tratto dritto, un gomito, un altro tratto.
##
## A elle e non a mano libera perché è la forma che si tira dritta. Seguire il
## cursore cella per cella dà strade che tremano, e una città vuole isolati;
## quale dei due gomiti prendere lo sceglie chi traccia, con R.
static func percorso_a_elle(da: Vector2i, a: Vector2i, prima_x: bool) -> Array[Vector2i]:
	var celle: Array[Vector2i] = []
	var gomito := Vector2i(a.x, da.y) if prima_x else Vector2i(da.x, a.y)
	_aggiungi_tratto(celle, da, gomito)
	_aggiungi_tratto(celle, gomito, a)
	return celle


## Le celle da `da` ad `a` lungo un asse solo. Il gomito non si ripete: due
## tratti attaccati lo condividono.
static func _aggiungi_tratto(celle: Array[Vector2i], da: Vector2i, a: Vector2i) -> void:
	var passo := Vector2i(signi(a.x - da.x), signi(a.y - da.y))
	var cella := da
	while true:
		if celle.is_empty() or celle[celle.size() - 1] != cella:
			celle.append(cella)
		if cella == a or passo == Vector2i.ZERO:
			return
		cella += passo


# --- Nomi dei modelli -------------------------------------------------------

## L'id del pezzo piano di una famiglia, data la variante.
static func id_del_pezzo(famiglia: String, variante: String) -> String:
	var f: Dictionary = FAMIGLIE.get(famiglia, {})
	return "" if f.is_empty() else str(f["pezzo"]) % variante


## L'id della rampa di una famiglia.
static func id_della_rampa(famiglia: String) -> String:
	var f: Dictionary = FAMIGLIE.get(famiglia, {})
	return "" if f.is_empty() else str(f["rampa"])


## A che famiglia appartiene un modello già posato. Serve a rifare la forma di
## una strada che c'era già senza cambiarle il fondo sotto i piedi.
static func famiglia_di(id_modello: String) -> String:
	return "sterrata" if id_modello.contains("_DIRT") else "asfaltata"


## L'id con cui una famiglia sta nel negozio.
static func voce_della_famiglia(famiglia: String) -> String:
	return PREFISSO_VOCE + famiglia.to_upper()


## La famiglia dietro una voce del negozio, o "" se quella voce è un modello
## come tutti gli altri.
static func famiglia_della_voce(id_voce: String) -> String:
	if not id_voce.begins_with(PREFISSO_VOCE):
		return ""
	var famiglia := id_voce.substr(PREFISSO_VOCE.length()).to_lower()
	return famiglia if FAMIGLIE.has(famiglia) else ""
