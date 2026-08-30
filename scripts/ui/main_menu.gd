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

class_name MainMenu
extends Control
## Il menu: la porta d'ingresso, e la via d'uscita.
##
## Non tocca né il salvataggio né le schermate: dice solo cosa ha chiesto
## l'utente. Chi cancella una partita e chi chiude l'app è Main, che è l'unico
## a sapere se c'è una sessione in corso da chiudere prima.

signal gioca()
signal statistiche_richieste()
signal nuova_partita_richiesta()
signal uscita_richiesta()

const COLORE_ACCENTO := Color(0.180392, 0.768627, 0.713726)
const COLORE_TENUE := Color(0.545098, 0.588235, 0.639216)

@onready var _gioca: Button = %Gioca
@onready var _statistiche: Button = %Statistiche
@onready var _nuova: Button = %Nuova
@onready var _esci: Button = %Esci
@onready var _riepilogo: Label = %Riepilogo
@onready var _volume: HSlider = %Volume
@onready var _muto: CheckButton = %Muto

var _conferma: ConfirmationDialog


func _ready() -> void:
	_gioca.pressed.connect(_su.bind(gioca))
	_statistiche.pressed.connect(_su.bind(statistiche_richieste))
	_esci.pressed.connect(_su.bind(uscita_richiesta))
	_nuova.pressed.connect(_chiedi_conferma)

	_volume.value_changed.connect(_on_audio_cambiato)
	_muto.toggled.connect(_on_muto_commutato)

	_prepara_la_conferma()
	aggiorna()


## Rimette in pagina quello che può essere cambiato mentre il menu era chiuso.
func aggiorna() -> void:
	var iniziata := SaveManager.partita_iniziata()
	_gioca.text = "Continua" if iniziata else "Comincia"
	# Non si cancella una partita che non c'è: il pulsante resta a schermo
	# spento, come le voci del negozio fuori portata.
	_nuova.disabled = not iniziata
	_riepilogo.text = _riga_di_riepilogo(iniziata)

	_volume.set_value_no_signal(SaveManager.volume())
	_muto.set_pressed_no_signal(SaveManager.muto())


func _riga_di_riepilogo(iniziata: bool) -> String:
	if not iniziata:
		return "Nessuna partita: la città è tutta da fare."
	var pezzi := PackedStringArray()
	pezzi.append("%d crediti" % SaveManager.credits)
	pezzi.append("%s di focus" % Durata.discorsiva(SaveManager.total_focus_seconds))
	var streak := SaveManager.streak_attuale()
	if streak > 0:
		pezzi.append("%d %s di fila" % [streak, "giorno" if streak == 1 else "giorni"])
	return " · ".join(pezzi)


# --- Interazione ------------------------------------------------------------

func _su(segnale: Signal) -> void:
	Sfx.suona("clic")
	segnale.emit()


func _on_audio_cambiato(valore: float) -> void:
	SaveManager.imposta_audio(valore, _muto.button_pressed)
	# Un volume si regola a orecchio: senza un suono di prova si regolerebbe
	# alla cieca e ce se ne accorgerebbe solo a fine sessione.
	Sfx.suona("clic")


func _on_muto_commutato(attivo: bool) -> void:
	SaveManager.imposta_audio(_volume.value, attivo)
	if not attivo:
		Sfx.suona("clic")


func _chiedi_conferma() -> void:
	Sfx.suona("clic")
	_conferma.popup_centered()


func _prepara_la_conferma() -> void:
	# Cancellare una città è l'unica cosa irreversibile che questa app sappia
	# fare: va detto per intero prima, non spiegato dopo.
	_conferma = ConfirmationDialog.new()
	_conferma.title = "Ricominciare da capo?"
	_conferma.dialog_text = "Il mondo, le costruzioni, i crediti e le statistiche\n" \
		+ "vengono cancellati per sempre, e una sessione in corso\n" \
		+ "viene interrotta senza accrediti.\n\nNon si può tornare indietro."
	_conferma.ok_button_text = "Cancella tutto"
	_conferma.cancel_button_text = "Lascia stare"
	_conferma.confirmed.connect(func() -> void: nuova_partita_richiesta.emit())
	add_child(_conferma)
