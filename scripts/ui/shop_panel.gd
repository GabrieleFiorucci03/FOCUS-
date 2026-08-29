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
signal demolizione_commutata(attiva: bool)

const TESTO_VUOTO := "Scegli qualcosa da costruire."

@onready var _saldo: Label = %Saldo
@onready var _categorie: TabBar = %Categorie
@onready var _elenco: ItemList = %Elenco
@onready var _dettaglio: Label = %Dettaglio
@onready var _demolisci: Button = %Demolisci

var _catalogo: CityCatalog
var _crediti: int = 0


func _ready() -> void:
	_categorie.tab_changed.connect(_on_categoria_cambiata)
	_elenco.item_selected.connect(_on_voce_selezionata)
	_demolisci.toggled.connect(_on_demolizione_commutata)


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
	_demolisci.set_pressed_no_signal(false)
	_dettaglio.text = TESTO_VUOTO


func demolizione_attiva() -> bool:
	return _demolisci.button_pressed


# --- Interazione ------------------------------------------------------------

func _on_categoria_cambiata(_indice: int) -> void:
	_riempi_elenco()


func _on_voce_selezionata(indice: int) -> void:
	var id := str(_elenco.get_item_metadata(indice))
	_demolisci.set_pressed_no_signal(false)
	_dettaglio.text = _descrizione(id)
	voce_scelta.emit(id)


func _on_demolizione_commutata(attiva: bool) -> void:
	if attiva:
		_elenco.deselect_all()
		_dettaglio.text = "Clic su una costruzione per demolirla: torna indietro il %d%% del prezzo.\nEsc per smettere." % roundi(Config.refund_ratio * 100.0)
	else:
		_dettaglio.text = TESTO_VUOTO
	demolizione_commutata.emit(attiva)


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


func _descrizione(id: String) -> String:
	var v := _catalogo.voce(id)
	var f: Vector2i = v["footprint"]
	var righe := PackedStringArray()
	righe.append("%s · %dx%d celle · %d crediti" % [v["nome"], f.x, f.y, _catalogo.prezzo(id)])
	if _catalogo.regola(id) == CityCatalog.Regola.PONTE:
		righe.append("Va sull'acqua, agganciato a una riva o a un'altra campata.")
	else:
		righe.append("Spiana il lotto al livello più basso che tocca.")
	righe.append("Clic per posare · R ruota · Esc annulla")
	return "\n".join(righe)
