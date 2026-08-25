# FOCUS! — Piano di sviluppo

App per PC: un cronometro/timer che premia il tempo di concentrazione dell'utente.
L'utente imposta un timer e lavora/studia/si allena per quel tempo. In cambio guadagna
crediti da spendere in un negozio per costruire gradualmente una città in un mondo 3D.

## Concept

- **Modalità Focus**: l'utente imposta un countdown e si concentra. Ogni ora di focus → crediti.
- **Modalità Città**: mondo 3D a griglia (stile TheoTown/Minecraft) dove piazzare edifici,
  strade, alberi e foreste acquistati col negozio.
- Le due modalità sono collegate dall'economia (crediti) e dal salvataggio.

```
┌─────────────────┐     crediti     ┌─────────────────┐
│  MODALITÀ FOCUS │ ──────────────► │  MODALITÀ CITTÀ │
│  (timer, UI 2D) │                 │  (mondo 3D)     │
└─────────────────┘                 └─────────────────┘
         │                                   │
         └──────────► SaveManager ◄──────────┘
              (crediti, mondo, statistiche)
```

## Stack tecnologico (deciso)

| Componente        | Scelta                                                         |
|-------------------|----------------------------------------------------------------|
| Motore app        | **Godot 4.x** (GDScript, versione standard non .NET)          |
| Timer             | Countdown a durata libera                                      |
| Anti-distrazione  | Nessuno (a fiducia)                                            |
| Mondo             | 3D a griglia, camera ortografica ruotabile a 4 lati           |
| Terreno           | Procedurale (FastNoiseLite)                                    |
| Modelli 3D        | Generati via script Python in Blender → esportati in `.glb`    |
| Livello utente    | Intermedio (si scrive codice vero)                            |

## Modello dati (salvataggio su disco)

```
SaveData:
  credits: int                 # crediti disponibili
  total_focus_seconds: int     # statistica totale
  world:
    seed: int                  # per rigenerare il terreno
    size: Vector2i             # es. 32x32 moduli
    tiles: [                   # solo le celle modificate
      { pos: Vector2i, type: "casa_01", rotation: int }
    ]
```

Si salvano solo le celle costruite (non tutto il terreno), che si rigenera dal `seed`.

## Economia — valori di partenza (da bilanciare)

| Voce           | Valore proposto      |
|----------------|----------------------|
| Guadagno       | ~10 crediti / ora    |
| Albero         | 2 crediti            |
| Strada         | 3 crediti            |
| Casa piccola   | 8 crediti            |
| Edificio grande| 25 crediti           |

Valori in un unico file di config per ritoccarli facilmente.

## Pipeline asset (Blender)

```
script Python (bpy)  ──►  Blender (headless)  ──►  modello.glb  ──►  Godot
   genera_casa.py         costruisce la mesh      file 3D          lo importa
```

- Ogni oggetto ha uno script che ne costruisce la geometria (base, muri, tetto, colori).
- Blender eseguibile headless: `blender --background --python genera_casa.py`.
- Stile condiviso (palette colori, proporzioni, bevel) in un file comune → coerenza.
- Output in `assets/models/`, letto direttamente da Godot.
- Cambiando i parametri si rigenera tutta la libreria in un colpo.

## Roadmap a fasi

### Fase 0 — Preparazione ✅ completata
- [x] Installare **Godot 4.x** (versione standard) — Godot 4.7.2 stable via winget
- [x] Installare **Blender** (per generare i modelli) — Blender 5.2.1
- [x] Creare progetto Godot + struttura cartelle
- [x] Git per il versioning (`.gitignore` + `.gitattributes`)

### Fase 1 — Core loop: Timer + Crediti + Salvataggio ✅ completata
- [x] `SaveManager` autoload — JSON in `user://focus_save.json`, innesto sui default
      così un salvataggio vecchio non si rompe quando lo schema cresce
- [x] Schermata Timer + countdown a durata libera (ore/minuti + preset 25/50/90)
- [x] Accredito crediti proporzionale; il resto sotto l'unità resta da parte e si
      somma alla sessione dopo, quindi 20 sessioni da 3 minuti valgono un'ora
- [x] Statistiche base (sessioni, focus totale) + crediti sempre a schermo
- [x] `Config` autoload che legge `data/economy.json`

### Fase 2 — Mondo 3D + Camera ✅ completata
- [x] `CityGrid` — celle 2 x 2 m, ingombri multi-cella, rotazione, conversione
      griglia↔mondo
