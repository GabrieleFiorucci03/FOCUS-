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


class_name CityCatalog
extends RefCounted
## Il catalogo del negozio: cosa si può comprare, come si chiama e dove si posa.
##
## Nasce dall'unione di due file che hanno padroni diversi.
## `assets/models/refined_v2/catalog.json` lo scrive la pipeline Blender a ogni
## rigenerazione della libreria: footprint, altezze, nome del `.glb`. Non si
## tocca a mano, verrebbe sovrascritto.
## `data/catalog.json` è la parte di gioco: come si chiama un oggetto in
## italiano, in che scaffale sta e con che regola si piazza.
## I prezzi stanno in `data/economy.json` e li legge Config.

## Dove stanno i .glb che la pipeline ha generato, tutti e centoquaranta: le
## novantuno voci del kit di base, rifatte con la geometria nuova — stessi id e
## stessi tipi, così una città salvata si riapre identica e cambia solo di
## aspetto — e i quarantanove modelli dell'espansione, che portano id nuovi e non
## ne toccano nessuno di quelli vecchi.
##
## I due generatori Blender restano due, perché sono due liste di modelli
## diverse, ma scrivono qui e ognuno rimette a posto il catalogo lasciando dove
## stanno le voci che non sono sue. Una libreria sola è una cartella sola da
## guardare quando qualcosa non torna.
const CARTELLA_MODELLI := "res://assets/models/refined_v2/"

const CATALOGO_ASSET := CARTELLA_MODELLI + "catalog.json"
const CATALOGO_GIOCO := "res://data/catalog.json"

## Come si posa un oggetto.
## TERRA: all'asciutto, spianando il lotto sotto di sé.
## PONTE e RAMPA: su qualunque cella libera, asciutta o bagnata che sia. Non
## spianano niente e non chiedono né acqua né gradini da raccordare: a decidere
## la quota a cui si posano è quello che si trovano intorno, non un divieto.
enum Regola { TERRA, PONTE, RAMPA }

## I campi con cui la pipeline descrive una variante, nell'ordine in cui vanno
## letti per comporre il nome: "Strada sterrata a incrocio", non "a incrocio
## sterrata".
const CAMPI_DESCRITTIVI: Array[String] = [
	"style", "variant", "service", "shape", "feature", "direction",
]

## Sotto questa luce una pila non si vedrebbe: la campata sfiora già l'acqua.
const LUCE_MINIMA_SOSTEGNO := 0.3

## id -> { id, nome, kind, categoria, footprint, modello, altezza, regola,
##         in_vendita, variante, sostegno }
var voci: Dictionary = {}

## Gli scaffali del negozio, in ordine:
## [{ id, nome, voci: PackedStringArray, gruppi: [{ nome, voci }] }].
## `voci` è tutto lo scaffale in fila, `gruppi` lo stesso elenco diviso per
## funzione. Le categorie che non hanno niente da vendere non ci finiscono.
var categorie: Array[Dictionary] = []


func _init() -> void:
	var gioco := _leggi(CATALOGO_GIOCO)
	_costruisci_voci(gioco)
	_costruisci_categorie(gioco)


# --- Interrogazioni ---------------------------------------------------------

func voce(id: String) -> Dictionary:
	return voci.get(id, {})


func esiste(id: String) -> bool:
	return voci.has(id)


## Il `res://` del .glb di un oggetto: la cartella dei modelli più il suo file.
## Sta qui perché la cartella è una cosa del catalogo, e chi costruisce o chi ne
## fa l'anteprima nel negozio non deve rimetterla insieme ogni volta.
func percorso(id: String) -> String:
	return str(voce(id).get("percorso", ""))


func prezzo(id: String) -> int:
	var v := voce(id)
	if v.is_empty():
		return 0
	return Config.price_for_asset(id, str(v["kind"]))


func rimborso(id: String) -> int:
	return Config.refund_for_price(prezzo(id))


func regola(id: String) -> Regola:
	var v := voce(id)
	if v.is_empty():
		return Regola.TERRA
	return v["regola"] as Regola


