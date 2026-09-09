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

class_name ComandiTocco
extends Control
## I tasti della città, per un telefono che di tasti non ne ha.
##
## In città quasi tutto si fa già toccando: il negozio e i conti hanno il loro
## pulsante, le costruzioni si posano dove si tocca, la mappa si trascina col
## dito e si zooma con due. Restano fuori le cose che sul PC sono solo tastiera
## — Q ed E che girano la vista, H che torna a casa, R che gira il pezzo, PagSu
## e PagGiù che lo alzano, l'Esc che annulla — e sono queste, e solo queste, che
## qui diventano pulsanti.
##
## Stanno in basso a destra, dove arriva il pollice di chi tiene il telefono in
## orizzontale a due mani, e sopra le due righe di suggerimenti. Il gruppo di
## sinistra compare solo quando serve: girare un pezzo che non hai in mano non
## vuol dire niente, e un pulsante spento che non fa niente è peggio di un
## pulsante che non c'è.
##
## Ogni pulsante non chiama il metodo della città: rifà il tasto (vedi
## [method Piattaforma.premi]). Così i due modi di dare lo stesso ordine
## restano uno.

## Il lato dei pulsanti. Il resto dell'interfaccia è tarata su un monitor e non
## la tocchiamo: questi invece nascono per un dito, e 56 punti su un'altezza di
## 720 fanno più o meno mezzo centimetro di vetro, che è quanto serve per non
## sbagliare bersaglio mentre si guarda la città e non le dita.
const LATO := 56.0
const SEPARAZIONE := 8.0
## Quanto stare staccati dal bordo, e dalle due righe di testo che stanno sotto
## (il suggerimento e il messaggio, alti insieme una sessantina di punti).
const MARGINE := Vector2(16.0, 86.0)
## Lo stacco fra il gruppo che c'è sempre e quello che compare col pezzo in
## mano: si toccano al buio, e due gruppi attaccati diventano un gruppo solo.
const STACCO_FRA_GRUPPI := 22.0

var _fila: HBoxContainer
var _gruppo_pezzo: HBoxContainer
var _gira: Button
var _alza: Button
var _abbassa: Button
var _annulla: Button


func _ready() -> void:
	# Il Control che tiene tutto copre lo schermo, ma non deve mangiarsi i
	# tocchi destinati al terreno: a prenderli sono i pulsanti, uno per uno.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Piattaforma.mobile

	_fila = HBoxContainer.new()
	_fila.name = "Fila"
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fila.add_theme_constant_override("separation", int(SEPARAZIONE))
	_fila.alignment = BoxContainer.ALIGNMENT_END
	_fila.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fila.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fila.offset_left = -MARGINE.x - 520.0
	_fila.offset_top = -MARGINE.y - LATO
	_fila.offset_right = -MARGINE.x
	_fila.offset_bottom = -MARGINE.y
	add_child(_fila)

	# Da sinistra a destra: prima il gruppo che compare e sparisce, poi quello
	# che c'è sempre. Il gruppo fisso resta inchiodato al bordo, così la mano lo
	# ritrova nello stesso punto anche quando l'altro non c'è.
	_gruppo_pezzo = HBoxContainer.new()
	_gruppo_pezzo.name = "Pezzo"
	_gruppo_pezzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gruppo_pezzo.add_theme_constant_override("separation", int(SEPARAZIONE))
	_gruppo_pezzo.visible = false
	_fila.add_child(_gruppo_pezzo)

	_gira = _bottone(BottoneSegno.Segno.GIRA, "Gira il pezzo (R)", _gruppo_pezzo)
	_gira.pressed.connect(func() -> void: Piattaforma.premi(KEY_R))
	_alza = _bottone(BottoneSegno.Segno.ALZA, "Alza di una quota (PagSu)", _gruppo_pezzo)
	_alza.pressed.connect(func() -> void: Piattaforma.premi(KEY_PAGEUP))
	_abbassa = _bottone(BottoneSegno.Segno.ABBASSA, "Abbassa di una quota (PagGiù)", _gruppo_pezzo)
	_abbassa.pressed.connect(func() -> void: Piattaforma.premi(KEY_PAGEDOWN))
	_annulla = _bottone(BottoneSegno.Segno.ANNULLA, "Annulla (Esc)", _gruppo_pezzo)
	_annulla.pressed.connect(func() -> void: Piattaforma.premi(KEY_ESCAPE))

	var stacco := Control.new()
	stacco.name = "Stacco"
	stacco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stacco.custom_minimum_size = Vector2(STACCO_FRA_GRUPPI - SEPARAZIONE * 2.0, 0.0)
	_fila.add_child(stacco)

	var sinistra := _bottone(BottoneSegno.Segno.RUOTA_SX, "Gira la vista a sinistra (Q)", _fila)
	sinistra.pressed.connect(func() -> void: Piattaforma.premi(KEY_Q))
	var destra := _bottone(BottoneSegno.Segno.RUOTA_DX, "Gira la vista a destra (E)", _fila)
	destra.pressed.connect(func() -> void: Piattaforma.premi(KEY_E))
	var casa := _bottone(BottoneSegno.Segno.CASA, "Torna sulla città (H)", _fila)
	casa.pressed.connect(func() -> void: Piattaforma.premi(KEY_H))


