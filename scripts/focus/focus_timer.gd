class_name FocusTimer
extends Node
## Countdown a durata libera basato sull'orologio monotono, non sui frame.
##
## Contare i delta di _process accumula errore e si ferma se la finestra viene
## sospesa: per un'app che misura ore di concentrazione non va bene. Qui il
## tempo si legge da Time.get_ticks_msec(), i frame servono solo a aggiornare
## la UI.

signal tick(remaining: float, elapsed: float)
signal finished(elapsed: float)
signal state_changed(new_state: int)

enum State { IDLE, RUNNING, PAUSED }

var state: State = State.IDLE
var duration: float = 0.0

## Secondi dei tratti già chiusi (prima di ogni pausa).
var _closed_elapsed: float = 0.0
## Istante di inizio del tratto in corso, orologio monotono.
var _segment_start_ms: int = 0


func _ready() -> void:
	set_process(false)


func start(seconds: float) -> void:
	duration = maxf(0.0, seconds)
	_closed_elapsed = 0.0
	_segment_start_ms = Time.get_ticks_msec()
	_set_state(State.RUNNING)
	set_process(true)
	_emit_tick()


func pause() -> void:
	if state != State.RUNNING:
		return
	_closed_elapsed = elapsed()
	set_process(false)
	_set_state(State.PAUSED)


func resume() -> void:
	if state != State.PAUSED:
		return
	_segment_start_ms = Time.get_ticks_msec()
	set_process(true)
	_set_state(State.RUNNING)


## Ferma il countdown e restituisce i secondi di focus accumulati.
func stop() -> float:
	var total := elapsed()
	_closed_elapsed = 0.0
	duration = 0.0
	set_process(false)
	_set_state(State.IDLE)
	return total


func elapsed() -> float:
	if state == State.RUNNING:
		return _closed_elapsed + float(Time.get_ticks_msec() - _segment_start_ms) / 1000.0
	return _closed_elapsed


func remaining() -> float:
	return maxf(0.0, duration - elapsed())


func is_active() -> bool:
	return state != State.IDLE


func _process(_delta: float) -> void:
	if elapsed() >= duration:
		var total := duration
		_closed_elapsed = total
		set_process(false)
		_set_state(State.IDLE)
		tick.emit(0.0, total)
		finished.emit(total)
		return
	_emit_tick()


func _emit_tick() -> void:
	tick.emit(remaining(), elapsed())


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(int(state))
