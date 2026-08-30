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

class_name Durata
extends RefCounted
## Come si scrive un tempo, in un posto solo.
##
## Due schermate diverse mostrano le stesse ore in due modi diversi — il
## countdown scorre, le statistiche riassumono — ma le regole di scrittura
## devono restare le stesse: se cambia il formato deve cambiare in entrambe.


## Il countdown grande: mm:ss, oppure h:mm:ss oltre l'ora.
##
## Si arrotonda per eccesso perché è un tempo che manca: finché resta un
## briciolo di secondo, quel secondo va ancora mostrato.
static func orologio(secondi: float) -> String:
	var totale := int(ceil(maxf(0.0, secondi)))
	var h := totale / 3600
	var m := (totale % 3600) / 60
	var s := totale % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


## Un tempo raccontato: "12h 34m", oppure "34m" sotto l'ora.
static func discorsiva(secondi: int) -> String:
	var h := secondi / 3600
	var m := (secondi % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % m
