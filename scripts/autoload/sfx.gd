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

extends Node
## I suoni dell'app, sintetizzati all'avvio invece che caricati da file.
##
## Non c'è un solo .wav sul disco: come i 91 modelli nascono da uno script
## Blender, questi nascono dalle note qui sotto. Si ritocca un numero e il suono
## cambia, senza aprire un editor audio e senza aggiungere binari al repository.
##
## Costa una manciata di millisecondi all'avvio: tutto il banco sta sotto i tre
## secondi di audio, sintetizzati una volta sola e poi soltanto riprodotti.

const FREQUENZA := 44100

## Quante voci possono sovrapporsi. Oltre, la più vecchia viene interrotta, ed
## è quello che si vuole: martellando il badile interessa sentire l'ultimo
## colpo, non i dodici di prima tutti insieme.
const VOCI := 8

## Il banco. Ogni suono è un elenco di note: "f" la frequenza in hertz, "t"
## quando entra, "d" quanto dura, "a" il volume, "forma" il timbro.
##
## Le frequenze non sono a caso: sono note vere, e quello che dice di sì sale
## (do-sol, do-mi-sol), quello che dice di no scende. È l'unico posto in cui
## questa app parla senza scrivere.
const BANCO := {
	# Il tempo comincia a scorrere: due note che salgono, la quinta giusta.
	"avvio": [
		{ "f": 523.25, "t": 0.00, "d": 0.14, "a": 0.55, "forma": "seno" },
		{ "f": 783.99, "t": 0.10, "d": 0.22, "a": 0.55, "forma": "seno" },
	],
	# Sospeso: le stesse due note al contrario.
	"pausa": [
		{ "f": 587.33, "t": 0.00, "d": 0.12, "a": 0.45, "forma": "seno" },
		{ "f": 440.00, "t": 0.09, "d": 0.20, "a": 0.45, "forma": "seno" },
	],
	# Il timer è finito: una campana su do-mi-sol-do con la coda lunga. È il
	# suono che deve arrivare da un'altra stanza.
	"fine": [
		{ "f": 1046.50, "t": 0.00, "d": 0.90, "a": 0.50, "forma": "campana" },
		{ "f": 1318.51, "t": 0.16, "d": 0.90, "a": 0.45, "forma": "campana" },
		{ "f": 1567.98, "t": 0.32, "d": 1.10, "a": 0.50, "forma": "campana" },
		{ "f": 2093.00, "t": 0.48, "d": 1.30, "a": 0.30, "forma": "campana" },
	],
	# Crediti accreditati: due note brevi e brillanti.
	"credito": [
		{ "f": 1318.51, "t": 0.00, "d": 0.07, "a": 0.40, "forma": "seno" },
		{ "f": 1760.00, "t": 0.05, "d": 0.18, "a": 0.40, "forma": "seno" },
	],
	# Qualcosa si posa: un tonfo pieno, senza note acute che restino in testa.
	"posa": [
		{ "f": 196.00, "t": 0.00, "d": 0.16, "a": 0.55, "forma": "triangolo" },
		{ "f": 98.00, "t": 0.00, "d": 0.22, "a": 0.45, "forma": "seno" },
		{ "f": 880.00, "t": 0.00, "d": 0.04, "a": 0.18, "forma": "seno" },
	],
	# Qualcosa viene giù: crollo largo, senza un'altezza riconoscibile.
	"demolisci": [
		{ "f": 320.00, "t": 0.00, "d": 0.34, "a": 0.50, "forma": "rumore" },
		{ "f": 82.41, "t": 0.02, "d": 0.30, "a": 0.45, "forma": "seno" },
	],
	# Il badile: una palata corta e sorda.
	"terreno": [
		{ "f": 900.00, "t": 0.00, "d": 0.13, "a": 0.32, "forma": "rumore" },
		{ "f": 130.81, "t": 0.00, "d": 0.14, "a": 0.35, "forma": "triangolo" },
	],
	# Non si può: due note basse e ravvicinate, che scendono.
	"errore": [
		{ "f": 207.65, "t": 0.00, "d": 0.10, "a": 0.35, "forma": "ronzio" },
		{ "f": 174.61, "t": 0.09, "d": 0.18, "a": 0.35, "forma": "ronzio" },
	],
	# Un pulsante del menu: appena percettibile.
	"clic": [
		{ "f": 1174.66, "t": 0.00, "d": 0.05, "a": 0.22, "forma": "seno" },
	],
}

var _banco_pronto: Dictionary = {}
var _voci: Array[AudioStreamPlayer] = []
var _prossima: int = 0
var _volume: float = 0.8
var _muto: bool = false


func _ready() -> void:
	for nome in BANCO:
		_banco_pronto[nome] = _sintetizza(BANCO[nome])
	for i in VOCI:
		var voce := AudioStreamPlayer.new()
		voce.bus = "Master"
		add_child(voce)
		_voci.append(voce)
	SaveManager.settings_changed.connect(_leggi_le_preferenze)
	SaveManager.game_loaded.connect(_leggi_le_preferenze)
	_leggi_le_preferenze()