## La pila da infilare sotto una campata, scelta sull'altezza da colmare.
##
## I sostegni non si comprano e non occupano celle: una campata sopra l'acqua
## senza niente sotto sembrerebbe appesa, quindi la pila giusta nasce insieme
## al ponte come sua decorazione.
func sostegno_per_luce(luce: float) -> String:
	if luce < LUCE_MINIMA_SOSTEGNO:
		return ""
	var scelto := ""
	var scarto := INF
	for id in voci:
		var v: Dictionary = voci[id]
		if str(v["kind"]) != "bridge_support" or str(v["variante"]) != "pier":
			continue
		var differenza := absf(float(v["sostegno"]) - luce)
		if differenza < scarto:
			scarto = differenza
			scelto = str(id)
	return scelto


# --- Costruzione ------------------------------------------------------------

func _costruisci_voci(gioco: Dictionary) -> void:
	var tipi: Dictionary = gioco.get("tipi", {})
	var predefinito: Dictionary = gioco.get("tipo_predefinito", {})
	var deroghe: Dictionary = gioco.get("asset", {})
	var ordine: Array[String] = []

	for voce_asset in _leggi(CATALOGO_ASSET).get("assets", []):
		var id := str(voce_asset.get("id", ""))
		if id.is_empty():
			continue
		if voci.has(id):
			push_error("CityCatalog: %s compare due volte nel catalogo." % id)
		else:
			ordine.append(id)
		var kind := str(voce_asset.get("kind", ""))
		var tipo: Dictionary = tipi.get(kind, predefinito)
		var deroga: Dictionary = deroghe.get(id, {})
		var f: Array = voce_asset.get("footprint", [1, 1])
		var footprint := Vector2i(int(f[0]), int(f[1]))
		var celle := Config.built_cells_for(id, maxi(1, footprint.x * footprint.y))
		voci[id] = {
			"id": id,
			"nome": _componi_nome(voce_asset, tipo, deroga),
			"kind": kind,
			"categoria": str(deroga.get("categoria",
				tipo.get("categoria", predefinito.get("categoria", "")))),
			"footprint": footprint,
			"modello": str(voce_asset.get("model", "")),
			"percorso": CARTELLA_MODELLI + str(voce_asset.get("model", "")),
			"altezza": float(voce_asset.get("height_meters", 0.0)),
			"regola": _regola_di(voce_asset, tipo, predefinito),
			"in_vendita": bool(deroga.get("in_vendita", tipo.get("in_vendita", true))),
			"variante": str(voce_asset.get("variant", "")),
			"sostegno": float(voce_asset.get("support_height", 0.0)),
			"salita": _salita(voce_asset),
			"celle": celle,
			"servizi": _servizi(voce_asset, kind, celle),
			"abitanti": Config.residents_per_cell(kind) * celle,
			"posti": Config.jobs_per_cell(kind) * celle,
			"zona": str(deroga.get("zona", _zona_di(voce_asset, kind))),
		}

	_numera_gli_omonimi(ordine)
	_aggiungi_le_strade()


## Mette nel negozio le due strade che si tracciano, al posto dei loro pezzi.
##
## Non sono modelli: sono le due famiglie, e sceglierle non posa niente — accende
## la modalità con cui si tira un percorso. Stanno fra le voci e non fra gli
## attrezzi perché è lì che uno le cerca, in mezzo a quello che si compra, e
## perché così si portano dietro gratis prezzo, ritratto e scaffale.
##
## Il ritratto e l'ingombro se li prendono in prestito dal pezzo dritto della
## loro famiglia: una scheda deve far vedere di che strada si tratta, e il
## dritto è il pezzo che la racconta.
func _aggiungi_le_strade() -> void:
	for famiglia in ReteStradale.FAMIGLIE:
		var dritto := ReteStradale.id_del_pezzo(str(famiglia), "STRAIGHT")
		if not voci.has(dritto):
			push_error("CityCatalog: manca il pezzo dritto di %s (%s)." % [famiglia, dritto])
			continue
		var modello: Dictionary = (voci[dritto] as Dictionary).duplicate(true)
		modello["id"] = ReteStradale.voce_della_famiglia(str(famiglia))
		modello["nome"] = str(ReteStradale.FAMIGLIE[famiglia]["nome"])
		modello["in_vendita"] = true
		modello["famiglia"] = str(famiglia)
		voci[modello["id"]] = modello


