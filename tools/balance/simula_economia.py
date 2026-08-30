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

"""Che cosa costano, in ore di concentrazione, i prezzi che stanno in economy.json.

Bilanciare a occhio un'app come questa non funziona: i prezzi sono in crediti,
ma quello che l'utente spende davvero è tempo, e fra le due cose c'è un solo
numero — `credits_per_hour`. Questo strumento fa la divisione per tutti e 19 i
tipi in una volta, e poi racconta le prime giornate di quattro persone diverse.

    python tools/balance/simula_economia.py

Legge i file veri (`data/economy.json`, `assets/models/generated/catalog.json`):
si ritocca un prezzo, si rilancia, e si vede subito se la prima sessione da 25
minuti paga ancora una casa.
"""

import json
import pathlib
import sys

RADICE = pathlib.Path(__file__).resolve().parents[2]
ECONOMIA = RADICE / "data" / "economy.json"
CATALOGO = RADICE / "assets" / "models" / "generated" / "catalog.json"

## Le sessioni tipiche, in minuti: i tre preset dell'app.
PRESET = [25, 50, 90]

## Quanto studia al giorno, chi. Non sono utenti veri, sono i quattro casi che
## un'app del genere incontra: chi la prova, chi la usa, chi ci vive dentro.
PROFILI = [
    ("chi la prova", 25),
    ("uno studente normale", 60),
    ("una sessione seria", 120),
    ("chi ci vive dentro", 240),
]

## Un primo quartiere plausibile: quante cose di ogni tipo, per dire quanto
## tempo separa la città vuota da qualcosa che sembra un posto.
QUARTIERE = {
    "road": 14,
    "tree": 10,
    "house": 6,
    "park": 2,
    "shop": 2,
    "apartment": 2,
    "school": 1,
}


def carica(percorso):
    if not percorso.exists():
        sys.exit("manca %s" % percorso)
    with open(percorso, encoding="utf-8") as f:
        return json.load(f)


def modelli_per_tipo(catalogo):
    """Quanti modelli esistono per ogni `kind`: un prezzo li governa tutti."""
    conta = {}
    for voce in catalogo.get("assets", catalogo.get("voci", [])):
        conta[voce.get("kind", "?")] = conta.get(voce.get("kind", "?"), 0) + 1
    return conta


def ore(crediti, per_ora):
    return crediti / per_ora if per_ora > 0 else float("inf")


def tempo(ore_decimali):
    """3.25 -> "3h 15m", 0.4 -> "24m"."""
    minuti = int(round(ore_decimali * 60))
    if minuti < 60:
        return "%dm" % minuti
    return "%dh %02dm" % (minuti // 60, minuti % 60)


def riga(*celle):
    print("  " + "".join(str(c).ljust(l) for c, l in celle))


def main():
    economia = carica(ECONOMIA)
    catalogo = carica(CATALOGO)
    per_ora = float(economia["credits_per_hour"])
    prezzi = economia["prices"]
    predefinito = int(economia["price_default"])
    conta = modelli_per_tipo(catalogo)

    print()
    print("ECONOMIA: %g crediti all'ora | rimborso %d%% | terreno %d cr/gradino"
          % (per_ora, round(float(economia["refund_ratio"]) * 100),
             int(economia["terrain_cost_per_level"])))

    print()
    print("QUANTO COSTA, IN CONCENTRAZIONE")
    riga(("tipo", 16), ("prezzo", 9), ("tempo", 10), ("modelli", 8))
    for tipo, prezzo in sorted(prezzi.items(), key=lambda kv: kv[1]):
        riga((tipo, 16), ("%d cr" % prezzo, 9),
             (tempo(ore(prezzo, per_ora)), 10), (conta.get(tipo, 0), 8))
    riga(("(non elencati)", 16), ("%d cr" % predefinito, 9),
         (tempo(ore(predefinito, per_ora)), 10), ("", 8))

    print()
    print("LA PRIMA SESSIONE")
    for minuti in PRESET:
        guadagno = minuti / 60.0 * per_ora
        alla_portata = sorted(
            (t for t, p in prezzi.items() if p <= guadagno),
            key=lambda t: prezzi[t])
        print("  %3d min -> %5.1f crediti: %s" % (
            minuti, guadagno,
            ", ".join(alla_portata) if alla_portata else "niente, nemmeno un albero"))

    print()
    print("I PRIMI GIORNI (crediti totali, spendendo nulla)")
    riga(("profilo", 22), ("giorno 1", 10), ("giorno 3", 10),
         ("settimana", 11), ("mese", 8))
    for nome, minuti in PROFILI:
        al_giorno = minuti / 60.0 * per_ora
        riga((nome, 22),
             ("%.0f cr" % al_giorno, 10),
             ("%.0f cr" % (al_giorno * 3), 10),
             ("%.0f cr" % (al_giorno * 7), 11),
             ("%.0f cr" % (al_giorno * 30), 8))

    costo = sum(prezzi.get(t, predefinito) * n for t, n in QUARTIERE.items())
    pezzi = sum(QUARTIERE.values())
    print()
    print("UN PRIMO QUARTIERE (%d pezzi: %s)" % (
        pezzi, ", ".join("%d %s" % (n, t) for t, n in QUARTIERE.items())))
    print("  costa %d crediti, cioe %s di concentrazione" % (costo, tempo(ore(costo, per_ora))))
    for nome, minuti in PROFILI:
        giorni = costo / (minuti / 60.0 * per_ora)
        print("    %-22s %.0f giorni" % (nome, giorni))
    print()


if __name__ == "__main__":
    main()
