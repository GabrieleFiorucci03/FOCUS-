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
    tiles: [                   # solo le celle costruite
      { pos: [x, z], type: "RES_LOW_1x1_001", rotation: int, level: int }
    ]
    terrain_edits: [           # solo le quote toccate a mano (Fase 4.5)
      { pos: Vector2i, level: int }
    ]
```

Si salvano solo le celle costruite e le quote modificate: tutto il resto del
terreno si rigenera dal `seed`. In JSON `Vector2i` non esiste, le coordinate
viaggiano come array `[x, z]`.

Il `level` di una cella non è ridondante col `seed`: piazzare spiana il lotto,
quindi il suolo sotto una costruzione non è più quello che il seme aveva
previsto. Senza quel numero, riaprendo la partita le case si ritroverebbero su
un terreno diverso da quello su cui erano state messe.

## Economia — valori di partenza (da bilanciare)

| Voce                  | Valore               |
|-----------------------|----------------------|
| Guadagno              | ~10 crediti / ora    |
| Albero                | 2 crediti            |
| Strada                | 3 crediti            |
| Casa                  | 8 crediti            |
| Palazzina             | 25 crediti           |
| Torre                 | 45 crediti           |
| Rimborso in demolizione | 50 % del prezzo    |

Tutto in `data/economy.json`, **un prezzo per tipo** (il campo `kind` del
catalogo asset), non per singolo modello: 19 numeri da bilanciare invece di 91,
e due case che si somigliano non possono costare in modo diverso per sbaglio.
Un tipo non elencato costa `price_default`.

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

### Fase 3 — Generazione terreno procedurale ✅ completata
- [x] Heightmap con `FastNoiseLite`, quantizzata a gradini da 0.5 m
- [x] Biomi: mare, lago, fiume, spiaggia, pianura, collina
- [x] Fiumi che scendono dalle alture e laghi dove restano incastrati
- [x] Seed salvato, terreno rigenerato identico; colori per bioma nei vertici
- [x] `spiana()` per livellare un lotto prima di costruirci

### Fase 3.5 — Pipeline asset Blender ✅ completata
- [x] Script base con stile condiviso — `tools/blender/focus_asset_specs.py` (stile "Focus Grove")
- [x] Alberi, case, edifici, strade, servizi, rampe e ponti: **91 asset** generati
- [x] Comando unico per rigenerare la libreria → `assets/models/generated/`
- [x] `catalog.json` con footprint, altezza, triangoli e seed
- [x] Render di anteprima in `assets/previews/`

### Fase 4 — Negozio + Costruzione ✅ completata
- [x] `CityCatalog` — unisce il catalogo tecnico della pipeline a `data/catalog.json`
      (nomi italiani, scaffali, regole) e ai prezzi per tipo di `economy.json`
- [x] UI negozio: cinque scaffali, prezzi, saldo, e le voci fuori portata spente
      invece che nascoste — sapere quanto manca è metà del motivo per tornare a
      fare focus
- [x] Puntamento col mouse: collisione sul terreno e raggio dalla camera
- [x] Modalità piazzamento con anteprima colorata, rotazione con `R`, controllo
      del saldo, addebito e salvataggio della cella
- [x] Demolizione con rimborso del 50 % (arrotondato per difetto: costruire e
      demolire non deve far guadagnare crediti)
- [x] Ricostruzione della città dal salvataggio all'avvio, spianamenti compresi

**Politica di livellamento decisa: piazzare spiana al livello più basso del
lotto**, gratis. Non svuota la Fase 4.5 per due motivi. Il primo è che un
oggetto da una cella sola non tocca mai il terreno — il minimo di una cella è
la cella stessa — quindi il suolo si muove solo sotto le costruzioni larghe a
cavallo di un gradino. Il secondo è che spianare va sempre e solo verso il
basso: colline, isole e conche restano roba dello strumento terreno.

Lo spianamento vive quanto la costruzione che l'ha chiesto: demolendo, il lotto
torna alla quota del seme. È l'unico comportamento coerente con il salvataggio,
che dei lotti spianati si ricorda solo finché c'è sopra qualcosa.

### Fase 4.5 — Modellare il terreno

Alzare e abbassare il suolo per farsi colline, laghi, fiumi e isole artificiali.

La Fase 4 ha costruito la macchina che serve — raggio dal mouse alla cella,
anteprima, controllo del saldo, addebito, salvataggio — e lo strumento terreno
la riusa tal quale con un'azione diversa.

Quello che c'è già e non va rifatto:

- Il puntamento: `CityView._cella_puntata()` dà la cella sotto il cursore, e
  `TerrainMesh.costruisci_selezione()` disegna il riquadro sulla cella bersaglio
  già alla quota di arrivo.
- Le quote sono numeri interi per cella: alzare è `livelli[i] += 1`.
- `CityTerrain.spiana()` livella un lotto, `livello_piu_basso()` sceglie la
  quota, `ripristina()` riporta delle celle a com'erano appena uscite dal seme.
- La classificazione delle acque è un flood fill dal bordo mappa, e questo
  risponde da solo a tre casi diversi senza codice dedicato:
  scavare una conca chiusa sotto il livello del mare produce un **lago**,
  collegarla alla costa con un canale la trasforma in **mare**,
  alzare il fondale fin sopra il pelo dell'acqua produce un'**isola**.

Da fare:

- [ ] Strumenti alza / abbassa / livella, con anteprima della cella bersaglio
- [ ] Ricalcolo di biomi e acque dopo ogni modifica (rieseguire il flood fill).
      Attenzione: `spiana()` oggi riclassifica la cella a mano in pianura o
      collina, che basta perché spiana solo all'asciutto e verso il basso.
      Alzare e abbassare per scelta non se la cava così.
- [ ] Ricostruzione della mesh: oggi si rifà tutto il terreno in un colpo, su
      32x32 regge anche a ogni click; se la mappa cresce va spezzata in blocchi
- [ ] Salvataggio delle quote modificate (`terrain_edits`, additivo allo schema).
      Va tenuto distinto dal `level` delle celle costruite, che è già lì e che
      la demolizione disfa: una collina scavata a mano invece deve restare.
- [ ] Costo in crediti, altrimenti il terraforming è gratis e l'economia salta
- [ ] Decidere cosa succede a un edificio su una cella che cambia quota:
      si rimuove, si blocca l'operazione, o scende con il terreno
- [ ] Decidere se limitare il dislivello tra celle adiacenti o lasciare i dirupi
- [ ] Decidere cosa fa una campata quando le si scava sotto o le si alza la
      sponda: la sua quota è decisa al momento del piazzamento e poi non si
      muove più

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
  data/                  # economy.json (prezzi) e catalog.json (nomi, scaffali)
  assets/models/generated/   # 91 .glb + catalog.json
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
- **Le quote del terreno sono discrete**, non continue. Un edificio appoggia in
  piano senza compenetrare il suolo e dire se un lotto è pianeggiante è
  immediato; un terreno liscio costringerebbe a deformare o sollevare ogni casa.
- **Piazzare spiana al livello più basso del lotto.** Alla mediana un lotto in
  pendenza si sarebbe scavato da una parte e riempito dall'altra; al minimo si
  scava e basta, e soprattutto un oggetto 1x1 non tocca mai il terreno, perché
  il minimo di una cella sola è la cella stessa.
- **Un ponte si aggancia, non si appoggia dove capita.** Una campata va solo
  sull'acqua e solo attaccata a una riva o a un'altra campata, e sta un gradino
  sopra la sponda: è la composizione che la pipeline aveva già verificato in
  Blender (`tools/blender/render_transport_demo.py`), dove la rampa colma
  esattamente quei 0,5 m. Le pile non si comprano e non occupano celle — la
  griglia ne ammette una sola per cella e sarebbe già presa dall'impalcato —
  ma nascono sotto la campata scegliendo l'altezza sulla luce da colmare.
- **Il terreno è l'unica cosa che il raggio del mouse colpisce.** Gli edifici
  hanno le collisioni spente: puntando una casa si vuole la cella su cui poggia,
  non la sua grondaia, e demolire vuol dire cliccare quello che si vede.
- **Il prezzo sta sul tipo, non sul modello.** Diciannove numeri invece di
  novantuno, e due case che si somigliano non possono costare in modo diverso
  per una distrazione.
- **I colori dei biomi viaggiano nei vertici**, non in un materiale per tipo:
  tutto il terreno è una superficie sola e un bioma nuovo non aggiunge un
  materiale. Vanno convertiti con `srgb_to_linear()`, altrimenti Godot li usa
  come lineari e il terreno viene slavato.

## Verifiche fatte sul generatore di terreno

Su 200 mondi 32x32 generati con semi diversi:

| Misura | Risultato |
|---|---|
| Mondi con almeno un fiume | 100 % |
| Mondi con almeno un lago | 82.5 % |
| Mondi con collina | 100 % |
| Terra emersa | 66.6 % della mappa |
| Posizioni 3x3 pianeggianti | 39 in media |

Stesso seme → stesso mondo, seme diverso → mondo diverso: verificato.

Le 39 posizioni 3x3 sono poche per una città intera, ma la Fase 4 livella il
lotto al momento del piazzamento (`spiana()` c'è già), quindi non è un limite.

## Verifiche fatte sugli asset

Misurando l'ingombro **al livello del suolo** contro il footprint dichiarato nel
catalogo, sui 72 modelli del primo kit (prima che arrivassero rampe e ponti):

- Nessun modello ha geometria sotto `y = 0`: l'origine al centro della base
  regge su tutta la libreria.
- 3 modelli debordano dal footprint di 12–22 cm (`COM_LOW_1x1_003`,
  `COM_LOW_2x1_004`, `PARK_1x1_004`): sono tettoie e gradini che arrivano a
  terra. Non rompono la griglia, ma due edifici adiacenti si sfiorano.
- 15 modelli hanno la base non centrata di 6–37 cm, quasi sempre verso `+Z`:
  ingressi e portici sul fronte. Stessa conclusione.

Nessuno di questi è bloccante. Se dà fastidio si sistema nel generatore Blender,
non in Godot.

## Verifiche fatte sul negozio e sul cantiere

Su un mondo 32x32, guidando `CityView` dal di fuori:

| Prova | Esito |
|---|---|
| 91 asset letti, 87 in vendita (i 4 sostegni no) | ok |
| Nessun nome ripetuto fra le 91 voci | ok |
| Una scuola 3x3 su quote `[4,4,5,4,4,5,4,5,6]` | spiana tutto a 4 |
| Una casa 1x1 | non tocca il terreno |
| Casa sull'acqua, campata a terra, ponte al largo | rifiutati, uno per volta |
| Campata su una sponda a quota 4 | posata a 2,50 m, con la pila sotto |
| Campata successiva al largo | eredita la quota, resta in piano |
| Scuola da 35 demolita | +17 crediti, e il lotto torna a `[4,4,5,4,4,5,4,5,6]` |
| Riapertura della partita | stesse costruzioni, stesso terreno |

Guardati anche i frame veri: il ponte con le sue rampe attraversa il fiume, il
fantasma verde della palazzina sta alla quota a cui il lotto verrà spianato, e
il negozio elenca i prezzi con le voci fuori portata spente.

## Prossimo passo

Fase 4.5: alzare e abbassare il terreno per scelta, con il costo in crediti e il
salvataggio delle quote modificate. Il puntamento, l'anteprima e l'addebito sono
già in piedi dalla Fase 4: quello che manca è l'azione.