## Se una voce del negozio è una strada da tracciare invece di un modello da
## posare. Chi la sceglie non prende in mano un pezzo: prende una matita.
func si_traccia(id: String) -> bool:
	return voce(id).has("famiglia")


## La famiglia di strada dietro una voce, o "" se quella voce non si traccia.
func famiglia(id: String) -> String:
	return str(voce(id).get("famiglia", ""))


## Dieci case si chiamano tutte "Casa": senza un numero il negozio sarebbe una
## lista di doppioni. Numera solo i nomi che si ripetono davvero, così "Serra"
## resta "Serra" e non diventa "Serra 1".
func _numera_gli_omonimi(ordine: Array[String]) -> void:
	var quanti := {}
	for id in ordine:
		var nome: String = voci[id]["nome"]
		quanti[nome] = int(quanti.get(nome, 0)) + 1

	var contatore := {}
	for id in ordine:
		var nome: String = voci[id]["nome"]
		if int(quanti[nome]) < 2:
			continue
		var n := int(contatore.get(nome, 0)) + 1
		contatore[nome] = n
		voci[id]["nome"] = "%s %d" % [nome, n]


func _costruisci_categorie(gioco: Dictionary) -> void:
	for descrizione in gioco.get("categorie", []):
		var id_categoria := str(descrizione.get("id", ""))
		var in_scaffale := PackedStringArray()
		for id in voci:
			var v: Dictionary = voci[id]
			if bool(v["in_vendita"]) and str(v["categoria"]) == id_categoria:
				in_scaffale.append(str(id))
		if in_scaffale.is_empty():
			continue
		var gruppi := _raggruppa(in_scaffale, descrizione.get("gruppi", []))
		var in_ordine := PackedStringArray()
		for gruppo in gruppi:
			in_ordine.append_array(gruppo["voci"] as PackedStringArray)
		categorie.append({
			"id": id_categoria,
			"nome": str(descrizione.get("nome", id_categoria)),
			"voci": in_ordine,
			"gruppi": gruppi,
		})


## Divide uno scaffale nei suoi gruppi, nell'ordine in cui il gioco li dichiara.
##
## Ogni gruppo si prende le voci rimaste che corrispondono a tutte le chiavi che
## dichiara, e le prende nell'ordine del catalogo, così dentro un gruppo i
## modelli di sempre vengono prima di quelli aggiunti dopo. Si guardano in fila e
## vince il primo che le prende: è quello che tiene i presidi fuori da
## "Trasporti", che altrimenti si porterebbe via tutto quello che è di tipo
## service. Quello che non entra da nessuna parte finisce in un gruppo senza
## nome in fondo allo scaffale — aggiungere un modello non deve mai poterlo far
## sparire dal negozio.
func _raggruppa(in_scaffale: PackedStringArray, descrizioni: Array) -> Array[Dictionary]:
	var gruppi: Array[Dictionary] = []
	var preso := {}
	for descrizione in descrizioni:
		var dentro := PackedStringArray()
		for id in in_scaffale:
			if preso.has(id) or not _corrisponde(str(id), descrizione):
				continue
			preso[id] = true
			dentro.append(str(id))
		if dentro.is_empty():
			continue
		gruppi.append({ "nome": str(descrizione.get("nome", "")), "voci": dentro })

	var avanzate := PackedStringArray()
	for id in in_scaffale:
		if not preso.has(id):
			avanzate.append(str(id))
	if not avanzate.is_empty():
		gruppi.append({ "nome": "", "voci": avanzate })
	return gruppi


