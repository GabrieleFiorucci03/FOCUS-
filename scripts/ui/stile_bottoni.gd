# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.

extends RefCounted
class_name StileBottoni
## La pelle dei pulsanti quadrati che stanno sopra il mondo: costruzioni, conti,
## menu.
##
## Stanno tutti e tre appoggiati sopra qualcos'altro, e sopra il mondo 3D non c'è
## un fondo su cui contare: la mappa è chiara sulla spiaggia e scura nel mare, e
## un pulsante trasparente sparisce sull'una o sull'altra. Quindi **fondo scuro
## sempre**, come i pannelli, che è anche il modo in cui l'app dice «questa roba
## sta davanti, non dentro».
##
## Acceso è verde acqua, che è già il colore di «acceso» altrove — lo streak, i
## numeri delle statistiche. Su un interruttore vuol dire che il pannello che
## apre è aperto, e si vede senza guardare cosa c'è sotto.
##
## Un posto solo per tutti e tre perché sono la stessa cosa vista tre volte: se
## si scuriscono, si scuriscono insieme.

const ACCENTO := Color(0.180392, 0.768627, 0.713726)
const FONDO := Color(0.101961, 0.129412, 0.160784, 0.94)
const FONDO_SVEGLIO := Color(0.152941, 0.192157, 0.235294, 0.96)
const FONDO_ACCESO := Color(0.101961, 0.196078, 0.203922, 0.96)
const BORDO := Color(1, 1, 1, 0.14)
const BORDO_SVEGLIO := Color(1, 1, 1, 0.32)
const SEGNO := Color(1, 1, 1, 0.76)
const SEGNO_SVEGLIO := Color(1, 1, 1, 0.96)
const SEGNO_SPENTO := Color(1, 1, 1, 0.28)


## Veste un pulsante. `margine` è quanto respiro lasciare attorno all'icona:
## con `expand_icon` accesa l'icona riempie tutto quello che il bordo le lascia,
## e senza margine tocca i lati.
static func applica(bottone: Button, margine := Vector2(9, 6)) -> void:
	bottone.focus_mode = Control.FOCUS_NONE
	bottone.add_theme_stylebox_override("normal", cornice(FONDO, BORDO, margine))
	bottone.add_theme_stylebox_override("hover",
		cornice(FONDO_SVEGLIO, BORDO_SVEGLIO, margine))
	bottone.add_theme_stylebox_override("pressed",
		cornice(FONDO_ACCESO, Color(ACCENTO, 0.75), margine))
	bottone.add_theme_stylebox_override("focus", cornice(FONDO, BORDO, margine))
	bottone.add_theme_stylebox_override("disabled",
		cornice(Color(FONDO, 0.6), Color(1, 1, 1, 0.07), margine))
	bottone.add_theme_color_override("icon_normal_color", SEGNO)
	bottone.add_theme_color_override("icon_hover_color", SEGNO_SVEGLIO)
	bottone.add_theme_color_override("icon_pressed_color", ACCENTO)
	bottone.add_theme_color_override("icon_hover_pressed_color", ACCENTO)
	bottone.add_theme_color_override("icon_focus_color", SEGNO)
	bottone.add_theme_color_override("icon_disabled_color", SEGNO_SPENTO)


## Un rettangolo con gli angoli tondi come quelli dei pannelli: la stessa
## famiglia di forme, così i pulsanti appartengono alla stessa app.
static func cornice(fondo: Color, bordo: Color, margine: Vector2) -> StyleBoxFlat:
	var stile := StyleBoxFlat.new()
	stile.bg_color = fondo
	stile.border_color = bordo
	stile.set_border_width_all(1)
	stile.set_corner_radius_all(8)
	stile.content_margin_left = margine.x
	stile.content_margin_right = margine.x
	stile.content_margin_top = margine.y
	stile.content_margin_bottom = margine.y
	return stile