## Quali comandi del pezzo hanno senso adesso. La città la chiama a ogni giro di
## [code]_aggiorna_aiuto[/code]: gli stessi cambi che riscrivono il suggerimento
## in fondo allo schermo riscrivono anche questa fila.
func mostra(gira: bool, quota: bool, annulla: bool) -> void:
	if not Piattaforma.mobile:
		return
	_gira.visible = gira
	_alza.visible = quota
	_abbassa.visible = quota
	_annulla.visible = annulla
	_gruppo_pezzo.visible = gira or quota or annulla


## Se un punto dello schermo è su questi pulsanti. La città lo chiede prima di
## prendere un tocco per un trascinamento della mappa: un dito partito da qui
## sta premendo, non sta scorrendo.
func contiene(punto: Vector2) -> bool:
	if not visible:
		return false
	for gruppo: Node in [_gruppo_pezzo, _fila]:
		for figlio: Node in gruppo.get_children():
			var bottone := figlio as Button
			if bottone != null and bottone.visible \
					and bottone.get_global_rect().has_point(punto):
				return true
	return false


func _bottone(segno: int, spiegazione: String, dove: Node) -> Button:
	var bottone := BottoneSegno.new()
	bottone.segno = segno
	bottone.tooltip_text = spiegazione
	bottone.custom_minimum_size = Vector2(LATO, LATO)
	dove.add_child(bottone)
	return bottone


