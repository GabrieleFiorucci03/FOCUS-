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
## `assets/models/generated/catalog.json` lo scrive la pipeline Blender a ogni
## rigenerazione della libreria: footprint, altezze, nome del `.glb`. Non si
## tocca a mano, verrebbe sovrascritto.
## `data/catalog.json` è la parte di gioco: come si chiama un oggetto in
## italiano, in che scaffale sta e con che regola si piazza.
## I prezzi stanno in `data/economy.json`, uno per tipo, e li legge Config.

const CATALOGO_ASSET := "res://assets/models/generated/catalog.json"
const CATALOGO_GIOCO := "res://data/catalog.json"

## Come si posa un oggetto.
## TERRA: all'asciutto, spianando il lotto sotto di sé.
## PONTE: sull'acqua, senza toccare il terreno, un gradino sopra la sponda.
## RAMPA: all'asciutto e in piano, ma solo dove c'è un gradino da raccordare.
enum Regola { TERRA, PONTE, RAMPA }

## I lati come li nomina la pipeline, tradotti in passi di griglia. Il fronte di
## ogni modello guarda -Y in Blender, che diventa -Z in Godot: "north" è la
## cella davanti.
const DIREZIONI := {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}

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

## Gli scaffali del negozio, in ordine: [{ id, nome, voci: PackedStringArray }].
## Le categorie che non hanno niente da vendere non ci finiscono.
var categorie: Array[Dictionary] = []


func _init() -> void:
	var gioco := _leggi(CATALOGO_GIOCO)
	var asset := _leggi(CATALOGO_ASSET)
	_costruisci_voci(asset, gioco)
	_costruisci_categorie(gioco)


# --- Interrogazioni ---------------------------------------------------------

func voce(id: String) -> Dictionary:
	return voci.get(id, {})


func esiste(id: String) -> bool:
	return voci.has(id)


func prezzo(id: String) -> int:
	var v := voce(id)
	if v.is_empty():
		return 0
	return Config.price_for_kind(str(v["kind"]))


func rimborso(id: String) -> int:
	return Config.refund_for_price(prezzo(id))


## Ruota un passo di griglia come Godot ruota il modello: -90° per scatto.
static func ruota_passo(passo: Vector2i, rotazione: int) -> Vector2i:
	var p := passo
	for _i in posmod(rotazione, 4):
		p = Vector2i(-p.y, p.x)
	return p


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

func _costruisci_voci(asset: Dictionary, gioco: Dictionary) -> void:
	var tipi: Dictionary = gioco.get("tipi", {})
	var predefinito: Dictionary = gioco.get("tipo_predefinito", {})
	var ordine: Array[String] = []

	for voce_asset in asset.get("assets", []):
		var kind := str(voce_asset.get("kind", ""))
		var tipo: Dictionary = tipi.get(kind, predefinito)
		var f: Array = voce_asset.get("footprint", [1, 1])
		var id := str(voce_asset.get("id", ""))
		if id.is_empty():
			continue
		voci[id] = {
			"id": id,
			"nome": _componi_nome(voce_asset, tipo),
			"kind": kind,
			"categoria": str(tipo.get("categoria", predefinito.get("categoria", ""))),
			"footprint": Vector2i(int(f[0]), int(f[1])),
			"modello": str(voce_asset.get("model", "")),
			"altezza": float(voce_asset.get("height_meters", 0.0)),
			"regola": _regola_di(voce_asset, tipo, predefinito),
			"in_vendita": bool(tipo.get("in_vendita", true)),
			"variante": str(voce_asset.get("variant", "")),
			"sostegno": float(voce_asset.get("support_height", 0.0)),
			"salita": _salita(voce_asset),
			"passo_alto": _passo_alto(voce_asset),
		}
		ordine.append(id)

	_numera_gli_omonimi(ordine)


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
		categorie.append({
			"id": id_categoria,
			"nome": str(descrizione.get("nome", id_categoria)),
			"voci": in_scaffale,
		})


## Il nome parte dal tipo e lo rifiniscono i campi descrittivi dell'asset: un
## valore che compare in "nomi" sostituisce il nome, uno che compare in
## "qualificatori" gli si accoda. Quello che non compare da nessuna parte non
## entra nel nome: meglio "Presidio sanitario 2" che un'etichetta piena di
## termini della pipeline.
static func _componi_nome(voce_asset: Dictionary, tipo: Dictionary) -> String:
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


## Di quanti gradini sale una rampa. Tutte quelle del kit salgono di 0,5 m, che
## è un gradino esatto: è per questo che una rampa vuole un dislivello di uno.
static func _salita(voce_asset: Dictionary) -> int:
	var gradino := float(voce_asset.get("elevation_step_meters", 0.5))
	return maxi(1, roundi(float(voce_asset.get("rise", 0.0)) / maxf(gradino, 0.001)))


## Da che parte guarda il lato alto di una rampa, a rotazione zero. La pipeline
## lo dice già: fra le "connections" è il lato con la quota maggiore.
static func _passo_alto(voce_asset: Dictionary) -> Vector2i:
	var connessioni: Dictionary = voce_asset.get("connections", {})
	var lato := ""
	var quota := -INF
	for nome in connessioni:
		if float(connessioni[nome]) > quota:
			quota = float(connessioni[nome])
			lato = str(nome)
	return DIREZIONI.get(lato, Vector2i.ZERO)


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