func suona(nome: String) -> void:
	if _muto or _volume <= 0.0:
		return
	var stream: AudioStreamWAV = _banco_pronto.get(nome, null)
	if stream == null:
		push_warning("Sfx: suono sconosciuto: %s" % nome)
		return
	var voce := _voci[_prossima]
	_prossima = (_prossima + 1) % _voci.size()
	voce.stream = stream
	voce.volume_db = linear_to_db(_volume)
	voce.play()


func _leggi_le_preferenze() -> void:
	_volume = SaveManager.volume()
	_muto = SaveManager.muto()


# --- Sintesi ----------------------------------------------------------------

## Costruisce un suono dalle sue note. Il risultato è identico a ogni avvio:
## anche il rumore esce da un generatore con un seme fisso, così un suono non
## può cambiare timbro fra due partite.
func _sintetizza(note: Array) -> AudioStreamWAV:
	var durata := 0.0
	for nota in note:
		durata = maxf(durata, float(nota["t"]) + float(nota["d"]))
	var onda := PackedFloat32Array()
	onda.resize(int(ceil(durata * FREQUENZA)) + 1)

	var rng := RandomNumberGenerator.new()
	for nota in note:
		rng.seed = int(nota["f"]) * 7919 + int(float(nota["t"]) * 1000.0)
		_incidi(onda, nota, rng)

	_normalizza(onda)
	return _impacchetta(onda)


## Somma una nota nell'onda, con la sua campana di volume: attacco molto corto
## e poi discesa esponenziale. Senza l'attacco il suono partirebbe con uno
## scatto, e senza la dissolvenza in coda finirebbe con un altro.
func _incidi(onda: PackedFloat32Array, nota: Dictionary, rng: RandomNumberGenerator) -> void:
	var frequenza := float(nota["f"])
	var inizio := int(float(nota["t"]) * FREQUENZA)
	var lunghezza := int(float(nota["d"]) * FREQUENZA)
	var ampiezza := float(nota["a"])
	var forma := str(nota["forma"])
	var attacco := maxi(1, int(0.006 * FREQUENZA))
	var coda := lunghezza / 10
	# Le campane suonano lunghe, i tonfi si spengono subito.
	var decadimento := 2.6 if forma == "campana" else 5.5
	var filtrato := 0.0

	for i in lunghezza:
		var indice := inizio + i
		if indice < 0 or indice >= onda.size():
			continue
		var t := float(i) / float(FREQUENZA)
		var fase := TAU * frequenza * t
		var valore := 0.0
		match forma:
			"seno":
				valore = sin(fase)
			"triangolo":
				valore = asin(sin(fase)) * 2.0 / PI
			"campana":
				# Una campana non è una sinusoide: sono più parziali che si
				# spengono a velocità diverse, e la più acuta va via per prima.
				valore = 0.7 * (sin(fase) \
					+ 0.5 * sin(fase * 2.0) * exp(-6.0 * t) \
					+ 0.25 * sin(fase * 3.01) * exp(-9.0 * t))
			"ronzio":
				valore = 0.6 * (sin(fase) + 0.5 * sin(fase * 2.0) + 0.33 * sin(fase * 3.0))
			"rumore":
				# Rumore filtrato: crudo graffia. Qui "f" non dice a che altezza
				# suonare ma quanto lasciarne passare.
				var alfa := clampf(frequenza / float(FREQUENZA), 0.0, 1.0)
				filtrato += alfa * (rng.randf_range(-1.0, 1.0) - filtrato)
				valore = filtrato * 2.2
			_:
				valore = sin(fase)

		var campana := exp(-decadimento * t)
		if i < attacco:
			campana *= float(i) / float(attacco)
		# Ultimo decimo in dissolvenza fino a zero esatto: una coda troncata a
		# metà oscillazione si sente come un clic.
		if coda > 0 and i > lunghezza - coda:
			campana *= float(lunghezza - i) / float(coda)
		onda[indice] += valore * ampiezza * campana


## Porta il picco a 0,9. Così i suoni del banco restano confrontabili fra loro
## senza dover accordare a mano l'ampiezza di ogni nota.
func _normalizza(onda: PackedFloat32Array) -> void:
	var picco := 0.0
	for campione in onda:
		picco = maxf(picco, absf(campione))
	if picco <= 0.0001:
		return
	var fattore := 0.9 / picco
	for i in onda.size():
		onda[i] *= fattore


func _impacchetta(onda: PackedFloat32Array) -> AudioStreamWAV:
	var dati := PackedByteArray()
	dati.resize(onda.size() * 2)
	for i in onda.size():
		dati.encode_s16(i * 2, int(clampf(onda[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FREQUENZA
	wav.stereo = false
	wav.data = dati
	return wav
