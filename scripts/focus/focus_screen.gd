extends Control
## Schermata di focus: imposti una durata, lavori, e il tempo diventa crediti.

## Durate rapide offerte come pulsanti, in minuti.
const PRESET_MINUTES: Array[int] = [25, 50, 90]

@onready var _timer: FocusTimer = $FocusTimer
@onready var _crediti: Label = %Crediti
@onready var _tempo: Label = %Tempo
@onready var _progresso: ProgressBar = %Progresso
@onready var _stato: Label = %Stato
@onready var _riga_durata: HBoxContainer = %RigaDurata
@onready var _ore: SpinBox = %Ore
@onready var _minuti: SpinBox = %Minuti
@onready var _preset: HBoxContainer = %Preset
@onready var _avvia: Button = %Avvia
@onready var _pausa: Button = %Pausa
@onready var _annulla: Button = %Annulla
@onready var _statistiche: Label = %Statistiche


func _ready() -> void:
	_costruisci_preset()

	_ore.value_changed.connect(_on_durata_cambiata)
	_minuti.value_changed.connect(_on_durata_cambiata)
	_avvia.pressed.connect(_on_avvia_premuto)
	_pausa.pressed.connect(_on_pausa_premuto)
	_annulla.pressed.connect(_on_annulla_premuto)

	_timer.tick.connect(_on_tick)
	_timer.finished.connect(_on_finita)
	_timer.state_changed.connect(_on_stato_timer_cambiato)

	SaveManager.credits_changed.connect(_on_crediti_cambiati)
	SaveManager.stats_changed.connect(_aggiorna_statistiche)

	_on_crediti_cambiati(SaveManager.credits)
	_aggiorna_statistiche()
	_aggiorna_comandi()
	_mostra_tempo(_durata_impostata(), 0.0)
	_stato.text = "Imposta una durata e comincia."


# --- Interazione ------------------------------------------------------------

func _on_avvia_premuto() -> void:
	if _timer.state == FocusTimer.State.PAUSED:
		_timer.resume()
		return
	var durata := _durata_impostata()
	if durata <= 0.0:
		_stato.text = "Imposta almeno un minuto."
		return
	_timer.start(durata)
	_stato.text = "Focus in corso. Buon lavoro."


func _on_pausa_premuto() -> void:
	if _timer.state == FocusTimer.State.RUNNING:
		_timer.pause()
		_stato.text = "In pausa. Il tempo non scorre."
	elif _timer.state == FocusTimer.State.PAUSED:
		_timer.resume()
		_stato.text = "Focus in corso."


func _on_annulla_premuto() -> void:
	var svolti := _timer.stop()
	_registra_sessione(svolti, false)
	_mostra_tempo(_durata_impostata(), 0.0)


func _on_durata_cambiata(_valore: float) -> void:
	if not _timer.is_active():
		_mostra_tempo(_durata_impostata(), 0.0)


func _on_tick(remaining: float, elapsed: float) -> void:
	_mostra_tempo(remaining, elapsed)


func _on_finita(elapsed: float) -> void:
	_registra_sessione(elapsed, true)
	_mostra_tempo(_durata_impostata(), 0.0)


func _on_stato_timer_cambiato(_nuovo_stato: int) -> void:
	_aggiorna_comandi()


func _on_crediti_cambiati(crediti: int) -> void:
	_crediti.text = "%d crediti" % crediti


# --- Logica -----------------------------------------------------------------

## Chiude una sessione: accredita il tempo svolto e racconta l'esito.
##
## Una sessione portata a termine paga sempre. Una interrotta a mano paga solo
## se Config lo permette e se è durata abbastanza (vedi economy.json).
func _registra_sessione(secondi: float, completata: bool) -> void:
	if secondi <= 0.0:
		_stato.text = "Sessione annullata."
		return

	var paga := completata
	if not completata:
		paga = Config.credits_on_early_stop and secondi >= float(Config.min_session_seconds)

	if not paga:
		_stato.text = "Interrotta dopo %s: troppo poco per essere accreditata." % _formatta(secondi)
		return

	var guadagnati := SaveManager.register_focus_session(secondi)
	var durata_testo := _formatta(secondi)
	if completata:
		_stato.text = "Sessione completata: %s di focus, +%d crediti." % [durata_testo, guadagnati]
	else:
		_stato.text = "Interrotta a %s: +%d crediti per il tempo svolto." % [durata_testo, guadagnati]


func _durata_impostata() -> float:
	return _ore.value * 3600.0 + _minuti.value * 60.0


func _mostra_tempo(remaining: float, elapsed: float) -> void:
	_tempo.text = _formatta(remaining)
	var totale := elapsed + remaining
	_progresso.value = (elapsed / totale) * 100.0 if totale > 0.0 else 0.0


func _aggiorna_comandi() -> void:
	var attivo := _timer.is_active()
	var in_pausa := _timer.state == FocusTimer.State.PAUSED

	_riga_durata.visible = not attivo
	_avvia.visible = not attivo
	_pausa.visible = attivo
	_annulla.visible = attivo
	_pausa.text = "Riprendi" if in_pausa else "Pausa"


func _aggiorna_statistiche() -> void:
	_statistiche.text = "%d sessioni · %s di focus totale" % [
		SaveManager.sessions_completed,
		_formatta_lungo(SaveManager.total_focus_seconds),
	]


func _costruisci_preset() -> void:
	for minuti in PRESET_MINUTES:
		var pulsante := Button.new()
		pulsante.text = "%d min" % minuti
		pulsante.pressed.connect(_imposta_durata.bind(minuti))
		_preset.add_child(pulsante)


func _imposta_durata(minuti_totali: int) -> void:
	_ore.value = minuti_totali / 60
	_minuti.value = minuti_totali % 60


# --- Formattazione ----------------------------------------------------------

## Countdown grande: mm:ss, oppure h:mm:ss oltre l'ora.
static func _formatta(secondi: float) -> String:
	var totale := int(ceil(maxf(0.0, secondi)))
	var h := totale / 3600
	var m := (totale % 3600) / 60
	var s := totale % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


## Statistiche: "12h 34m", oppure "34m" sotto l'ora.
static func _formatta_lungo(secondi: int) -> String:
	var h := secondi / 3600
	var m := (secondi % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % m
