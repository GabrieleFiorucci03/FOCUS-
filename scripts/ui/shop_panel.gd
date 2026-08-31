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


class_name ShopPanel
extends PanelContainer
## Il pannello del negozio: scaffali, prezzi e il pulsante per demolire.
##
## Qui dentro non si compra niente e non si tocca il salvataggio: il pannello
## dice solo cosa ha scelto l'utente. Chi paga e chi costruisce è CityView, che
## è l'unico a sapere se il posto scelto va bene.

signal voce_scelta(id: String)
## Lo strumento in mano, o "" quando non ce n'è nessuno.
signal strumento_scelto(strumento: String)

const TESTO_VUOTO := "Scegli qualcosa da costruire."

## Gli attrezzi, nell'ordine in cui compaiono. Costruire sta nell'elenco qui
## sopra; qui sotto c'è quello che si fa a una città che esiste già.
const STRUMENTI := {
	"alza": "Alza",
	"abbassa": "Abbassa",
	"livella": "Livella",
	"demolisci": "Demolisci",
}

@onready var _saldo: Label = %Saldo
@onready var _categorie: TabBar = %Categorie
@onready var _elenco: ItemList = %Elenco
@onready var _dettaglio: Label = %Dettaglio
@onready var _strumenti: GridContainer = %Strumenti

var _catalogo: CityCatalog
var _crediti: int = 0
var _gruppo: ButtonGroup


func _ready() -> void:
	_categorie.tab_changed.connect(_on_categoria_cambiata)
	_elenco.item_selected.connect(_on_voce_selezionata)
	_costruisci_gli_strumenti()


func _costruisci_gli_strumenti() -> void:
	# Un gruppo solo: gli attrezzi si escludono a vicenda, e riclicare quello
	# acceso lo spegne invece di lasciare senza via d'uscita.
	_gruppo = ButtonGroup.new()
	_gruppo.allow_unpress = true
	for id in STRUMENTI:
		var bottone := Button.new()
		bottone.text = str(STRUMENTI[id])
		bottone.toggle_mode = true
		bottone.button_group = _gruppo
		bottone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottone.toggled.connect(_on_strumento_commutato.bind(id))
		_strumenti.add_child(bottone)


func mostra_catalogo(catalogo: CityCatalog) -> void:
	_catalogo = catalogo
	_categorie.clear_tabs()
	for categoria in catalogo.categorie:
		_categorie.add_tab(str(categoria["nome"]))
	if _categorie.tab_count > 0:
		_categorie.current_tab = 0
	_riempi_elenco()


func aggiorna_saldo(crediti: int) -> void:
	_crediti = crediti
	_saldo.text = "%d crediti" % crediti
	_aggiorna_disponibilita()


## Riporta il pannello a riposo. La chiama CityView quando si esce da una
## modalità, quindi non deve rimbalzare indietro nessun segnale.
func deseleziona() -> void:
	_elenco.deselect_all()
	_spegni_gli_strumenti()
	_dettaglio.text = TESTO_VUOTO


func _spegni_gli_strumenti() -> void:
	var acceso := _gruppo.get_pressed_button()
	if acceso != null:
		acceso.set_pressed_no_signal(false)


# --- Interazione ------------------------------------------------------------

func _on_categoria_cambiata(_indice: int) -> void:
	_riempi_elenco()


func _on_voce_selezionata(indice: int) -> void:
	var id := str(_elenco.get_item_metadata(indice))
	_spegni_gli_strumenti()
	_dettaglio.text = _descrizione(id)
	voce_scelta.emit(id)


func _on_strumento_commutato(attivo: bool, id: String) -> void:
	if not attivo:
		# Cambiando attrezzo arriva prima lo spegnimento del vecchio: solo se
		# non se n'è acceso un altro vuol dire davvero "nessuno strumento".
		if _gruppo.get_pressed_button() == null:
			_dettaglio.text = TESTO_VUOTO
			strumento_scelto.emit("")
		return
	_elenco.deselect_all()
	_dettaglio.text = _descrizione_strumento(id)
	strumento_scelto.emit(id)


# --- Elenco -----------------------------------------------------------------

func _riempi_elenco() -> void:
	_elenco.clear()
	if _catalogo == null or _categorie.current_tab < 0 or _categorie.current_tab >= _catalogo.categorie.size():
		return
	var categoria: Dictionary = _catalogo.categorie[_categorie.current_tab]
	for id in categoria["voci"]:
		var v := _catalogo.voce(id)
		var f: Vector2i = v["footprint"]
		var indice := _elenco.add_item("%s · %d cr" % [v["nome"], _catalogo.prezzo(id)])
		_elenco.set_item_metadata(indice, id)
		_elenco.set_item_tooltip(indice, "%s · ingombro %dx%d celle" % [v["nome"], f.x, f.y])
	_aggiorna_disponibilita()


## Quello che non ci si può permettere resta a schermo, spento: sapere quanto
## manca è metà del motivo per tornare a fare focus.
func _aggiorna_disponibilita() -> void:
	if _catalogo == null:
		return
	for i in _elenco.item_count:
		var id := str(_elenco.get_item_metadata(i))
		var troppo_caro := _catalogo.prezzo(id) > _crediti
		_elenco.set_item_disabled(i, troppo_caro)
		_elenco.set_item_custom_fg_color(i, Color(1, 1, 1, 0.35) if troppo_caro else Color(1, 1, 1))


func _descrizione_strumento(id: String) -> String:
	var a_capo := "\n"
	match id:
		"demolisci":
			return "Clic su una costruzione per demolirla: torna indietro il %d%% del prezzo, ma il terreno resta come l'hai spianato.%sEsc per smettere." % [
				roundi(Config.refund_ratio * 100.0), a_capo
			]
		"livella":
			return "Primo clic: prende la quota. Da lì in poi ci porta le celle che tocchi.%s%d crediti a gradino, senza rimborso." % [
				a_capo, Config.terrain_cost_per_level
			]
		_:
			return "%s il terreno di un gradino (0,5 m) a ogni clic.%s%d crediti a gradino, senza rimborso. Sotto una costruzione non si tocca." % [
				"Alza" if id == "alza" else "Abbassa", a_capo, Config.terrain_cost_per_level
			]


func _descrizione(id: String) -> String:
	var v := _catalogo.voce(id)
	var f: Vector2i = v["footprint"]
	var righe := PackedStringArray()
	righe.append("%s · %dx%d celle · %d crediti" % [v["nome"], f.x, f.y, _catalogo.prezzo(id)])
	var a_mano := true
	match _catalogo.regola(id):
		CityCatalog.Regola.PONTE:
			righe.append("Va su qualunque cella libera, un gradino sopra quello che scavalca.")
		CityCatalog.Regola.RAMPA:
			righe.append("Va su qualunque cella libera, e non spiana niente.")
		_:
			righe.append("Spiana il lotto al livello più basso che tocca.")
			a_mano = false
	if a_mano:
		righe.append("Clic per posare · R ruota · PagSu / PagGiù cambia quota · Esc annulla")
	else:
		righe.append("Clic per posare · R ruota · Esc annulla")
	return "\n".join(righe)