## Se una voce sta in un gruppo: tutte le chiavi che il gruppo dichiara devono
## trovarla d'accordo, e quelle che non dichiara non la riguardano.
func _corrisponde(id: String, descrizione: Dictionary) -> bool:
	var v := voce(id)
	if v.is_empty():
		return false
	var tipi: Array = descrizione.get("tipi", [])
	if not tipi.is_empty() and not tipi.has(str(v["kind"])):
		return false
	var zone: Array = descrizione.get("zone", [])
	if not zone.is_empty() and not zone.has(str(v["zona"])):
		return false
	var produce := str(descrizione.get("produce", ""))
	if not produce.is_empty():
		var dato: Vector2i = v["servizi"]
		if produce == "corrente" and dato.x <= 0:
			return false
		if produce == "acqua" and dato.y <= 0:
			return false
	return true


## Il nome parte dal tipo e lo rifiniscono i campi descrittivi dell'asset: un
## valore che compare in "nomi" sostituisce il nome, uno che compare in
## "qualificatori" gli si accoda. Quello che non compare da nessuna parte non
## entra nel nome: meglio "Presidio sanitario 2" che un'etichetta piena di
## termini della pipeline.
## Un modello che si è già portato dietro il suo nome se lo tiene: i modelli
## dell'espansione non sono varianti di una tipologia — non c'è nessun campo che
## componendosi faccia "Torre Lanterna" — e componendoli si otterrebbero
## quarantotto oggetti chiamati "Torre", "Negozio" e "Impianto", numerati.
static func _componi_nome(voce_asset: Dictionary, tipo: Dictionary,
		deroga: Dictionary = {}) -> String:
	if deroga.has("nome"):
		return str(deroga["nome"])
	if not str(voce_asset.get("name", "")).is_empty():
		return str(voce_asset["name"])
	var nome := str(tipo.get("nome", "Oggetto"))
	var nomi: Dictionary = tipo.get("nomi", {})
	var qualificatori: Dictionary = tipo.get("qualificatori", {})
	var coda := PackedStringArray()

	for campo in CAMPI_DESCRITTIVI:
		if not voce_asset.has(campo):
			continue
		var valore := str(voce_asset[campo])
		if nomi.has(valore):
			nome = str(nomi[valore])
		elif qualificatori.has(valore):
			coda.append(str(qualificatori[valore]))

	if coda.is_empty():
		return nome
	return nome + " " + " ".join(coda)


## Che cosa fa un oggetto ai servizi della città: x la corrente, y l'acqua,
## positivo se ne mette in comune e negativo se ne prende.
##
## Un impianto dà il suo numero, che è suo o al più della sua variante: fra una
## pala eolica e una centrale nucleare non c'è un fattore di scala, c'è un altro
## ordine di grandezza. Tutto il resto prende a cella costruita, così un palazzo
## 3x3 pesa nove volte una casetta 1x1 senza che nessuno debba scriverlo
## novantuno volte: il tipo dice quanto pesa un metro quadro, il costruito dice
## quanti — e non è tutto l'ingombro, perché il giardino di una villa sta dentro
## il rettangolo ma non consuma niente.
func _servizi(voce_asset: Dictionary, kind: String, celle: int) -> Vector2i:
	var id := str(voce_asset.get("id", ""))
	var impianto := Config.plant_output_for_asset(id, kind, str(voce_asset.get("variant", "")))
	if impianto != Vector2i.ZERO:
		return impianto
	return -Config.consumption_per_cell(kind) * maxi(1, celle)


## Quanto un oggetto dà (positivo) o prende (negativo) di corrente e acqua.
func servizi(id: String) -> Vector2i:
	var v := voce(id)
	return Vector2i.ZERO if v.is_empty() else v["servizi"] as Vector2i


## Quanti abitanti porta un edificio quando funziona. Zero per tutto quello in
## cui non ci abita nessuno.
##
## La densità sta sul tipo e il costruito fa il resto, come per i servizi e per
## la stessa ragione: una torre 4x4 ospita sedici volte quello che ospita una
## cella di torre, e nessuno deve scrivere novantuno numeri perché lo dica.
func abitanti(id: String) -> int:
	var v := voce(id)
	return 0 if v.is_empty() else int(v["abitanti"])


