# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.

extends Button
class_name BottoneMenu
## Il pulsante che apre il menu, disegnato invece che scritto.
##
## Accanto a «Focus» e «Città» un terzo rettangolo con su scritto «Menu» sembra
## una terza modalità, e non lo è: quelli due dicono *dove sei*, questo *fa una
## cosa*. Le tre righe lo dicono senza parole e senza pesare quanto loro, e la
## barra torna a leggersi in un colpo: due schede, e un comando.
##
## Il fondo scuro non è un vezzo: questo pulsante sta anche sopra la mappa della
## città, che è chiara sulla spiaggia e scura nel mare. Vedi [StileBottoni], che
## veste allo stesso modo i due pulsanti in alto a sinistra.
##
## Le tre righe sono disegnate a mano perché il resto dell'app fa lo stesso — i
## suoni sono sintetizzati, i modelli generati — e perché un quadrato di 34
## pixel non vale un file d'immagine da importare e tenere allineato al tema.

## Le tre righe: quanto sono lunghe, quanto grosse, e quanto stanno distanti.
const LARGHEZZA := 16.0
const SPESSORE := 2.0
const PASSO := 6.0

var _premuto := false


func _ready() -> void:
	text = ""
	tooltip_text = "Menu (Esc)"
	custom_minimum_size = Vector2(38, 0)
	StileBottoni.applica(self, Vector2(6, 6))
	# Il disegno cambia con lo stato, e lo stato non manda un segnale suo: si
	# ridisegna quando succede una delle cose che lo cambiano.
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(_su_giu.bind(true))
	button_up.connect(_su_giu.bind(false))


func _su_giu(giu: bool) -> void:
	_premuto = giu
	queue_redraw()


## Tre righe centrate. Il pulsante è alto quanto le due schede accanto, ma il
## disegno sta al centro e non si accorge di quanto è alto il contenitore.
func _draw() -> void:
	var colore := _colore()
	var centro := size / 2.0
	for i in 3:
		var y := centro.y + (i - 1) * PASSO - SPESSORE / 2.0
		draw_rect(Rect2(centro.x - LARGHEZZA / 2.0, y, LARGHEZZA, SPESSORE), colore)


func _colore() -> Color:
	if disabled:
		return StileBottoni.SEGNO_SPENTO
	if _premuto:
		return StileBottoni.ACCENTO
	return StileBottoni.SEGNO_SVEGLIO if is_hovered() else StileBottoni.SEGNO