- [x] Camera ortografica isometrica su braccio snodato
- [x] Rotazione a 90° sui 4 lati con transizione, pan trascinando, zoom
- [x] Passaggio Focus↔Città senza fermare il timer
- [x] Banco di prova con 41 oggetti di tutte le taglie di footprint

### Fase 3 — Generazione terreno procedurale
- [ ] Heightmap (noise) → colline/pianure
- [ ] Biomi (mare, lago, pianura, collina) + fiumi
- [ ] Seed salvato + materiali per bioma

### Fase 3.5 — Pipeline asset Blender ✅ completata
- [x] Script base con stile condiviso — `tools/blender/focus_asset_specs.py` (stile "Focus Grove")
- [x] Alberi, case, edifici, strade e servizi: **72 asset** generati
- [x] Comando unico per rigenerare la libreria → `assets/models/generated/`
- [x] `catalog.json` con footprint, altezza, triangoli e seed
- [x] Render di anteprima in `assets/previews/`

### Fase 4 — Negozio + Costruzione
- [ ] Catalogo oggetti (dati) collegato ai `.glb`
- [ ] UI negozio + logica acquisto (scala crediti, controllo saldo)
- [ ] Modalità piazzamento sulla griglia + anteprima + rotazione + salvataggio

### Fase 5 — Rifinitura
- [ ] Bilanciamento economia
- [ ] UI/UX (menu, transizioni Focus↔Città)
- [ ] Suoni e feedback (fine timer, acquisto, piazzamento)
- [ ] Pannello statistiche (streak, ore totali)
- [ ] Test generale e correzione bug

## Struttura del progetto

```
FOCUS!/
  project.godot          # progetto Godot 4.7
  scenes/                # main, focus, city, ui
  scripts/               # autoload, focus, city, ui
  data/                  # cataloghi ed economia (JSON)
  assets/models/generated/   # 72 .glb + catalog.json
  tools/blender/         # pipeline di generazione (ignorata da Godot)
```

Convenzioni ereditate dalla pipeline asset: **cella 2 x 2 m**, origine al centro
della base, fronte verso `-Y`, collisioni con suffisso `-colonly`.

## Scelte di progetto

- **Il timer legge l'orologio monotono**, non i delta dei frame: un calo di FPS o
  una finestra sospesa non falsano un'ora di concentrazione.
- **Un'interruzione manuale paga il tempo svolto** (sopra `min_session_seconds`).
  Si disattiva con `credits_on_early_stop: false` in `data/economy.json`.
- **Le coordinate nel salvataggio sono array `[x, y]`**, non `Vector2i`: JSON non
  conosce i tipi di Godot. La conversione avviene al caricamento.
- **Niente `GridMap`.** Vuole una `MeshLibrary` e ragiona per celle 1x1, mentre il
  catalogo arriva a footprint 4x4: ingombri multi-cella e rotazione andrebbero
  comunque reimplementati sopra di lui. `CityGrid` è un dizionario
  `Vector2i → piazzamento`, ~140 righe.
- **Le due schermate restano entrambe istanziate**, si mostrano e si nascondono.
  Distruggerle a ogni cambio fermerebbe il countdown appena vai a vedere la città.
- **La città smette di girare quando non si vede** (`process_mode`), la schermata
  focus no: è il timer che deve continuare.

## Verifiche fatte sugli asset

Misurando l'ingombro **al livello del suolo** di tutti e 72 i modelli contro il
footprint dichiarato nel catalogo:

- Nessun modello ha geometria sotto `y = 0`: l'origine al centro della base
  regge su tutta la libreria.
- 3 modelli debordano dal footprint di 12–22 cm (`COM_LOW_1x1_003`,
  `COM_LOW_2x1_004`, `PARK_1x1_004`): sono tettoie e gradini che arrivano a
  terra. Non rompono la griglia, ma due edifici adiacenti si sfiorano.
- 15 modelli hanno la base non centrata di 6–37 cm, quasi sempre verso `+Z`:
  ingressi e portici sul fronte. Stessa conclusione.

Nessuno di questi è bloccante. Se dà fastidio si sistema nel generatore Blender,
non in Godot.

## Prossimo passo

Fase 3: heightmap con `FastNoiseLite`, biomi (mare, lago, pianura, collina),
fiumi, seed salvato e materiali per bioma. Poi la griglia dovrà tenere conto
della quota del terreno.
