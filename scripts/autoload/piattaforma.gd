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
## L'unica cosa che il gioco deve sapere del telefono: che non ha una tastiera.
##
## Il resto dell'app non nomina mai Android. Chiede `Piattaforma.mobile` e si
## comporta di conseguenza, e le due o tre cose che su un telefono si fanno in
## un altro modo — vibrare invece di far lampeggiare la finestra, leggere
## l'orologio da un'altra parte — stanno qui, scritte una volta sola.

## Su PC ci si può fingere un telefono con `Godot -- --mobile`: i comandi a
## tocco compaiono, la tastiera continua a funzionare, e si prova tutto senza
## passare da un APK ogni volta. Serve a me quanto all'emulatore.
const FINGI_TELEFONO := "--mobile"

## Vero su Android e iOS, o quando si sta fingendo. Si legge, non si scrive.
var mobile: bool = false


func _ready() -> void:
	mobile = OS.has_feature("mobile") \
		or OS.get_cmdline_user_args().has(FINGI_TELEFONO) \
		or OS.get_cmdline_args().has(FINGI_TELEFONO)


## Rifà il tasto che farebbe la stessa cosa, invece di chiamare il metodo che
## il tasto chiama.
##
## Dietro a ogni tasto della città c'è già una decisione con dentro i suoi
## «solo se non sto tracciando» e i suoi `set_input_as_handled`. Un bottone a
## tocco che chiamasse il metodo di sotto salterebbe quella decisione, e da lì
## in poi ci sarebbero due comportamenti da tenere allineati per sempre.
## Sintetizzando l'evento il dito passa esattamente per la strada del tasto, e
## di comportamento ne resta uno.
func premi(tasto: Key, con_shift: bool = false) -> void:
	var giu := InputEventKey.new()
	giu.physical_keycode = tasto
	giu.keycode = tasto
	giu.shift_pressed = con_shift
	giu.pressed = true
	Input.parse_input_event(giu)
	var su := giu.duplicate() as InputEventKey
	su.pressed = false
	Input.parse_input_event(su)


## L'equivalente telefonico di far lampeggiare la finestra nella barra delle
## applicazioni: un timer di concentrazione si usa guardando altrove, e a
## schermo spento la campana da sola può non bastare.
func chiedi_attenzione() -> void:
	if mobile:
		Input.vibrate_handheld(700)
		return
	DisplayServer.window_request_attention()


## Come si chiama, dentro una frase, il gesto che fa succedere le cose.
##
## I suggerimenti sono gli stessi su tutte e due le versioni, e devono restarlo:
## se un giorno cambia quello che fa un attrezzo, la frase da correggere dev'essere
## una sola. Quello che cambia sono le due o tre parole che nominano un gesto che
## sull'altra piattaforma non esiste, ed è giusto che stiano qui, tutte insieme.
##
## `verbo()` apre la frase — «Clic per posare», «Tocca per posare» — e
## `sostantivo()` la usa come nome: «a ogni clic», «a ogni tocco».
func verbo(maiuscola: bool = true) -> String:
	var parola := "Tocca" if mobile else "Clic"
	return parola if maiuscola else parola.to_lower()


func sostantivo() -> String:
	return "tocco" if mobile else "clic"


## La stessa apertura, quando quello che si preme è una cosa e non un posto: un
## clic si fa *su* una costruzione, un dito quella costruzione la tocca e basta.
func verbo_su(maiuscola: bool = true) -> String:
	return verbo(maiuscola) if mobile else verbo(maiuscola) + " su"


## Il comando che annulla: un tasto sul PC, e sul telefono il pulsante che
## disegna quella stessa croce.
func esc() -> String:
	return "×" if mobile else "Esc"


## L'orologio con cui si misura una sessione.
##
## Su PC va benissimo quello monotono di Godot. Su Android no: quando il
## telefono va in sonno profondo `get_ticks_msec()` si ferma con lui, e
## un'ora di focus a schermo spento tornerebbe indietro contata metà. L'unico
## orologio che lì cammina sempre è quello di sistema.
func adesso_msec() -> int:
	if mobile:
		return int(Time.get_unix_time_from_system() * 1000.0)
	return Time.get_ticks_msec()
