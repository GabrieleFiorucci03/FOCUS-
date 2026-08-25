<div align="center">

# FOCUS!

**Il tempo che passi a concentrarti diventa una città.**

Imposti un timer, lavori o studi per davvero, e ogni minuto di concentrazione
si trasforma in crediti da spendere per tirare su, pezzo dopo pezzo, una città
3D isometrica.

![Il kit residenziale generato in Blender](assets/previews/catalog_residential.png)

![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/linguaggio-GDScript-355570)
![Blender](https://img.shields.io/badge/Blender-5.2-ea7600?logo=blender&logoColor=white)
![Stato](https://img.shields.io/badge/stato-fase%203%20di%205-yellow)
![Licenza](https://img.shields.io/badge/licenza-GPL--3.0-blue)

</div>

---

> [!NOTE]
> **Progetto in sviluppo.** Oggi funzionano il timer, l'economia, il salvataggio
> e il mondo 3D con la sua camera. Quello che ancora non c'è è il negozio: gli
> edifici si vedono, ma non si comprano né si piazzano. La roadmap qui sotto
> dice dove siamo.

## L'idea

Le app di produttività ti danno una spunta e una statistica. Qui la ricompensa
è qualcosa che **resta e si vede crescere**: un'ora di concentrazione vale dieci
crediti, dieci crediti valgono un quartiere in più.

```
┌─────────────────┐     crediti     ┌─────────────────┐
│  MODALITÀ FOCUS │ ──────────────► │  MODALITÀ CITTÀ │
│  (timer, UI 2D) │                 │  (mondo 3D)     │
└─────────────────┘                 └─────────────────┘
         │                                   │
         └──────────► SaveManager ◄──────────┘
              (crediti, mondo, statistiche)
```

Nessun blocco dei siti, nessun controllo, nessuna penalità: il timer va **a
fiducia**. L'unica persona che imbrogli sei tu.

## Com'è adesso

![La schermata di focus](docs/timer.png)

Durata libera in ore e minuti, preset rapidi, pausa e ripresa, crediti e
statistiche sempre a schermo.

![Il mondo 3D](docs/citta.png)

Il mondo su griglia da 2 metri, generato da un seme: heightmap a gradini, mare,
laghi, fiumi che scendono dalle alture, spiagge, pianure e colline. La camera
ortografica ruota a scatti di 90° sui quattro lati. Del terreno non si salva
niente se non il seme — si rigenera identico. Gli edifici nell'immagine sono un
banco di prova piazzato dal codice, per verificare che i footprint del catalogo
si incastrino davvero. Il timer continua a scorrere mentre sei qui.

## Il kit di asset

72 modelli low-poly, nessuno modellato a mano: sono tutti **generati da script
Python in Blender**, con una direzione visiva condivisa chiamata *Focus Grove* —
volumi morbidi, materiali flat, pareti calde, tetti in terracotta, accenti teal.

|  | Contenuto |
|---|---|
| **Residenziale** | 10 case, 6 condomini, 2 palazzoni, 4 ville, 3 torri |
| **Urbano** | 6 negozi, 3 uffici, 3 fabbriche, 4 parchi, scuole, polizia, vigili del fuoco, sanità |
| **Infrastrutture** | 10 moduli di strada, eolico, torre idrica, solare, campi sportivi, fienile e serre |
| **Natura** | 6 alberi riutilizzabili |

<div align="center">

![Catalogo urbano](assets/previews/catalog_urban.png)

</div>

Il generatore è **deterministico**: stesso ID e stesso seed producono sempre lo
stesso modello. Cambi un parametro di stile e rigeneri tutta la libreria in un
colpo solo.

```powershell
blender --background --python tools/blender/generate_mvp_assets.py
```

Ogni `.glb` ha accanto un JSON con footprint, altezza, conteggio dei triangoli e
seed, più un `catalog.json` complessivo che Godot legge per costruire il negozio.

## Provalo

Serve **Godot 4.x** (versione standard, non .NET). Blender serve solo se vuoi
rigenerare gli asset.

```bash
git clone https://github.com/GabrieleFiorucci03/FOCUS-.git
```

Apri la cartella con Godot e premi `F5`. Al primo avvio l'engine importa i 72
`.glb`, ci mette una ventina di secondi.

## Roadmap

| Fase | Cosa | Stato |
|---|---|---|
| 0 | Setup, progetto, struttura | ✅ |
| 1 | Timer, crediti, salvataggio | ✅ |
| 2 | Griglia 3D e camera isometrica | ✅ |
| 3 | Terreno procedurale, biomi, fiumi | ✅ |
| 3.5 | Pipeline asset Blender | ✅ |
| 4 | Negozio e costruzione sulla griglia | ⬜ |
| 5 | Bilanciamento, suoni, statistiche | ⬜ |

Il dettaglio sta in [`PIANO.md`](PIANO.md).

## Struttura

```
FOCUS!/
├─ scenes/            main · focus · city · ui
├─ scripts/
│  ├─ autoload/       config.gd · save_manager.gd
│  ├─ focus/          focus_timer.gd · focus_screen.gd
│  └─ city/           city_grid.gd · city_terrain.gd · terrain_mesh.gd
│                       iso_camera.gd · city_view.gd
├─ data/              economy.json
├─ assets/
│  ├─ models/generated/   72 .glb + catalog.json
│  └─ previews/           render del catalogo
└─ tools/blender/     la pipeline che genera tutto
```

## Bilanciare l'economia

Tutti i numeri stanno in [`data/economy.json`](data/economy.json). Cambi il file,
riavvii, fatto — non si tocca il codice.

```json
{
  "credits_per_hour": 10.0,
  "credits_on_early_stop": true,
  "min_session_seconds": 60
}
```

`credits_on_early_stop` decide se interrompere una sessione a metà paga il tempo
già svolto o non paga niente.

## Tre dettagli di cui vale la pena parlare

**Il timer non conta i frame.** Contare i `delta` di `_process` accumula errore e
si ferma se la finestra viene sospesa. Su una sessione da due ore è la differenza
tra misurare e stimare, quindi il countdown legge l'orologio monotono di sistema
e i frame servono solo ad aggiornare la UI.

**I crediti frazionari non si buttano.** Tre minuti valgono mezzo credito, e mezzo
credito non è zero: il resto sotto l'unità resta da parte e si somma alla sessione
dopo. Venti sessioni da tre minuti valgono esattamente quanto un'ora piena.

**Il salvataggio sopravvive alle versioni future.** In caricamento il file JSON
viene innestato sopra uno schema di default: quando una fase nuova aggiungerà
chiavi, i salvataggi vecchi continueranno ad aprirsi invece di rompersi.

## Licenza

[GNU General Public License v3.0](LICENSE) — Copyright © 2026 Gabriele Fiorucci.

Sei libero di usare, studiare, modificare e ridistribuire questo progetto. Se ne
distribuisci una versione modificata, devi rilasciarne il codice sorgente sotto
la stessa licenza.