## Un pulsante quadrato con un segno disegnato dentro.
##
## Disegnato e non importato, come le tre righe del menu e per la stessa
## ragione: sette quadrati di 56 punti non valgono sette file d'immagine da
## importare e tenere allineati al tema. La pelle è quella di [StileBottoni],
## perché anche questi stanno sopra il mondo 3D, che è chiaro sulla spiaggia e
## scuro nel mare.
class BottoneSegno extends Button:
	enum Segno { RUOTA_SX, RUOTA_DX, CASA, GIRA, ALZA, ABBASSA, ANNULLA }

	const RAGGIO := 15.0
	const SPESSORE := 3.0
	const PUNTA := 6.0

	var segno: int = Segno.CASA

	var _premuto := false

	func _ready() -> void:
		text = ""
		StileBottoni.applica(self, Vector2(6, 6))
		button_down.connect(_su_giu.bind(true))
		button_up.connect(_su_giu.bind(false))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _su_giu(giu: bool) -> void:
		_premuto = giu
		queue_redraw()

	func _draw() -> void:
		var colore := _colore()
		var centro := size / 2.0
		match segno:
			Segno.RUOTA_SX:
				_arco(centro, RAGGIO, 140.0, -130.0, colore)
			Segno.RUOTA_DX:
				_arco(centro, RAGGIO, 40.0, 310.0, colore)
			Segno.CASA:
				_casa(centro, colore)
			Segno.GIRA:
				# Lo stesso arco della vista, ma stretto attorno a un quadrato:
				# qui a girare non è quello che guardi, è quello che hai in mano.
				_arco(centro, RAGGIO, 40.0, 310.0, colore)
				var lato := RAGGIO * 0.62
				draw_rect(Rect2(centro - Vector2(lato, lato) / 2.0, Vector2(lato, lato)),
					colore, false, SPESSORE * 0.7)
			Segno.ALZA:
				_freccia_dritta(centro, -1.0, colore)
			Segno.ABBASSA:
				_freccia_dritta(centro, 1.0, colore)
			Segno.ANNULLA:
				var d := RAGGIO * 0.78
				draw_line(centro + Vector2(-d, -d), centro + Vector2(d, d),
					colore, SPESSORE, true)
				draw_line(centro + Vector2(-d, d), centro + Vector2(d, -d),
					colore, SPESSORE, true)

	## Un arco quasi chiuso con la punta di freccia in fondo: il verso lo dicono
	## da che parte è aperto e dove sta la punta, non una scritta.
	func _arco(centro: Vector2, raggio: float, da: float, a: float, colore: Color) -> void:
		draw_arc(centro, raggio, deg_to_rad(da), deg_to_rad(a), 32, colore, SPESSORE, true)
		var fine := deg_to_rad(a)
		var punto := centro + Vector2(cos(fine), sin(fine)) * raggio
		# La tangente, presa nel verso in cui l'arco è stato percorso.
		var verso := signf(a - da)
		var avanti := Vector2(-sin(fine), cos(fine)) * verso
		var fianco := Vector2(avanti.y, -avanti.x)
		draw_colored_polygon(PackedVector2Array([
			punto + avanti * PUNTA,
			punto - avanti * PUNTA * 0.4 + fianco * PUNTA * 0.9,
			punto - avanti * PUNTA * 0.4 - fianco * PUNTA * 0.9,
		]), colore)

	## Un tetto e quattro muri: la casa del tasto H.
	func _casa(centro: Vector2, colore: Color) -> void:
		var lato := RAGGIO
		var colmo := centro + Vector2(0.0, -lato)
		draw_polyline(PackedVector2Array([
			centro + Vector2(-lato, 0.0), colmo, centro + Vector2(lato, 0.0),
		]), colore, SPESSORE, true)
		draw_rect(
			Rect2(centro + Vector2(-lato * 0.68, 0.0), Vector2(lato * 1.36, lato * 0.9)),
			colore, false, SPESSORE)

	## La freccia della quota: su o giù, con la riga di terra dalla parte in cui
	## la quota si misura.
	func _freccia_dritta(centro: Vector2, verso: float, colore: Color) -> void:
		var lungo := RAGGIO * 0.9
		var coda := centro + Vector2(0.0, -verso * lungo)
		var testa := centro + Vector2(0.0, verso * lungo)
		draw_line(coda, testa, colore, SPESSORE, true)
		draw_colored_polygon(PackedVector2Array([
			testa + Vector2(0.0, verso * PUNTA * 0.9),
			testa + Vector2(PUNTA, -verso * PUNTA * 0.5),
			testa + Vector2(-PUNTA, -verso * PUNTA * 0.5),
		]), colore)
		var terra := centro.y + lungo + PUNTA * 1.7
		draw_line(Vector2(centro.x - lungo, terra), Vector2(centro.x + lungo, terra),
			Color(colore, colore.a * 0.55), SPESSORE * 0.7, true)

	func _colore() -> Color:
		if disabled:
			return StileBottoni.SEGNO_SPENTO
		if _premuto:
			return StileBottoni.ACCENTO
		return StileBottoni.SEGNO_SVEGLIO if is_hovered() else StileBottoni.SEGNO
