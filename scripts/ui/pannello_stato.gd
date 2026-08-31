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


class_name PannelloStato
extends Control
## Come sta la città, in un angolo e sempre lì: abitanti, corrente, acqua.
##
## Non ha un pulsante e non si chiude, perché non è una cosa da andare a
## cercare: sono i tre numeri che dicono se quello che si sta per costruire ci
## sta. I conti della città stanno invece dietro al loro pulsante — quelli
## rispondono a "che cosa non va", che è una domanda che ci si fa ogni tanto,
## non a ogni clic.
##
## Qui dentro non si conta niente: i conti li fa CityView, che è l'unica a
## sapere cosa c'è in città. Questo li mette in pagina.

## Sopra questa quota di riempimento la barra passa all'ambra: non è ancora un
## problema, ma è il momento in cui conviene pensare al prossimo impianto.
const SOGLIA_AMBRA := 0.85

const COLORE_CALMO := Color(0.36, 0.70, 0.95)
const COLORE_AMBRA := Color(0.95, 0.72, 0.32)
const COLORE_ROSSO := Color(0.90, 0.31, 0.26)

@onready var _pannello: PanelContainer = %Pannello
@onready var _abitanti: Label = %Abitanti
@onready var _corrente_testo: Label = %CorrenteTesto
@onready var _corrente_barra: ProgressBar = %CorrenteBarra
@onready var _acqua_testo: Label = %AcquaTesto
@onready var _acqua_barra: ProgressBar = %AcquaBarra
@onready var _lavoro_testo: Label = %LavoroTesto
@onready var _lavoro_barra: ProgressBar = %LavoroBarra
@onready var _felicita_testo: Label = %FelicitaTesto
@onready var _felicita_barra: ProgressBar = %FelicitaBarra


## `usati` e `disponibili` sono coppie: x la corrente, y l'acqua. Il lavoro
## viaggia a parte perché i suoi due numeri non sono una coppia dello stesso
## genere: uno è quanta gente cerca un posto, l'altro quanti posti ci sono.
func aggiorna(abitanti: int, usati: Vector2i, disponibili: Vector2i,
		posti_chiesti: int, posti_offerti: int, felicita: float) -> void:
	_abitanti.text = _con_i_punti(abitanti)
	_scrivi(_corrente_testo, _corrente_barra, usati.x, disponibili.x)
	_scrivi(_acqua_testo, _acqua_barra, usati.y, disponibili.y)
	_scrivi(_lavoro_testo, _lavoro_barra, posti_chiesti, posti_offerti)
	_scrivi_felicita(felicita)


## La felicità non ha un "su quanto": è già una quota. Il colore va al contrario
## degli altri — qui il pieno è la cosa buona — e il rosso comincia alla soglia
## dell'abbandono, così vuol dire "di qui in giù la gente se ne va".
func _scrivi_felicita(quota: float) -> void:
	_felicita_barra.max_value = 100.0
	_felicita_barra.value = clampf(quota * 100.0, 0.0, 100.0)
	_felicita_testo.text = "%d%%" % roundi(quota * 100.0)
	var colore := COLORE_CALMO
	if quota < Config.abandon_below():
		colore = COLORE_ROSSO
	elif quota < 0.8:
		colore = COLORE_AMBRA
	_felicita_testo.add_theme_color_override("font_color", colore)
	_felicita_barra.add_theme_stylebox_override("fill", _riempimento(colore))


## Mille e duecento si legge "1.200": a quattro cifre attaccate l'occhio deve
## fermarsi a contarle, e questo numero si guarda di sfuggita.
static func _con_i_punti(numero: int) -> String:
	var cifre := str(absi(numero))
	var fuori := ""
	while cifre.length() > 3:
		fuori = "." + cifre.substr(cifre.length() - 3) + fuori
		cifre = cifre.substr(0, cifre.length() - 3)
	return ("-" if numero < 0 else "") + cifre + fuori


## Una riga di servizio: quanta se ne usa su quanta ce n'è, e la barra piena in
## proporzione.
##
## Finché ce n'è abbastanza si legge la percentuale usata, che è quello che dice
## quanto margine resta. Quando invece non basta la percentuale smette di
## servire — «2392%» non si legge, si guarda e basta — e al suo posto va quanto
## ne manca, che è il numero con cui si decide cosa costruire. Vale anche per il
## totale a zero, che non è lo zero per cento ma una divisione che non si può
## fare.
static func _scrivi(testo: Label, barra: ProgressBar, usati: int, disponibili: int) -> void:
	barra.max_value = maxi(disponibili, 1)
	barra.value = clampi(usati, 0, barra.max_value)
	var quota := 1.0 if disponibili <= 0 else float(usati) / float(disponibili)
	if usati > disponibili:
		testo.text = "%d / %d · ne mancano %d" % [usati, disponibili, usati - disponibili]
	else:
		testo.text = "%d / %d · %d%%" % [usati, disponibili, roundi(quota * 100.0)]

	var colore := COLORE_CALMO
	if quota > 1.0 or disponibili <= 0:
		colore = COLORE_ROSSO
	elif quota >= SOGLIA_AMBRA:
		colore = COLORE_AMBRA
	testo.add_theme_color_override("font_color", colore)
	barra.add_theme_stylebox_override("fill", _riempimento(colore))


static func _riempimento(colore: Color) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = colore
	stile.corner_radius_top_left = 3
	stile.corner_radius_top_right = 3
	stile.corner_radius_bottom_left = 3
	stile.corner_radius_bottom_right = 3
	return stile


## Se il mouse sta sopra il pannello. CityView lo chiede prima di puntare una
## cella: sotto il riquadro non c'è terreno da scegliere.
func sotto_il_mouse() -> bool:
	return _pannello.get_global_rect().has_point(get_viewport().get_mouse_position())