## Quanti posti di lavoro offre un edificio quando funziona. Zero per tutto
## quello in cui non lavora nessuno.
func posti(id: String) -> int:
	var v := voce(id)
	return 0 if v.is_empty() else int(v["posti"])


## Quale servizio di zona porta un edificio, o "" se non ne porta nessuno.
func zona(id: String) -> String:
	var v := voce(id)
	return "" if v.is_empty() else str(v["zona"])


## Chi porta cosa. Questa è struttura, non bilanciamento: dice quale famiglia di
## asset fa da presidio per quale servizio, e cambia solo se cambia la libreria.
## I raggi e la soglia, che invece si ritoccano, stanno in economy.json.
static func _zona_di(voce_asset: Dictionary, kind: String) -> String:
	match kind:
		"park":
			return "verde"
		"sport":
			return "sport"
		"school":
			match str(voce_asset.get("variant", "")):
				"primary":
					return "elementare"
				"secondary":
					return "superiore"
		"service":
			match str(voce_asset.get("service", "")):
				"police":
					return "polizia"
				"fire":
					return "pompieri"
				"health":
					return "ospedale"
	return ""


## Se un oggetto è una strada: quello su cui si cammina e si arriva. Le rampe e
## gli impalcati dei ponti lo sono quanto l'asfalto — servono a passarci.
func e_strada(id: String) -> bool:
	var v := voce(id)
	if v.is_empty():
		return false
	return str(v["kind"]) in ["road", "sloped_road", "bridge"]


## Se un oggetto ha bisogno di una strada accanto.
##
## Non è un elenco a parte: è chiunque abbia a che fare con corrente e acqua, che
## le prenda o che le dia. Una pala eolica non consuma niente ma qualcuno ci deve
## pur arrivare per tirarla su e per ripararla, e una centrale in mezzo ai campi
## senza uno straccio di strada è la stessa cosa assurda di una casa. Restano
## liberi solo quelli che con i servizi non c'entrano — strade, ponti, rampe,
## alberi, parchi — e una lista sola non può contraddirne un'altra.
func vuole_la_strada(id: String) -> bool:
	return servizi(id) != Vector2i.ZERO


## Di quanti gradini sale una rampa. Tutte quelle del kit salgono di 0,5 m, che
## è un gradino esatto: serve a sapere dove arriva una rampa posata sull'acqua,
## dove non c'è terreno su cui appoggiarle il piede.
static func _salita(voce_asset: Dictionary) -> int:
	var gradino := float(voce_asset.get("elevation_step_meters", 0.5))
	return maxi(1, roundi(float(voce_asset.get("rise", 0.0)) / maxf(gradino, 0.001)))


static func _regola_di(voce_asset: Dictionary, tipo: Dictionary, predefinito: Dictionary) -> Regola:
	var nome_regola := str(tipo.get("regola", predefinito.get("regola", "terra")))
	# Le rampe sono di tipo "bridge" ma non stanno sull'acqua: sono il raccordo
	# che sale dalla sponda all'impalcato, quindi si posano a terra.
	var per_variante: Dictionary = tipo.get("regola_varianti", {})
	var variante := str(voce_asset.get("variant", ""))
	if per_variante.has(variante):
		nome_regola = str(per_variante[variante])
	match nome_regola:
		"ponte":
			return Regola.PONTE
		"rampa":
			return Regola.RAMPA
		_:
			return Regola.TERRA


static func _leggi(percorso: String) -> Dictionary:
	if not FileAccess.file_exists(percorso):
		push_error("CityCatalog: %s non trovato." % percorso)
		return {}
	var dati: Variant = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	if typeof(dati) != TYPE_DICTIONARY:
		push_error("CityCatalog: %s non è un oggetto JSON valido." % percorso)
		return {}
	return dati
