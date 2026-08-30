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

"""L'icona dell'app: un cronometro, disegnato una volta e scritto in due formati.

Godot vuole un `.svg` per il progetto e l'editor; l'eseguibile Windows vuole un
`.ico` con dentro sei misure diverse. Sono la stessa icona, quindi la geometria
sta scritta qui una volta sola e i due file escono da queste misure: ritoccare
un colore in un formato e dimenticarlo nell'altro non è possibile.

    python tools/icon/genera_icona.py

Serve Pillow, e solo per il .ico. Il disegno è al centro di un quadrato da 128:
lancetta in su sulle dodici, perché un cronometro fermo sull'inizio è la cosa
giusta da mettere sull'icona di un'app che ti chiede di cominciare.
"""

import pathlib
import sys

RADICE = pathlib.Path(__file__).resolve().parents[2]

## Il lato del disegno, nelle unità in cui sono espresse tutte le misure sotto.
LATO = 128

## La palette, la stessa di "Focus Grove" che governa i modelli 3D.
FONDO = "#1f2933"
TEAL = "#2ec4b6"
LANCETTA = "#ff8a5c"

## Il cronometro: cassa, lancetta, corona.
RAGGIO_ANGOLI = 24
CENTRO = (64, 68)
RAGGIO = 38
SPESSORE = 8
LANCETTA_FINO_A = 44
CORONA = (52, 18, 24, 10, 5)  # x, y, larghezza, altezza, raggio

## Le misure che finiscono nel .ico. Windows le pesca a seconda del contesto:
## 16 nella barra del titolo, 256 nell'anteprima grande di Esplora risorse.
MISURE = [256, 128, 64, 48, 32, 16]

## Quanto si disegna in grande prima di rimpicciolire. Pillow non ha
## antialiasing sui contorni: si disegna a 8x e si riduce, ed è la riduzione a
## fare i bordi morbidi.
SCALA = 8


def scrivi_svg(percorso):
    x, y, larghezza, altezza, raggio = CORONA
    svg = """<svg xmlns="http://www.w3.org/2000/svg" width="{lato}" height="{lato}" viewBox="0 0 {lato} {lato}">
  <rect width="{lato}" height="{lato}" rx="{angoli}" fill="{fondo}"/>
  <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{teal}" stroke-width="{spessore}"/>
  <path d="M{cx} {cy}V{fino}" stroke="{lancetta}" stroke-width="{spessore}" stroke-linecap="round"/>
  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{teal}"/>
</svg>
""".format(lato=LATO, angoli=RAGGIO_ANGOLI, fondo=FONDO, cx=CENTRO[0], cy=CENTRO[1],
           r=RAGGIO, teal=TEAL, spessore=SPESSORE, lancetta=LANCETTA,
           fino=LANCETTA_FINO_A, x=x, y=y, w=larghezza, h=altezza, rx=raggio)
    # Scritto in binario: cosi' i fine riga restano quelli del testo qui
    # sopra, e su Windows il file non esce con i CRLF che lo farebbero
    # risultare modificato a ogni rigenerazione.
    percorso.write_bytes(svg.encode("utf-8"))
    return svg


def disegna(lato):
    """Il cronometro su una tela quadrata di `lato` pixel, disegnato in grande."""
    from PIL import Image, ImageDraw

    s = lato * SCALA / float(LATO)
    tela = Image.new("RGBA", (lato * SCALA, lato * SCALA), (0, 0, 0, 0))
    penna = ImageDraw.Draw(tela)

    penna.rounded_rectangle(
        [0, 0, lato * SCALA - 1, lato * SCALA - 1],
        radius=RAGGIO_ANGOLI * s, fill=FONDO)

    cx, cy = CENTRO[0] * s, CENTRO[1] * s
    r = RAGGIO * s
    penna.ellipse([cx - r, cy - r, cx + r, cy + r], outline=TEAL, width=int(SPESSORE * s))

    # La lancetta ha le punte tonde: due cerchi alle estremità fanno lo stesso
    # lavoro dello stroke-linecap dell'SVG.
    mezzo = SPESSORE * s / 2.0
    penna.line([cx, cy, cx, LANCETTA_FINO_A * s], fill=LANCETTA, width=int(SPESSORE * s))
    for punta in (cy, LANCETTA_FINO_A * s):
        penna.ellipse([cx - mezzo, punta - mezzo, cx + mezzo, punta + mezzo], fill=LANCETTA)

    x, y, larghezza, altezza, raggio = CORONA
    penna.rounded_rectangle(
        [x * s, y * s, (x + larghezza) * s, (y + altezza) * s],
        radius=raggio * s, fill=TEAL)

    return tela.resize((lato, lato), Image.LANCZOS)


def scrivi_ico(percorso):
    grande = disegna(max(MISURE))
    grande.save(percorso, format="ICO", sizes=[(m, m) for m in MISURE])


def main():
    svg = RADICE / "icon.svg"
    ico = RADICE / "icon.ico"
    scrivi_svg(svg)
    print("scritto %s" % svg.relative_to(RADICE))
    try:
        scrivi_ico(ico)
    except ImportError:
        sys.exit("serve Pillow per il .ico:  python -m pip install Pillow")
    print("scritto %s (%s)" % (ico.relative_to(RADICE),
                               ", ".join("%dx%d" % (m, m) for m in MISURE)))


if __name__ == "__main__":
    main()
