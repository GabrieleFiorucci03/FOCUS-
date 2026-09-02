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
    terrain_edits: [           # solo le quote spianate, cella per cella
      { pos: [x, z], level: int }
    ]
```

Si salvano solo le celle costruite e le quote modificate: tutto il resto del
terreno si rigenera dal `seed`. In JSON `Vector2i` non esiste, le coordinate
viaggiano come array `[x, z]`.

`terrain_edits` non è ridondante col `seed`: piazzare spiana il lotto, quindi il
suolo lì non è più quello che il seme aveva previsto. Ci finiscono solo le celle
scese davvero — un lotto 3x3 livellato al minimo di solito ne muove tre o
quattro, non nove — e ci restano anche dopo che la costruzione è stata demolita:
sbancare è una modifica al mondo, non un pezzo dell'edificio.

Il `level` di un tile è un'altra cosa: è la quota a cui sta l'oggetto. Per una
casa coincide col terreno, per una campata di ponte no, perché quella sta
sospesa sopra l'acqua.

## Economia — bilanciata in Fase 5

I prezzi non si scelgono in crediti ma **in minuti**, e poi si moltiplicano per
`credits_per_hour`. È l'unica domanda che conta davvero: quanto tempo di
concentrazione deve costare una casa?

| Voce                    | Tempo    | Crediti |
|-------------------------|----------|---------|
| Guadagno                | —        | 24 / ora |
| Albero                  | 5 min    | 2       |
| Strada                  | 7,5 min  | 3       |
| Terreno (un gradino)    | 5 min    | 2       |
| Casa, parco             | 25 min   | 10      |
| Negozio                 | 45 min   | 18      |
| Villa, palazzina        | 1h 15m   | 30      |
| Scuola                  | 3h       | 72      |
| Palazzone               | 4h       | 96      |
| Torre                   | 5h       | 120     |
| Rimborso in demolizione | —        | 50 % del prezzo |

Tutto in `data/economy.json`, **un prezzo per tipo** (il campo `kind` del
catalogo asset), non per singolo modello: 19 numeri da bilanciare invece di 91,
e due case che si somigliano non possono costare in modo diverso per sbaglio.
Un tipo non elencato costa `price_default`.

Le due misure che hanno deciso questi numeri, ricavate con
`tools/balance/simula_economia.py`:

- **La prima sessione da 25 minuti compra una casa.** A 10 crediti l'ora ne
  comprava due alberi, e il primo premio dell'app era un cespuglio.
- **Un primo quartiere (37 pezzi) costa 13 ore**, cioè due settimane a un'ora al
  giorno. Erano 23 ore, che sono più di un mese.

La forbice fra l'albero e la torre è passata da 22 a 60: le cose grandi restano
traguardi di giorni mentre ogni singola sessione paga comunque qualcosa da
posare.

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
- [x] Salvataggio delle quote spianate (`terrain_edits`) e ricostruzione della
      città all'avvio: prima il terreno, poi quello che ci sta sopra

**Politica di livellamento decisa: piazzare spiana al livello più basso del
lotto**, gratis. Non svuota la Fase 4.5 per due motivi. Il primo è che un
oggetto da una cella sola non tocca mai il terreno — il minimo di una cella è
la cella stessa — quindi il suolo si muove solo sotto le costruzioni larghe a
cavallo di un gradino. Il secondo è che spianare va sempre e solo verso il
basso: colline, isole e conche restano roba dello strumento terreno.

**Demolendo, il lotto resta spianato.** Sbancare è una modifica al mondo, non un
pezzo dell'edificio: il terreno non deve rimbalzare su e giù ogni volta che si
cambia idea su cosa costruirci. Per questo lo spianamento si salva per conto suo
in `terrain_edits`, staccato dal tile, e sopravvive alla demolizione anche
riaprendo la partita.

### Fase 4.5 — Modellare il terreno ✅ completata

Alzare e abbassare il suolo per farsi colline, laghi e isole artificiali.

La Fase 4 ha costruito la macchina che serve — raggio dal mouse alla cella,
anteprima, controllo del saldo, addebito, salvataggio — e lo strumento terreno
la riusa tal quale con un'azione diversa.

Quello che c'è già e non va rifatto:

- Il puntamento: `CityView._cella_puntata()` dà la cella sotto il cursore, e
  `TerrainMesh.costruisci_selezione()` disegna il riquadro sulla cella bersaglio
  già alla quota di arrivo.
- Le quote sono numeri interi per cella: alzare è `livelli[i] += 1`.
- `CityTerrain.spiana()` livella un lotto, `livello_piu_basso()` sceglie la
  quota, `livello_naturale()` dice com'era la cella appena uscita dal seme.
- Il salvataggio delle quote: `terrain_edits` c'è già, lo scrive il piazzamento
  e lo rilegge l'avvio. Lo strumento terreno ci scrive dentro allo stesso modo.
- La classificazione delle acque è un flood fill dal bordo mappa, e questo
  risponde da solo a tre casi diversi senza codice dedicato:
  scavare una conca chiusa sotto il livello del mare produce un **lago**,
  collegarla alla costa con un canale la trasforma in **mare**,
  alzare il fondale fin sopra il pelo dell'acqua produce un'**isola**.

Fatto:

- [x] Attrezzi **alza**, **abbassa** e **livella** nel pannello, con l'anteprima
      del riquadro già alla quota di arrivo. Livella prende la quota col primo
      clic e poi la copia sulle celle che tocchi.
- [x] Ricalcolo di biomi e acque a ogni modifica, `CityTerrain.riclassifica()`
- [x] Costo in crediti (`terrain_cost_per_level`), **senza rimborso**: rimettere
      il terreno com'era è un lavoro come scavarlo
- [x] Salvataggio: le quote finiscono in `terrain_edits`, le stesse che già
      scriveva lo spianamento da piazzamento

Le regole, decise:

- **Sotto una costruzione il terreno non si tocca**, e vale anche per una
  campata di ponte: spostarle il fondale la lascerebbe appesa. Prima si
  demolisce.
- **Al massimo quattro gradini di salto fra due celle vicine** (2 m). Oltre, il
  terreno smette di essere un paesaggio e diventa una scacchiera di torri.
- **Le rampe salgono di un gradino solo.** Non è una scelta di bilanciamento: le
  rampe del kit salgono di 0,5 m, che è esattamente un gradino, e su un salto
  diverso resterebbero per aria.

Il ricalcolo ha portato con sé un cambio in generazione. Il flood fill delle
acque girava **prima** che i fiumi venissero scavati e le conche allagate, e
nessuno tornava a controllare: una conca allagata poteva essersi collegata al
mare senza che il mare se ne accorgesse. Ora la classificazione chiude i conti
anche in generazione, così il mondo appena nato è già quello che si otterrebbe
riclassificandolo — senza, il primo colpo di badile avrebbe cambiato qualche
cella dall'altra parte della mappa. Fiumi e laghi di collina se lo ricordano da
soli, perché il flood fill non saprebbe rimetterli al loro posto; il mare e le
conche sotto il suo livello no, ed è proprio quello che fa funzionare il canale
scavato a mano.

Restano fuori, e vanno decisi se serviranno:

- [x] Ricostruzione della mesh a blocchi — **chiusa**: il terreno è una mesh per
      zona, e una modifica rifà solo le zone che ha cambiato. Vedi «Una mesh per
      zona», in fondo.
- [x] Cosa fa una campata quando le si alza la sponda accanto — **chiuso in
      Fase 5**: il terreno che serve a una costruzione vicina non si tocca più.

### Fase 5 — Rifinitura ✅ completata

- [x] **Statistiche e streak.** Il salvataggio tiene un registro per giorno
      (`daily`), e da lì si ricavano serie in corso, record, giorni attivi e le
      ultime due settimane. Pannello con quattro cifre grandi e un grafico a
      colonne disegnato a mano, raggiungibile dal menu e dalla schermata focus.
- [x] **Bilanciamento economia.** Prezzi riscritti partendo dal tempo, con
      `tools/balance/simula_economia.py` a fare i conti sui file veri.
- [x] **Menu e transizioni.** Schermata iniziale con riepilogo della partita,
      continua / nuova città / statistiche / esci e il volume; dissolvenza corta
      fra focus e città; l'Esc apre e chiude il menu.
- [x] **Suoni.** Nove effetti sintetizzati all'avvio da `Sfx`, nessun file
      audio sul disco. Avvio, pausa, campana di fine, crediti, posa,
      demolizione, badile, rifiuto, clic.
- [x] **Correzione bug.** Il terreno che regge un ponte o una rampa non si
      tocca più; i pannelli davanti a qualcosa sono diventati opachi; la riga
      di stato della città non finisce più sotto il negozio.
- [x] 98 controlli automatici, tutti verdi, più i frame veri guardati a occhio.

Quello che la Fase 5 ha deciso, e perché:

- **Un giorno conta per lo streak se ci sta dentro almeno `min_session_seconds`
  di focus**, la stessa soglia sotto la quale un'interruzione non viene pagata.
  Una soglia sola: non ha senso che un tempo valga crediti ma non valga giornata.
- **La serie regge fino a mezzanotte.** Se oggi non hai ancora cominciato si
  conta da ieri: il giorno non è finito, e un contatore che si azzera alle 00:01
  punirebbe per una cosa che non è ancora successa.
- **Il giorno è quello dell'orologio locale**, non UTC: un'ora di studio finita
  a mezzanotte e mezza appartiene alla giornata in cui l'hai vissuta. I conti
  fra date invece si fanno a mezzogiorno e in UTC, così un fuso o un'ora legale
  non possono far saltare o ripetere un giorno.
- **Chiudere la finestra paga la sessione in corso.** Vale il tempo svolto,
  esattamente come premere Termina: chiudere una finestra non è un buon motivo
  per perdere mezz'ora di lavoro vero.
- **Il volume sopravvive a "nuova città".** È una preferenza dell'utente, non un
  pezzo della partita.

## Struttura del progetto

```
FOCUS!/
  project.godot          # progetto Godot 4.7
  scenes/                # main (+ menu), focus, city, ui (negozio, statistiche)
  scripts/               # autoload (config, salvataggio, suoni), focus, city, ui
  data/                  # economy.json (prezzi) e catalog.json (nomi, scaffali)
  assets/models/realistic/   # 91 .glb + catalog.json (in uso nel gioco)
  assets/models/generated/   # il kit MVP, tenuto come riferimento
  tools/blender/         # pipeline di generazione (ignorata da Godot)
  tools/balance/         # simulatore dell'economia (Python puro)
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
  il minimo di una cella sola è la cella stessa. Lo sbancamento resta anche
  dopo la demolizione: è una modifica al mondo, non un pezzo dell'edificio, e
  si salva staccato dal tile che l'ha chiesta.
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
- **Una rampa vuole un gradino, non un pendio.** Le rampe del kit salgono di
  0,5 m, che è esattamente un gradino del terreno: su un salto diverso
  resterebbero per aria. Da qui la regola — piede in piano, e appena oltre il
  lato alto qualcosa a un livello esatto sopra. Quel "qualcosa" può essere
  terreno o l'impalcato di un ponte, che è il motivo per cui le rampe da ponte
  esistono; e per questo la campata va posata prima delle sue rampe.
- **Modellare il terreno non si rimborsa, demolire sì.** Un edificio demolito
  esiste ancora, come materiale; una collina spianata no. E senza questa
  asimmetria il terraforming diventerebbe un magazzino di crediti a costo zero.
- **Il prezzo sta sul tipo, non sul modello.** Diciannove numeri invece di
  novantuno, e due case che si somigliano non possono costare in modo diverso
  per una distrazione.
- **Il flood fill delle acque ha l'ultima parola, sempre.** Mare e conche sotto
  il suo livello non vengono ricordati da nessuna parte: si rideducono a ogni
  modifica partendo dal bordo mappa. È questo che fa rispondere da solo a tre
  casi che sembrano diversi — la conca scavata diventa un lago, il canale che la
  collega alla costa la trasforma in mare, il fondale alzato diventa un'isola.
  Fiumi e laghi di collina fanno eccezione e si ricordano: quelli il flood fill
  non saprebbe rimetterli al loro posto. Una cella modellata perde l'etichetta,
  e se torna alla quota del seme se la riprende.
- **Lo streak non si salva, si ricalcola.** Su disco vanno solo i giorni e i
  loro secondi; serie in corso, record e giorni attivi si rideducono da lì a
  ogni lettura. È la stessa scelta che il mondo fa con il mare: quello che si
  può ridedurre non si scrive, così non può scollarsi da ciò che descrive. Un
  contatore salvato a parte, prima o poi, dice un numero che i giorni smentiscono.
- **I suoni si sintetizzano all'avvio, non si caricano.** Nove effetti nascono
  da una tabella di note — frequenza, entrata, durata, timbro — come i 91
  modelli nascono da uno script Blender. Nessun binario nel repository, nessun
  editor audio da aprire per cambiare un suono, e un banco che sta sotto i tre
  secondi di audio totale. Le note non sono a caso: quello che dice sì sale
  (do-sol, do-mi-sol), quello che dice no scende.
- **Il prezzo si sceglie in minuti.** In `economy.json` ci finiscono crediti, ma
  la domanda a monte è sempre "quanto tempo di concentrazione deve costare
  questa cosa", e il numero è quel tempo moltiplicato per `credits_per_hour`.
  Ragionare in crediti significa non sapere cosa si sta decidendo.
- **Il terreno che regge una costruzione vicina non si tocca.** Proteggere la
  cella sotto un edificio non bastava: una campata sta un gradino sopra la sua
  sponda e una rampa sale verso la cella accanto, e tutte e due decidono la
  propria quota al piazzamento e poi non la muovono più. Alzare la riva
  lasciava il ponte a mezz'aria senza un messaggio, perché il terreno da solo
  non sa cosa regge.
- **Un pannello che sta davanti a qualcosa è opaco.** Col fondo semitrasparente
  del tema di serie il terreno passava attraverso i prezzi del negozio e il
  countdown attraverso le statistiche. Un fondo solo, condiviso dai due
  pannelli, così restano parenti.
- **I colori dei biomi viaggiano nei vertici**, non in un materiale per tipo:
  tutto il terreno è una superficie sola e un bioma nuovo non aggiunge un
  materiale. Vanno convertiti con `srgb_to_linear()`, altrimenti Godot li usa
  come lineari e il terreno viene slavato.

## Verifiche fatte sul generatore di terreno

Su 200 mondi 32x32 generati con semi diversi:

| Misura | Risultato |
|---|---|
| Mondi con almeno un fiume | 100 % |
| Mondi con almeno un lago | 80.5 % |
| Mondi con collina | 100 % |
| Terra emersa | 66.6 % della mappa |
| Posizioni 3x3 pianeggianti | 39 in media |

Stesso seme → stesso mondo, seme diverso → mondo diverso: verificato.

I laghi erano l'82,5 % prima che la Fase 4.5 facesse chiudere i conti al flood
fill anche in generazione: quattro mondi su duecento avevano un lago che in
realtà era attaccato al mare.

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
| Le quote salvate dopo lo spianamento | 4, cioè solo le celle scese davvero |
| Scuola da 35 demolita | +17 crediti, e il lotto resta a `[4,4,4,4,4,4,4,4,4]` |
| Riapertura della partita | stesse costruzioni, e il lotto sgombro ancora spianato |

Guardati anche i frame veri: il ponte con le sue rampe attraversa il fiume, il
fantasma verde della palazzina sta alla quota a cui il lotto verrà spianato, e
il negozio elenca i prezzi con le voci fuori portata spente.

## Verifiche fatte su rampe e terreno

| Prova | Esito |
|---|---|
| Riclassificare un mondo intatto, su 100 semi | non sposta un solo bioma |
| Riclassificare due volte | stesso risultato di una |
| Rampa al piede di un gradino, quattro rotazioni | ne vale una sola, quella che punta in su |
| Rampa in piano, o girata al contrario | rifiutata |
| Posare una rampa | non spiana niente |
| Alza una cella | +1 gradino, 1 credito, quota nel salvataggio |
| Riabbassarla | torna al seme, sparisce dal salvataggio, e si ripaga |
| Livella | primo clic prende la quota, il secondo la copia |
| Scavare una conca chiusa fino sotto il mare | nasce un lago |
| Terreno sotto una casa, sotto una campata, oltre i 4 gradini | rifiutato, uno per volta |
| Riapertura della partita | quote, biomi e costruzioni identici |

Guardati anche i frame veri: la rampa punta in salita e i due tratti di strada
si saldano alle sue estremità senza scalini.

## Verifiche fatte sulla rifinitura

98 controlli automatici, guidando l'app dal di fuori con una scena usa e getta:

| Prova | Esito |
|---|---|
| Tre giorni pieni di fila | serie 3 |
| Un buco al quarto, poi cinque giorni pieni | serie 3, record 5 |
| Oggi ancora vuoto, ieri e l'altro ieri pieni | serie 2: la giornata non è finita |
| Un giorno da trenta secondi | non conta |
| Mezz'ora di focus | 12 crediti, e il giorno se li segna |
| Tre sessioni da un minuto | 1 credito: i resti si sommano ancora |
| Nuova città | mondo, crediti e statistiche azzerati, volume no |
| I nove suoni | sintetizzati, picco a 0,9, silenzio in testa e in coda |
| Alzare la sponda di un ponte già posato | rifiutato, e lo dice |
| Abbassarla | rifiutato |
| Alzare una cella lontana dal ponte | permesso |
| Alzare la cella a cui sale una rampa | rifiutato, e lo dice |
| Rampa al piede di un gradino, quattro rotazioni | ne vale una sola |
| All'avvio | menu aperto, città ferma dietro |
| Esc | apre il menu, e da aperto lo richiude |
| Esc con le statistiche davanti | lo prendono loro, il menu non si muove |

Guardati anche i frame veri, ed è lì che sono usciti i tre bug che compilavano
benissimo: il pannello statistiche era trasparente e il countdown si leggeva
attraverso le cifre, le colonne dei giorni vuoti sembravano giornate grigie
invece che giornate assenti, e la riga di stato della città finiva sotto il
negozio.

## Distribuzione

Le cinque fasi facevano un progetto; questo lo rende un'app che si può dare a
qualcuno.

- **Un file solo.** `binary_format/embed_pck` mette i dati dentro
  l'eseguibile: si scarica `FOCUS.exe` e basta, niente cartella da tenere
  insieme e niente installer da far girare.
- **`export_presets.cfg` è versionato**, contro l'abitudine del `.gitignore` che
  Godot suggerisce. Quel consiglio serve a non pubblicare credenziali di firma:
  qui non ce ne sono, e il preset documenta come si costruisce la build. La
  cartella `build/` invece resta fuori.
- **L'icona nasce dallo stesso script del `.svg`.**
  `tools/icon/genera_icona.py` scrive tutti e due i file dalle stesse misure:
  Godot vuole l'SVG per il progetto, Windows vuole un `.ico` con sei
  risoluzioni dentro. Due formati, una geometria sola — cambiare un colore in
  uno e scordarselo nell'altro non è possibile. Da Godot 4.7 non serve più
  `rcedit`: icona e informazioni di versione le scrive l'esportatore.
- **La LICENSE viaggia dentro il pacchetto** (`include_filter`). La GPL chiede
  che il testo accompagni il binario, e un eseguibile unico non può avere un
  file di licenza accanto per caso.
- **Il salvataggio sta in `%APPDATA%`, non accanto all'eseguibile.** Era già
  così dalla Fase 1 (`user://`), e adesso ha una conseguenza visibile: si può
  sostituire il `.exe` con una versione nuova senza perdere la città.
- **Non c'è firma digitale.** Un certificato costa qualche centinaio di euro
  l'anno e non ha senso per un progetto libero, quindi Windows mostrerà
  SmartScreen al primo avvio. Il README lo dice prima che succeda, e ricorda che
  chi non si fida può compilarselo da sé in due comandi: è la risposta onesta,
  ed è anche il motivo per cui il codice è aperto.

## Ripensamento su ponti e rampe

Le regole di piazzamento di ponti e rampe erano scritte per proteggere una
composizione: campata sull'acqua agganciata a una riva, rampa col piede in
piano e un gradino esatto da salire, terreno sotto ponti e rampe congelato
perché nessuno dei due si muove più dopo la posa. Alla prova dei fatti quella
composizione non si difendeva da sola: chi prendeva una rampa in salita e la
puntava verso l'alto se la vedeva rifiutare, e per farla accettare doveva
girarla al contrario. Il verso giusto è quello che si vede — il fronte dei
modelli guarda -Y in Blender, che l'export glTF porta a +Z in Godot, mentre la
tabella dei lati traduceva "north" in -Z: il controllo cercava il gradino
dalla parte sbagliata.

Si poteva raddrizzare la tabella. Si è invece tolta la regola:

- **Ponti e rampe si posano su qualunque cella libera**, asciutta o bagnata.
  L'unico rifiuto che resta è quello che vale per tutti: qui c'è già qualcosa.
  Nessun verso è vietato, quindi `R` decide come si vede il pezzo e basta.
- **La quota non si chiede più al giocatore, si deduce.** La campata eredita
  l'impalcato vicino, o sta un gradino sopra la sponda, e comunque mai sotto il
  pelo dell'acqua né dentro la collina che scavalca. La rampa prende il livello
  del terreno che ha sotto; dove terreno asciutto non ce n'è, va un gradino
  sotto l'impalcato accanto, che è il punto a cui deve arrivare.
- **Il terreno accanto a ponti e rampe torna modellabile.** Il divieto serviva a
  non rompere un aggancio obbligatorio: senza più l'obbligo, era solo un no in
  più. La cella *sotto* una costruzione resta intoccabile come prima.

Con la regola è uscito il codice che la serviva: la tabella dei lati, il lato
alto delle rampe, la quota calpestabile oltre il bordo e il vincolo del terreno
vicino. Le rampe restano di un gradino, ma è un dato del modello, non un
divieto.

Tolti i rifiuti restava però un vincolo silenzioso: la quota. Dedurla è comodo
finché indovina, e quando non indovina non c'è modo di dirglielo — una rampa
resta incollata al terreno anche quando la si vuole in aria, a metà di un
raccordo che il gioco non ha previsto. Quindi **`PagSu` e `PagGiù` spostano di
un gradino la quota del pezzo che si ha in mano**, e la deduzione diventa il
punto di partenza invece che l'unica risposta. Vale solo per ponti e rampe:
chi spiana il lotto ha la sua quota nel lotto stesso, e alzarlo lo farebbe
levitare. Lo scostamento si azzera quando si cambia oggetto, si tiene fra una
posa e l'altra — una fila di campate alla stessa quota si fa così — e resta
dentro i limiti del mondo.

E la vista si sposta anche **con WASD o con le frecce**, `Shift` per correre.
Il trascinamento col tasto destro c'era già, ma vuole una mano sul mouse che
nel frattempo serve per puntare dove si costruisce. La velocità sta sullo zoom
e non sui metri — una schermata al secondo, due e mezza correndo — così da
vicino si va piano e da lontano in fretta, e la profondità porta la stessa
correzione del trascinamento: la camera guarda il piano di sbieco, e senza
dividere per il seno dell'inclinazione avanti e indietro andrebbero più piano
che destra e sinistra. Non serve spegnerlo quando il menu sta davanti: la
città ha già il `process_mode` disabilitato, e con lei la camera.

| Prova | Esito |
|---|---|
| Rampa sull'asciutto, quattro rotazioni | valgono tutte, piede al livello del terreno |
| Ponte sull'asciutto, quattro rotazioni | valgono tutte, impalcato un gradino sopra |
| Rampa e ponte sull'acqua | posati; l'impalcato sta sopra il pelo dell'acqua |
| Ponte accanto a una sponda | un gradino sopra la riva, come prima |
| Rampa sull'acqua accanto a un impalcato | piede un gradino sotto l'impalcato |
| Rampa su una cella occupata | rifiutata, e lo dice |
| Alzare la cella accanto a un ponte | permesso |
| Dieci modelli di rampa, tutta la mappa, quattro rotazioni | 40.960 posti provati, rifiutati solo quelli occupati o fuori mappa |
| Rampa alzata a mano da -3 a +3 gradini | ci va, e ci resta anche dopo la posa |
| Alzata oltre il tetto del mondo, o sotto zero | si ferma al limite |
| Alzata su una casa | ignorata: chi spiana il lotto non si alza |
| W, A, S, D e le frecce | opposti a due a due, perpendicolari fra loro |
| W | va verso il fondo dello schermo, non di traverso |
| Shift, e lo zoom da vicino | cambiano il passo, non la direzione |

Guardati anche i frame veri: le rampe salgono dalla parte in cui le si gira, e
il cavalcavia posato sull'asciutto si salda alle due rampe che gli arrivano
sotto senza scalini.

## Il negozio diventa una fascia

Il negozio era una colonna alta quanto lo schermo, appoggiata a destra: si
mangiava un quarto della città sempre, anche quando non si stava costruendo, e
in cambio mostrava venti voci per volta dentro un `ItemList`. Adesso è un
pulsante e una fascia.

- **Il pulsante col martello e la chiave inglese**, in alto a sinistra, apre e
  chiude. L'icona è un SVG di quattro tratti (`assets/ui/costruzioni.svg`):
  disegnata a trentacinque pixel di lato, dove qualsiasi dettaglio in più
  sarebbe fango. Ci arriva anche il tasto `B`, e l'Esc la richiude — ma solo a
  mani vuote, perché in cantiere l'Esc lascia prima l'attrezzo.
- **La fascia sta in cima e tiene tutto il catalogo di fila**, ottantasette
  schede e i quattro attrezzi in coda, divise negli scaffali di sempre col nome
  sopra ciascun gruppo. Il nome scorre insieme alle sue schede, così si sa
  sempre dentro cosa si sta guardando: non sono schede di categorie che si
  escludono, è un catalogo unico che si attraversa.
- **Si scorre trascinandola col mouse.** Tredicimila pixel di fila sono tanti da
  trascinare, però, quindi la rotella li scorre a scatti — sopra la fascia
  smette di zoomare la città, che tanto sta dietro — e in testa ci sono i nomi
  degli scaffali, che saltano al loro pezzo con un clic.
- **Ogni scheda porta il ritratto del suo modello.** Un nome non basta a
  distinguere «Ufficio» da «Ufficio a gradoni», e comprare alla cieca vuol dire
  posare, guardare e demolire.
- **La città si riprende lo schermo.** Chiusa la fascia non resta niente davanti
  al mondo, e le due righe di stato in basso, che stavano strette per non
  finire sotto il pannello, tornano larghe quanto la finestra.

I ritratti sono scattati dal gioco, non da Blender. Una cartella di novanta PNG
sarebbe una seconda copia della libreria da tenere allineata a mano, e si
scorderebbe di aggiornarsi alla prima rigenerazione: è lo stesso motivo per cui
il terreno si salva col seme e non con le quote. Lo studio è un `SubViewport`
solo, grande una scheda, con un mondo tutto suo perché la città non ci entri
dentro; i modelli ci passano uno per frame, si fanno inquadrare dal loro
ingombro e lasciano una `ImageTexture` ferma. Novanta viewport vivi costerebbero
come un secondo mondo 3D; uno riusato novanta volte costa due secondi e mezzo
all'avvio, spesi mentre si guarda il menu — e il ciclo non aspetta il processo
ma il disegno (`RenderingServer.frame_post_draw`), quindi va avanti anche con la
città ferma dietro al menu, che è esattamente com'è fatto l'avvio. La telecamera
dello studio ha l'inclinazione e l'imbardata di quella di gioco: nella fascia un
modello ha già la faccia che avrà una volta posato.

Il punto delicato è stato il trascinamento. Sotto il dito ci sono le schede, e
sono loro a prendersi il clic: il gesto va quindi intercettato in `_input`, che
arriva prima della GUI, lasciandolo scendere finché è un clic e trattenendolo
appena diventa un trascinamento. Trattenere il rilascio però non basta, e il
primo tentativo comprava una casa a ogni scorrimento: un pulsante decide di
essere stato premuto guardando se il mouse era dentro quando è stato premuto,
non dove arriva il rilascio. Quello che serve è fargli uscire il mouse dai bordi
prima — la stessa strada di un dito che scivola via — e da lì in poi il
rilascio non lo riguarda più. È uscito dai controlli automatici, non
dall'occhio: trascinare sembrava funzionare benissimo.

| Prova | Esito |
|---|---|
| All'avvio | fascia chiusa, e il pulsante la apre |
| Gli scaffali | cinque più gli strumenti, in fila e in testa |
| Le schede | ottantasette, una per ogni voce in vendita |
| Senza crediti | restano a schermo, spente; coi crediti si riaccendono |
| Clic su una scheda | la sceglie, e il dettaglio la descrive |
| Trascinamento di 140 px | la fila scorre di 140 px |
| Lo stesso trascinamento | non compra niente, e non lascia schede accese |
| Rotella sopra la fascia | scorre lo scaffale invece di zoomare |
| Nome di uno scaffale | salta al suo pezzo di fila |
| Mouse sopra la fascia | CityView non punta la cella che ci sta sotto |
| I ritratti | 87 su 87, 96x96 px, e dentro c'è davvero un modello |
| Con la città ferma dietro al menu | si scattano lo stesso, tutti |
| Lo studio dopo l'ultimo scatto | sgombro: nessun modello resta dentro |
| Il contenuto di una scheda | non ruba il mouse al pulsante che lo contiene |
| Scheda troppo cara | si sbiadisce col suo ritratto dentro |

Guardati anche i frame veri: il pulsante, la fascia e la barra delle modalità
stanno insieme senza pestarsi, i ritratti si riconoscono uno per uno lungo tutti
gli scaffali, e i nomi lunghi («Strada sterrata in curva») ci stanno dentro —
alla prima misura delle schede no, e si leggeva «Strada sterrata i».

## Corrente e acqua

La città non chiedeva niente: si posava, si pagava, finiva lì. Adesso ogni
edificio vuole corrente e acqua, e qualcuno gliele deve dare.

- **Si paga a cella occupata, non a modello.** Il tipo dice quanto pesa un metro
  quadro, l'ingombro dice quanti: una torre 4x4 chiede sedici volte una casetta
  1x1 senza che nessuno debba scrivere novantuno numeri, ed è la stessa ragione
  per cui i prezzi stanno sul tipo. «Gli edifici più grandi chiedono di più»
  esce da sé dalla forma dei dati, invece di essere una regola in più.
- **Gli impianti danno un numero fisso, ciascuno il suo.** Una pala eolica è una
  pala eolica, che stia stretta o larga: 90 di corrente, come l'impianto solare;
  il serbatoio idrico 90 di acqua. Solare ed eolico danno lo stesso perché
  costano lo stesso — un impianto peggiore allo stesso prezzo sarebbe una
  trappola, non una scelta, e a distinguerli basta che uno occupi 3x2 e l'altro
  2x2.
- **Strade, ponti, rampe, alberi e parchi non si allacciano a niente.** La regola
  così si dice in una riga: gli edifici consumano, le infrastrutture e il verde
  no.
- **Senza impianti non è servito niente.** La città non parte con la corrente
  addosso: zero e zero. C'era un allacciamento di partenza, 20 e 20, messo lì
  perché la prima casa non costasse anche una centrale — ma faceva risultare
  servita mezza città senza che ci fosse una sola pala eolica, ed è un conto
  che mente. Il numero è rimasto in `economy.json`, a zero: chi vuole regalarsi
  un allacciamento lo alza e basta.
- **Senza corrente si costruisce lo stesso, ma resta al buio.** È l'altra metà
  della decisione di sopra, e senza di lei la prima sarebbe stata un muro:
  a bilancio zero non si sarebbe potuta posare nemmeno la prima casa. Bilanciare
  diventa la cosa da inseguire invece del divieto che ti ferma la mano — lo
  stesso criterio scritto nel piano per i cinque presidi civici, applicato anche
  qui per non avere due regole diverse per la stessa idea.
- **Quello che resta scoperto si vede.** Un velo scuro addosso alla costruzione
  e un punto esclamativo rosso che le galleggia sopra, e toccandolo si aprono i
  conti. Un divieto si spiega da solo perché ti ferma; un problema che ti lascia
  costruire va detto, o non lo scopre nessuno.
- **Demolire un impianto è permesso anche se lascia la città in rosso.** Le
  costruzioni che reggeva si spengono e lo dicono. Vietarlo avrebbe reso
  impossibile spostare una pala.
- **Una costruzione col punto esclamativo non entra in funzione.** Un impianto
  senza strada non produce un ampere: sta lì, l'hai pagato, ma non conta. È la
  stessa cosa che il suo punto esclamativo dice già a chi guarda, detta al
  bilancio. Per questo la corrente disponibile non è un totale tenuto a mano ma
  una somma che si rifà quando serve: basta demolire una strada tre celle più in
  là per cambiarla, e un numero aggiornato a mano si sarebbe scollato dal mondo
  alla prima distrazione.
- **Quello che si spegne è quello che dà, non quello che chiede.** Una casa al
  buio la corrente la vuole lo stesso, ed è proprio quello che la tiene al buio.
  Toglierle anche il consumo libererebbe la corrente che la riaccenderebbe, che
  la farebbe consumare di nuovo, che la rispegnerebbe: una domanda senza
  risposta stabile.
- **Del bilancio non si salva niente.** È la somma di quello che c'è in città e
  si rifà da sola al caricamento — stesso principio del terreno, che si salva
  col seme e non con le quote. Una città salvata prima di questa modifica si
  riapre intera e va semplicemente in rosso: non si demolisce niente per
  punizione, solo non si cresce finché non arriva un impianto.

I numeri stanno in `data/economy.json` come tutti gli altri, e `python
tools/balance/simula_economia.py` adesso li fa vedere insieme ai prezzi: quanto
chiede il quartiere di riferimento, quanti impianti servono e quanto pesano in
percentuale. Sul quartiere di riferimento (37 pezzi, 310 crediti) sono 41 e 41,
cioè un impianto per servizio: 108 crediti, il 35% in più. È il gradino più alto
della curva e si sale una volta sola — quei due impianti ne reggono 110, e i due
quartieri successivi non costano un credito di infrastruttura.

| Prova | Esito |
|---|---|
| Casa 1x1, casa 1x2, torre 4x4 | 1+1, 2+2, 32+32: l'ingombro fa il conto |
| Pala eolica, serbatoio idrico | danno 90 dell'uno e niente dell'altro |
| Strade, rampe, ponti, alberi, parchi | non chiedono niente |
| Posare una casa | il bilancio scende di uno e uno |
| Città senza impianti | si costruisce, e resta tutto scoperto |
| Una costruzione scoperta | velo scuro addosso e punto esclamativo sopra |
| Toccare il punto esclamativo | si aprono i conti della città |
| Posare pala e torre | velo e punto esclamativo spariscono |
| Posare una pala | il tetto della corrente sale di 90 |
| Togliere la strada da sotto una pala | smette di produrre, e chi alimentava si spegne |
| La casa che si spegne | continua a chiedere la sua corrente, e il conto non oscilla |
| Rimettere quella strada | la pala riprende e la casa si riaccende |
| La fascia | scrive «Corrente 78/110», e cambia colore vicino al limite |

## La strada, e i conti della città

Due cose che vengono dalla stessa domanda: come fa il giocatore a sapere che
cosa non va nella sua città.

- **Chi ha a che fare coi servizi vuole una strada accanto**, che li prenda o
  che li dia. La lista non è un elenco a parte: è quella di corrente e acqua,
  letta dallo stesso posto, e una lista sola non può contraddirne un'altra. Ci
  stanno dentro anche gli impianti, che non consumano niente ma a cui qualcuno
  deve pur arrivare per tirarli su e per ripararli: una centrale in mezzo ai
  campi senza uno straccio di strada è la stessa cosa assurda di una casa.
  Restano liberi solo quelli che con i servizi non c'entrano — strade, ponti,
  rampe, alberi, parchi.
- **Adiacenza, non raggiungibilità.** Confinare con una strada è un controllo
  locale che costa nulla; pretendere che quella strada sia collegata a tutto il
  resto vorrebbe dire visitare il grafo stradale a ogni movimento del mouse, e
  soprattutto che tagliarne una in mezzo scollegherebbe mezza città in un colpo.
  Confinare basta a impedire la casa in mezzo al niente, che è la cosa che si
  voleva impedire. La rete resta una raffinatura possibile, non il primo passo.
- **I conti della città** sono un pannello a parte, col suo pulsante: per ogni
  servizio, quante costruzioni lo chiedono e quante ne restano scoperte. Non è
  il pannello delle statistiche di focus — quello racconta le giornate di
  concentrazione, questo racconta la città, e si guardano in momenti diversi.
- **Cliccando un servizio si accende sul mondo** chi ne resta scoperto, e solo
  chi ne resta scoperto. Un numero dice quante sono, non dove sono, e per
  rimediare bisogna sapere dove; colorare di verde anche quelle a posto — che
  sono la maggioranza — vorrebbe dire nascondere le tre che contano dentro una
  città intera dipinta. Un servizio per volta.
- **Quando un servizio non basta per tutti, la rete serve prima quello che
  c'era già.** Si scorrono le costruzioni nell'ordine in cui sono state posate e
  si stacca da dove il conto sfonda. È una regola arbitraria come ogni altra, ma
  è stabile — riaprendo la partita restano al buio le stesse case — ed è quella
  che ci si aspetta, perché è l'ultima cosa costruita ad aver fatto saltare il
  conto.
- **L'elenco dei servizi è una costante sola** in `CityView`. I cinque presidi
  civici non ci sono perché non hanno ancora un'area di azione: quando ce
  l'avranno entrano lì, e il pannello, l'evidenza e i conti funzionano già.

Le città salvate prima di questa modifica si riaprono intere, e le loro case
senza strada compaiono nel pannello come scoperte: è esattamente il posto dove
si voleva che comparissero.

| Prova | Esito |
|---|---|
| Casa in mezzo al niente | rifiutata, e dice che ci vuole una strada |
| Albero e prima strada in mezzo al niente | si posano: non chiedono strada |
| Casa attaccata alla strada, e casa a quattro celle | la prima sì, la seconda no |
| Rampe e impalcati | valgono come strada quanto l'asfalto |
| Corrente ridotta sotto il fabbisogno | qualcuno resta al buio, ma non tutti |
| Due letture di seguito | stessi scoperti: il conto è stabile |
| Chi resta al buio | l'ultimo arrivato, non il primo |
| Corrente in abbondanza | nessuno scoperto |
| Clic su un servizio | sul mondo si accendono solo le scoperte |
| Richiudere il pannello | si spegne anche il colore sul mondo |

## Spostare quello che c'è già

Demolire e ricostruire costava metà prezzo e faceva perdere il posto; per
girare una casa di novanta gradi era un prezzo assurdo. Lo strumento *Sposta*
prende in mano una costruzione e la riposa dove si vuole.

- **Non si ripaga.** L'edificio è già stato comprato una volta, e far pagare il
  ripensamento vuol dire che nessuno cambia mai idea — cioè che la città resta
  com'è venuta la prima volta.
- **Valgono tutte le regole di un piazzamento nuovo**, perché è un piazzamento
  nuovo: strada accanto, celle libere, terreno asciutto, quota. Il codice è
  letteralmente lo stesso `_valuta`, e non una seconda copia delle regole
  destinata a divergere al primo ritocco.
- **In mano non c'è.** Presa su, sparisce dalla griglia e dal bilancio dei
  servizi: il posto che occupava è libero, il che è quello che serve per poterla
  rimettere dov'era spostata di una cella sola.
- **Dal salvataggio invece esce solo quando si è posata.** È venuto fuori da un
  frame vero, non dai controlli: prendere in mano una costruzione e chiudere
  l'app la faceva sparire per sempre. Adesso finché sta in mano il salvataggio
  la tiene dov'era, e chiudere l'app la lascia lì.
- **Esc è un passo indietro per volta**: il primo rimette a posto quello che si
  ha in mano e lascia lo strumento in mano, il secondo esce. Anche cambiare
  strumento, scegliere un altro oggetto o uscire dalla città la rimettono a
  posto: una costruzione non può sparire perché si è cliccato altrove.

| Prova | Esito |
|---|---|
| Clic su una costruzione | presa in mano, e la sua cella è libera |
| Mentre è in mano | fuori dalla griglia e dal bilancio, dentro il salvataggio |
| Riposarla altrove | griglia, bilancio e salvataggio tornano a tornare |
| Spostare | non costa e non rimborsa un credito |
| Esc con qualcosa in mano | torna dov'era, con la rotazione che aveva |
| Cambiare strumento o uscire | la rimette a posto invece di perderla |
| Il salvataggio dopo un ripensamento | una riga sola, dove era |
| Riposarla lontano da una strada | rifiutata come un piazzamento qualsiasi |

## Gli abitanti, e il pannello di stato

Il primo dei tre attributi che rendono una città una città invece di un
plastico. Ogni edificio residenziale porta con sé un numero di abitanti, e in
un angolo dello schermo ci sono i tre numeri che dicono come sta la città.

- **La densità sta sul tipo, l'ingombro fa il resto**, come per corrente e
  acqua e per la stessa ragione: una casetta 1x1 fa 3 abitanti, una casa 1x2 ne
  fa 6, una villa 2x2 ne fa 8, una palazzina 24, una stecca 40, una torre 4x4
  ne fa 224. La scala è quella delle tipologie, non dei metri quadri — le celle
  sono 2x2 m e nessun conto realistico ci starebbe dentro, mentre il rapporto
  fra una villa e una torre è quello che si legge guardando.
- **La densità conviene**, che è come dev'essere: coi prezzi di adesso un
  abitante costa 3,3 crediti in una casa, 1,2 in una palazzina e 0,95 in una
  torre. La villa costa più di quello che ospita ed è voluto — è un lusso, non
  un affare. La stecca resta il pezzo peggio prezzato del listino, ma il
  problema è il suo prezzo (96 crediti) e non il suo numero di abitanti.
- **Un edificio col punto esclamativo non ospita nessuno.** È la regola già
  scritta per gli impianti, applicata al primo attributo che le tocca: se è
  grigio non entra in funzione, e un palazzo senz'acqua è un palazzo vuoto.
  Continua però a chiedere l'acqua di un palazzo pieno — quello che si spegne è
  quello che l'edificio dà, mai quello che chiede.
- **Il pannello di stato non ha un pulsante e non si chiude**, perché non è una
  cosa da andare a cercare: sono i tre numeri che dicono se quello che si sta per
  costruire ci sta. Abitanti, corrente e acqua, ognuna con la sua barra piena in
  proporzione e la percentuale usata; azzurra quando c'è margine, ambra sopra
  l'85%, rossa quando è finita. I conti della città restano dietro al loro
  pulsante: quelli rispondono a «che cosa non va», che è una domanda che ci si fa
  ogni tanto, non a ogni clic.
- **Senza impianti la percentuale non esiste.** Non è lo zero per cento, è una
  divisione che non si può fare: la barra si riempie tutta di rosso e il testo
  dice «8 / 0», che è la lettura giusta — tutto quello che c'è resta scoperto.

| Prova | Esito |
|---|---|
| Casa 1x1, casa 1x2, torre 4x4 | 3, 6, 224: l'ingombro fa il conto |
| Casa, villa, palazzina, torre | in quest'ordine, sempre più densi |
| Strade, alberi, parchi, negozi, uffici, scuole, impianti | non ci abita nessuno |
| Posare una casetta servita | la popolazione sale di 3 |
| Toglierle la strada | non ospita più nessuno, ma l'acqua la chiede lo stesso |
| Rimetterla | si ripopola |
| Le barre | piene quanto l'usato sul disponibile, con la percentuale |
| Mille e duecento | si legge «1.200» |

## Il lavoro

Il secondo attributo. Ogni edificio commerciale, di lavoro o di servizio offre
un certo numero di posti, e gli abitanti li vogliono tutti.

- **La densità sta sul tipo, l'ingombro fa il resto**, come per abitanti e
  servizi: negozio 4 posti a cella, ufficio 8, fabbrica 6, azienda agricola e
  presidio 3, scuola 2, campo sportivo 1. Un negozio 1x1 fa 4 posti, un ufficio
  2x2 ne fa 32, una fabbrica 3x3 ne fa 54.
- **In superficie il rapporto è circa uno a uno**: un ufficio 2x2 (32 posti)
  regge una palazzina 2x2 (24 abitanti) e avanza. La lettura è «un isolato di
  uffici per un isolato di case», che è la proporzione che si vuole poter vedere
  a occhio guardando la città. Una torre 4x4 (224 abitanti) vuole tre uffici
  3x3: è la ragione per cui una torre non si posa da sola.
- **Il lavoro è il quarto servizio dell'elenco**, accanto a strada, corrente e
  acqua. Non ha avuto bisogno di niente di nuovo: pannello dei conti, evidenza
  sul mondo, velo scuro e punto esclamativo funzionano già per chiunque entri in
  quell'elenco, ed è esattamente il motivo per cui quell'elenco è una costante
  sola.
- **Chi resta senza lavoro si spopola**, come chi resta senz'acqua. La fila
  segue l'ordine di posa: senza posto resta l'ultimo arrivato, che è anche
  quello che ha fatto saltare il conto.
- **La domanda è quella nominale, non quella viva.** Un palazzo rimasto senza
  lavoro ospita zero abitanti, ma continua a chiedere i posti dei suoi abitanti
  nominali. Se smettesse anche di chiederli, i posti tornerebbero a bastare, il
  palazzo si ripopolerebbe, i posti tornerebbero a mancare, e via all'infinito:
  una domanda senza risposta stabile. È la stessa regola della corrente, e vale
  la pena scriverla una volta per tutte — **quello che si spegne di una
  costruzione in difetto è quello che dà, mai quello che chiede.**
- **Un ufficio senz'acqua è un ufficio chiuso**, e non offre un posto. Per
  contare i posti bisogna quindi sapere prima quali edifici funzionano, e per
  questo il lavoro si conta dopo gli altri tre: `SERVIZI_ALLACCIAMENTO` esiste
  per dire quali sono «gli altri tre» in un posto solo. Un ufficio non ha
  bisogno di un impiego per darne, quindi il giro si chiude.
- **Il pannello di stato ha la sua riga**, con quanti posti si chiedono su
  quanti ce ne sono. Sopra la capienza la percentuale smette di servire —
  «2392%» non si legge — e al suo posto va quanto ne manca, che è il numero con
  cui si decide cosa costruire.

| Prova | Esito |
|---|---|
| Negozio 1x1, ufficio 2x2 | 4 e 32 posti |
| Case, ville, torri, strade, alberi, parchi | non danno lavoro a nessuno |
| Posare un negozio | quattro posti in più |
| Posare una casa | tre posti chiesti in più |
| Posare una torre da 224 abitanti | i posti non bastano più |
| Chi resta senza | la torre, l'ultima arrivata: `!` e zero abitanti |
| Rileggere il conto due volte | stesso risultato: niente altalena |
| Togliere la strada a un negozio | smette di dare lavoro |
| Il pannello | «287 / 12 · ne mancano 275» |

## La felicità, e gli edifici che si abbandonano

Il terzo attributo, e il primo che non è un sì o un no. Cinque servizi di zona —
**polizia, pompieri, ospedale, verde e sport** — ognuno con un'area di azione
attorno a sé; un'abitazione dentro l'area riceve quel servizio, e la sua
felicità è la frazione dei cinque che le arrivano. **Sotto il 50% l'abitazione
viene abbandonata**: la gente se ne va, il velo scuro e il punto esclamativo
compaiono come per chi resta senz'acqua.

- **Due famiglie di bisogni, e vanno tenute distinte** perché è quello che rende
  il gioco leggibile. **Strada, corrente, acqua e lavoro sono allacciamenti**: o
  ci sono o non ci sono, e senza si spegne subito. **I cinque presidi sono
  felicità**: si contano a frazione, nessuno da solo spegne niente, e si cede
  sotto metà. In `CityView` sono due costanti — `SERVIZI_VITALI` e
  `SERVIZI_ZONA` — e la differenza sta scritta lì, non sparsa fra i controlli.
- **Il raggio cresce con l'edificio.** Un numero base per servizio in
  `economy.json` (9 celle per i tre presidi civici, 8 per lo sport, 6 per il
  verde) più il lato più lungo dell'edificio meno uno: un ospedale 3x3 arriva a
  11 celle, una clinica 2x2 a 10, un parco tascabile 1x1 a 6. Un numero per
  modello non serve — l'ingombro lo dice già.
- **Cerchi, non rombi.** Il raggio è in linea d'aria: le aree tonde sono quello
  che ci si aspetta guardando, e la distanza di Manhattan avrebbe fatto rombi
  che nessuno associa a «quanto lontano arriva un'ambulanza».
- **La soglia a metà è generosa di proposito.** Tre servizi su cinque tengono in
  piedi un quartiere: si può crescere prima e rifinire dopo, invece di dover
  avere tutto subito. È un numero in `economy.json`, `abandon_below`.
- **La felicità è delle abitazioni, non di tutti.** Chiedere a una pala eolica
  se ha il parco sotto casa non vuol dire niente. Ma soprattutto: se anche i
  presidi potessero essere abbandonati per infelicità, l'infelicità di ciascuno
  dipenderebbe dai vicini e quella dei vicini da lui, e alla domanda non ci
  sarebbe una risposta sola. Un quartiere si spegnerebbe a catena senza che
  nessuno possa dire da dove è cominciato.
- **Un presidio allacciato serve la zona, contento o no.** È l'altra metà della
  stessa precauzione: la copertura dipende dagli allacciamenti, mai dalla
  felicità. Un presidio senza strada o senz'acqua invece è chiuso, e la sua area
  sparisce insieme a lui.
- **La felicità della città è la media pesata sugli abitanti**, non sugli
  edifici: una torre scontenta pesa duecento volte una casetta scontenta, perché
  è duecento volte più gente. Sta nel pannello di stato con la sua barra, e il
  colore va al contrario delle altre — qui il pieno è la cosa buona, e il rosso
  comincia alla soglia dell'abbandono.
- **I conti della città hanno nove righe**, una per servizio, e le cinque di
  zona dicono quante abitazioni restano fuori. Cliccandone una si accende sul
  mondo chi ne è scoperto: è così che si decide dove mettere il prossimo
  presidio. In fondo, quante costruzioni sono abbandonate — è la riga che spiega
  un «Abitanti 0» senza far aprire nient'altro.

Le scuole sono entrate subito dopo: i servizi di zona sono diventati sette, e
per arrivare al cento per cento servono sia l'elementare sia la superiore. La
sezione qui sotto racconta com'è andata.

| Prova | Esito |
|---|---|
| Chi porta cosa | polizia, pompieri, ospedale dai presidi; verde dai parchi; sport dai campi |
| Case e scuole | non portano nessun servizio di zona |
| Abitazione senza presidi | felicità 0%, abbandonata, col punto esclamativo |
| Un presidio per volta | 20%, 40%, 60%: un quinto ciascuno |
| A tre su cinque | sopra la soglia: la casa si ripopola e il `!` sparisce |
| Demolire un presidio | si torna al 40% e la casa viene riabbandonata |
| Togliere la strada a un presidio | la sua area sparisce del tutto |
| Il pannello | felicità in percentuale, e le nove righe dei servizi |

## Le aree, e come si vedono

I sette servizi di zona — **polizia, pompieri, ospedale, verde, sport, scuola
elementare e scuola superiore** — hanno un'area di azione attorno a sé, e adesso
quell'area si vede.

- **Come si calcola.** Un cerchio attorno al centro del presidio, di raggio
  letto da `economy.json` più il lato più lungo dell'edificio meno uno: un
  ospedale 3x3 arriva a 11 celle, una clinica 2x2 a 10, un parco tascabile 1x1 a
  6. Un'abitazione è coperta se **almeno una delle sue celle** cade dentro il
  cerchio di **almeno un** presidio di quel tipo. In linea d'aria e non a
  scacchiera: le aree tonde sono quello che ci si aspetta guardando, e la
  distanza di Manhattan avrebbe fatto rombi che nessuno associa a «quanto
  lontano arriva un'ambulanza».
- **Le due scuole contano separate.** Servono bacini diversi — 7 celle base
  l'elementare, 10 la superiore — e averne una sola non è come averle tutte e
  due: per arrivare al cento per cento servono entrambe.
- **Un settimo ciascuno.** Con sette servizi la soglia di abbandono a metà vuol
  dire che ne bastano quattro: si può crescere prima e rifinire dopo.
- **Cliccando un servizio nei conti** si accendono due strati sul mondo: in
  verde tenue il **territorio** che quel servizio raggiunge, in rosso le
  **abitazioni** che restano fuori. Sono due domande diverse e servono
  entrambe — il rosso dice che c'è un problema, il verde dice dove mettere il
  prossimo presidio. Gli allacciamenti (strada, corrente, acqua, lavoro) un
  territorio non ce l'hanno, e per loro resta solo il rosso.
- **Mentre si posiziona un presidio si vede la sua area**, disegnata sul terreno
  attorno all'anteprima e aggiornata a ogni cella. È la stessa area che varrà
  dopo averlo posato, calcolata dalla stessa funzione: un'anteprima che promette
  un cerchio diverso da quello vero sarebbe peggio di nessuna anteprima.
- **Uno strato solo, e una regola su chi lo occupa.** L'area in mano e il
  servizio acceso nei conti si contenderebbero lo stesso velo: vince quello che
  si ha in mano, perché è la domanda del momento — «se lo metto qui, dove
  arriva?» — e appena lo si posa ricompare l'altro. La decisione sta in una
  funzione sola, `_ridipingi_evidenza`, invece che sparsa fra i posti che
  ridisegnano.
- **L'elenco dei servizi scorre.** Da tre che erano sono diventati undici: le
  righe dei conti stanno dentro un contenitore che scorre, così il pannello ha
  un'altezza fissa qualunque cosa succeda all'elenco.

| Prova | Esito |
|---|---|
| I servizi di zona | sette, con le due scuole separate |
| Una scuola | continua a dare lavoro e non abitanti |
| Il bacino della superiore | più largo di quello dell'elementare |
| Posare un'elementare | la felicità di una casa vicina sale di un settimo |
| L'area di una scuola | 154 celle; la casa dentro, una a venti celle fuori |
| Accendere un servizio di zona | due strati: territorio coperto e case scoperte |
| Accendere un allacciamento | un solo strato: non ha territorio |
| Un presidio in mano | si vede la sua area, identica a quella che avrà |
| Una casa in mano | nessuna area, perché non è un presidio |
| Uscire dal cantiere | l'area sparisce con lui |

## Un mondo più credibile, e più grande di quello che si vede

L'ultima voce del piano, ed erano due lavori: come è fatto il mondo, e quanto
ne è tuo.

### Il paesaggio

Il rilievo nasce da **tre rumori che fanno tre mestieri diversi**, invece che da
uno solo smorzato verso il centro.

- **La forma del continente** è rumore a bassa frequenza. Prima era una distanza
  dal centro — un cerchio — e si vedeva: la costa era una curva di livello.
  Adesso la discesa verso i bordi serve solo a garantire che il mare chiuda la
  mappa, e dentro quel vincolo la costa fa promontori e insenature per conto
  suo.
- **Le colline** sono rumore frattale normale, che riempie l'entroterra di alti
  e bassi morbidi.
- **Le creste** sono rumore *ridged*, che invece di dossi tondi produce dorsali
  che si diramano. Pesano come il quadrato della terra emersa: sulla costa non
  se ne accorge nessuno, in cima cambiano tutto. È quello che distingue un
  paesaggio da un mucchio di collinette.

Poi passa **l'erosione termica**: dove il salto verso il vicino più basso supera
il talus, la parete frana e il materiale si sposta di sotto. Non si lima, si
sposta — che è la differenza fra erodere e smussare, e si vede: le valli si
allargano verso il basso invece di restare incisioni a picco. Tre passate, su
una copia che si applica alla fine di ciascuna, altrimenti l'ordine di scansione
conterebbe e il versante a est verrebbe diverso da quello a ovest.

E infine **piove**: un rumore suo, più largo di quello delle colline perché il
clima cambia più lentamente del terreno, corretto dalla quota. L'umidità decide
il bioma **prima** della quota, non dopo: se contasse solo sotto una certa
altezza il mondo tornerebbe a essere colorato a fasce, che è esattamente quello
che si voleva togliere. Un versante al riparo è secco che stia a cinque metri o
a quaranta, e diventa **prateria** invece che prato.

I numeri non sono stati scelti a occhio: una scena usa e getta stampa, per sei
semi, quanta terra emerge, come si distribuiscono le quote e quanti biomi di
ciascun tipo escono. La prima stesura faceva mondi al 27% di terra con una pila
di celle appiattite contro il tetto delle quote; tre giri di taratura dopo, la
terra è al 40% e le quote si spandono fra 4 e 8 senza saturare.

### Le zone

Il mondo è una **scacchiera di zone 32x32** — la vecchia misura del mondo
intero, che adesso è il pezzo che si compra. Se ne possiede una all'inizio,
quella al centro, e le altre si comprano con lo strumento **Espandi**.

- **Si comprano solo le zone che confinano** con una già tua: serve a fare una
  città sola invece di isole sparse.
- **Il prezzo cresce a ogni zona presa** (120 crediti la prima, poi × 1,6):
  allargarsi deve restare una scelta, non l'automatismo che si fa perché tanto
  costa poco. Centoventi crediti sono cinque ore di concentrazione.
- **Fuori dalle tue zone non si costruisce e non si scava**, e il rifiuto dice
  perché e cosa fare.
- **Quello che non è tuo si vede lo stesso**, sotto un velo scuro ma non opaco:
  la collina che potresti comprare devi poterla vedere, è metà del motivo per
  comprarla.

**Un mondo grande e finito, non infinito.** Il piano diceva di generare il
terreno da una funzione delle coordinate globali, così da poter aggiungere zone
all'infinito. Si è fatta una cosa diversa e più semplice: il mondo intero — nove
zone, 96x96 celle — si genera tutto insieme dal seme, come prima, e il giocatore
ne possiede una parte. I confini fra zone combaciano perché non sono confini:
è una griglia sola. E soprattutto l'erosione e i fiumi, che sono processi
globali e non funzioni locali, continuano a girare su tutto il mondo senza
margini di sovrapposizione né determinismo a blocchi — cioè senza la parte
difficile. Nove volte l'area di prima sono abbastanza; se un giorno non lo
saranno, la strada dell'infinito è ancora lì, e il costo di averla rimandata è
zero.

**Le partite vecchie restano quelle che erano.** Un salvataggio nato quando il
mondo era una zona sola non ha nessuna zona scritta dentro: in quel caso sono
sue tutte quelle che il suo mondo conteneva — cioè l'unica — e ci si continua a
costruire come prima. Il terreno però si rigenera dal seme, e il seme adesso
passa per un generatore diverso: **una città salvata prima di questa modifica si
riapre su un paesaggio nuovo**. È il prezzo di non salvare il terreno, ed è lo
stesso prezzo che si paga da sempre; solo che finora nessuno aveva cambiato il
generatore.

| Prova | Esito |
|---|---|
| Sei semi diversi | 40% di terra in media, quote spanse fra 4 e 8, prateria ovunque |
| Partita nuova | mondo 3x3 zone da 32, una sola in mano, quella al centro |
| Costruire in casa | si può; fuori dalle proprie zone no, e lo dice |
| Il badile fuori zona | non lavora |
| Zona accanto / propria / d'angolo / fuori mappa | comprabile solo la prima |
| Comprare | scala i crediti, la aggiunge, e da lì in poi ci si costruisce |
| La zona dopo | costa di più (192 contro 120) |
| Senza crediti | non si compra |
| Il velo | copre tutto quello che non è tuo |

Guardati anche i frame veri: quattro mondi affiancati per vedere che
l'algoritmo non è stato solo fortunato con un seme, e il mondo intero da lontano
con due zone accese in mezzo a sette spente.

## Il piano per il prossimo giro

### Il mondo infinito

Oggi il mondo è una scacchiera di nove zone e finisce lì: comprate tutte, non
c'è un decimo riquadro. La scelta era consapevole — genero tutto insieme dal
seme, e i processi globali girano su tutto senza la parte difficile — ma il
limite si tocca, e adesso si vuole toglierlo. **Il giocatore deve poter comprare
zone finché ha crediti, in qualunque direzione, senza un bordo.**

Il cuore della cosa è una sola: **il terreno smette di essere un array e diventa
una funzione**. Oggi `CityTerrain` nasce con una `size` e riempie tre array
paralleli; domani la quota di una cella deve dipendere solo dalle sue coordinate
assolute e dal seme del mondo, e la zona a est deve combaciare con quella che
c'è già perché entrambe rispondono alla stessa funzione, non perché qualcuno le
ha cucite.

#### Il problema vero: i processi globali

Il rumore è già una funzione delle coordinate: quello si trasporta così com'è.
Non lo sono le tre cose che rendono il mondo un paesaggio, e sono esattamente
quelle che sono state aggiunte per ultime.

- **L'erosione** guarda i vicini, e attraverso le passate guarda i vicini dei
  vicini. Con tre passate su un intorno di quattro celle il suo raggio d'azione
  è tre celle: una frana non si propaga più in là.
- **I fiumi** partono da un punto alto e scendono a valle finché trovano il
  mare. Un fiume può essere lungo trenta celle, e non c'è un tetto: il suo
  raggio d'azione è quanto è lungo il fiume.
- **La classificazione delle acque** oggi dice «è mare quello che si tocca
  partendo dal bordo mappa». In un mondo senza bordo la frase non vuol dire
  niente.

La risposta per le prime due è la stessa: **generare a blocchi con un margine di
sovrapposizione**. Per produrre una zona si genera un riquadro più largo — la
zona più `M` celle per lato — ci si fanno girare sopra i processi locali, e si
tiene solo la parte centrale. Se `M` supera il raggio d'azione del processo, il
risultato è identico qualunque zona si sia chiesta, e le cuciture non esistono
perché non c'è niente da cucire. Costa: si genera più terreno di quello che si
tiene, e la stessa cella viene calcolata più volte da zone diverse. È il prezzo,
ed è accettabile finché `M` resta piccolo.

Per l'erosione `M = 4` basta e avanza. Per i fiumi no, e qui va presa una
decisione:

1. **Fiumi su griglia grossa.** Si traccia il reticolo idrografico su una
   griglia rada — una cella ogni otto, diciamo — che copre un'area grande a
   piacere e costa poco perché è sedici volte più piccola. I fiumi diventano
   allora un dato di consultazione, come il rumore: «per questa cella, passa un
   fiume?» si risponde guardando la polilinea più vicina. È la strada che tiene
   i fiumi lunghi senza generare mezzo mondo.
2. **Fiumi troncati al margine.** Si accetta che un fiume possa interrompersi
   dove finisce la finestra di generazione. Più semplice, e visibilmente
   sbagliato: un fiume che finisce nel nulla si nota.
3. **Niente fiumi fuori dalla prima zona.** Onesto ma triste.

La prima è quella giusta, ed è anche l'unica che regge se un giorno si vorranno
i bacini idrografici veri.

Il mare invece **sparisce come categoria**: quelli che oggi sono mari diventano
laghi grossi. La definizione di adesso — «è mare l'acqua che si tocca partendo
dal bordo mappa» — in un mondo senza bordo non vuol dire niente, e le soluzioni
che la salvavano volevano tutte una soglia inventata: una distesa più larga di
`N` celle è mare, sotto è lago. Ma quella soglia non decide niente che il
giocatore possa vedere. Un lago e un mare si comportano già allo stesso modo:
stanno a una quota, ci si costruiscono sopra ponti, li si scava e li si riempie
col badile. L'unica differenza vera era il colore, ed è un prezzo basso da
pagare per togliere di mezzo un flood fill globale che in un mondo infinito non
saprebbe da dove partire.

Quello che resta è più semplice di prima: **l'acqua sotto il livello di
riferimento è un lago, l'acqua che scende a gradini è un fiume.** Nessuna delle
due ha bisogno di sapere quanto è grande il mondo. Le distese larghe restano
larghe — il rilievo non cambia — ma non sono più un'entità a parte, e la costa
smette di essere il confine del mondo per tornare a essere solo una riva.

#### Cosa si rompe, in ordine di fastidio

- **`CityGrid` non ammette coordinate negative** (`in_griglia` vuole `x >= 0`) e
  ha una `size`. Serve o un'origine mobile — il mondo si estende attorno a un
  punto che resta a zero — o coordinate con segno. La seconda è più pulita e
  tocca più codice; la prima è un trucco che prima o poi si paga.
- **La mesh del terreno era una sola per tutto il mondo** — **chiuso**: adesso
  è una per zona, e una modifica rifà solo le zone che ha cambiato. Vedi «Una
  mesh per zona», in fondo.
- **Il velo sulle zone non tue** scorreva tutte le celle del mondo. Con un mondo
  infinito «tutte le celle» non esiste — **chiuso**: adesso si disegna solo
  quello che è tuo e l'anello di zone comprabili, velo compreso. Vedi «Si vede
  solo quello che si può prendere», più sotto.
- **La camera non ha limiti** già adesso, quindi lì non cambia niente — ma
  diventa il modo con cui ci si perde. Serve un «torna alla città», o la
  bussola.
- **Il salvataggio** ha già la lista delle zone possedute e non salva il
  terreno: quella parte è pronta, ed è il pezzo di lavoro che era stato fatto
  bene in anticipo.

#### Da decidere

- **Il prezzo di una zona non può crescere all'infinito** com'è adesso (×1,6 a
  ogni acquisto): alla ventesima zona costerebbe più di quanto si guadagni in un
  anno. O si mette un tetto, o la crescita diventa lineare, o si paga in
  proporzione a quanto si è già costruito invece che a quante zone si hanno.
- **Che senso ha espandersi**, oltre allo spazio. Se una zona lontana è solo
  altre celle uguali, comprarla è un numero che sale. Le zone dovrebbero avere
  un carattere — un fiume, una baia, una montagna — e forse è lì che la
  generazione a blocchi larghi si ripaga.
- **Quante zone tenere vive.** Un mondo infinito non si tiene tutto in memoria:
  serve decidere quando una zona lontana si può scaricare, e cosa succede alle
  costruzioni che ci stanno sopra (nel salvataggio ci sono già, quindi
  probabilmente niente).

#### L'ordine di lavoro

1. ~~**Spezzare la mesh per zona.**~~ Fatto. Serviva comunque, non ha rotto
   niente, e si è misurato: cinque volte più svelto oggi, e non peggiora se il
   mondo cresce.
2. **Il terreno come funzione**, con generazione a blocchi e margine, a mondo
   ancora finito: si può confrontare cella per cella col generatore di adesso e
   pretendere che dia lo stesso risultato. È il controllo che rende sicuro tutto
   il resto.
3. **I fiumi su griglia grossa**, che è il pezzo con più design dentro.
4. **Le coordinate senza bordo**, e la compravendita di zone che non esistono
   ancora.

### Le strade si tracciano, non si posano una per una

Oggi una strada si costruisce una cella per volta, scegliendo a mano il pezzo
giusto: dritto, curva, T, incrocio, testata. Per un incrocio sono quattro clic e
quattro scelte, e sbagliare pezzo si vede subito. Si vuole invece **tracciare un
percorso** — premere in un punto, trascinare fino a un altro, rilasciare — e
trovarcisi una strada già fatta.

Il grosso del lavoro non è tracciare il percorso: è **scegliere i pezzi**.

- **Ogni cella di strada guarda i suoi quattro vicini** e da lì esce il modello e
  la rotazione: due vicini opposti fanno un dritto, due adiacenti una curva, tre
  una T, quattro un incrocio, uno solo una testata. È una tabella di sedici casi
  su una maschera di quattro bit, e va scritta una volta sola.
- **Le strade che già ci sono cambiano forma.** Attaccandosi a un dritto, quel
  dritto diventa una T: non basta posare le celle nuove, bisogna **ricalcolare
  anche i vicini** di ogni cella toccata. È la parte che si dimentica e che si
  nota subito.
- **Il dislivello vuole le rampe.** Dove il percorso sale di un gradino non ci va
  una strada piana ma una `sloped_road`, girata nel verso della salita; dove sale
  di più, o si spiana o non si passa. Questa parte parla con le regole del
  terreno che ci sono già, e va decisa insieme a loro.
- **L'acqua vuole i ponti.** Un percorso che attraversa un fiume dovrebbe posare
  un impalcato e le sue rampe, che è la composizione già verificata in Blender.
  Vale la pena farlo al primo giro? Forse no: prima le strade su terra, poi
  l'acqua.

Da decidere:

- **Che forma ha il percorso.** A mano libera, seguendo il cursore cella per
  cella, è quello che fa il dito su una mappa; a **elle**, cioè due segmenti
  ortogonali con un angolo solo, è quello che fanno i city builder, ed è più
  facile da tirare dritto. Probabilmente serve tutt'e due, con l'elle di
  default e la mano libera tenendo un tasto.
- **Cosa succede a quello che c'è in mezzo.** Il percorso incrocia una casa: si
  ferma prima, la aggira, o rifiuta? Fermarsi prima è il comportamento che non
  fa danni e non sorprende — la strada arriva fin dove poteva.
- **Il prezzo si vede mentre si traccia.** Il numero di celle per il prezzo di
  una strada, aggiornato mentre si trascina, e il tracciato in rosso appena
  sfonda i crediti: decidere dopo aver pagato è la cosa che si vuole togliere.
- **Come si annulla.** L'Esc durante il trascinamento non posa niente. Dopo,
  invece, è una demolizione come le altre — a meno che non si voglia un «disfai
  l'ultima strada», che però è una cosa nuova per tutto il gioco e non solo per
  le strade.

Il pezzo riutilizzabile è la tabella dei sedici casi: la stessa che serve alle
strade servirà, il giorno che si vorranno, ai ponti e ai muri. Vale la pena
scriverla come una cosa a sé, che dalla maschera dei vicini restituisce id del
modello e rotazione, e non come un `match` nascosto dentro il piazzatore.

## Si vede solo quello che si può prendere

Il mondo si disegnava tutto. Nove zone su nove, quelle comprate e quelle no, le
seconde sotto un velo scuro; il velo diceva «non è tua», ma il paesaggio sotto
c'era, e la mappa finiva dove finiva l'array. Adesso **si disegna quello che è
tuo e l'anello di zone che confinano con qualcosa di tuo, e basta.**

La regola è la stessa che decide cosa si può comprare — `_comprabile()`, che
esisteva già — e quella coincidenza è metà del motivo per cui vale la pena: **si
vede esattamente quello che si può prendere.** Non c'è una zona lontana che si
guarda per mesi senza poterla toccare, e non c'è un pezzo di mondo comprabile
che non si sia mai visto.

Come funziona, in due pezzi:

- **Una maschera di celle**, un byte per cella, parallela al terreno. La riempie
  `CityView._aggiorna_visibilita()` scorrendo le zone, non le celle: sono nove
  domande invece di novemila. La leggono le tre mesh del mondo — terreno, acqua
  e reticolo — e una maschera vuota vuol dire «tutto», così chi non ha niente da
  nascondere non deve costruirsene una piena di uno.
- **I fianchi si chiudono sul bordo del visibile** esattamente come si chiudevano
  sul bordo della mappa: `_quota_vicina()` non distingue più fra «fuori mappa» e
  «fuori dalla maschera», e in tutti e due i casi il terreno cala sotto il pelo
  dell'acqua. Senza, il bordo del disegnato si vedrebbe in trasparenza. Con,
  il mondo finisce con una scogliera, e ogni zona comprata la sposta più in là.

Comprare rifà il terreno e non solo il velo: la zona presa scopre l'anello che
adesso le confina, quindi le celle da disegnare cambiano più di quelle appena
comprate. È l'unico posto dove ricostruire tutto costa, ed è una volta per
acquisto.

Quello che non cambia: la collisione del terreno nasce dalla sua mesh, quindi il
raggio del mouse non trova più niente dove non si disegna — e non c'era niente
da cliccare comunque, perché le zone lontane non erano comprabili nemmeno prima.

Il conto vero, però, è un altro. **Questo è il primo pezzo del mondo infinito
che si poteva scrivere senza toccare la generazione**: quando le zone non
avranno più un numero, «disegna tutto» non sarà solo lento, sarà impossibile.
Averlo già fatto vuol dire che il giorno del terreno-funzione resta un problema
solo — generare — e non due.

## Una mesh per zona

Il terreno era **una mesh sola e un trimesh solo** per tutto il mondo, rifatti
interi a ogni modifica. Un colpo di badile tocca una cella; ne faceva ricostruire
novemila, più la forma di collisione che serve al raggio del mouse. Adesso ogni
zona ha la sua mesh, la sua acqua, il suo reticolo e il suo corpo, e una modifica
rifà solo le zone che ha cambiato.

Le misure, su un mondo di prova con cinque zone visibili:

| | prima | adesso |
|---|---|---|
| colpo di badile in mezzo a una zona | 328 ms | **64 ms** |
| colpo sul confine fra due zone | 328 ms | **129 ms** |

Cinque volte, e il numero che conta non è il cinque: è che **64 ms non
cresceranno**. Con nove zone possedute il vecchio codice ne avrebbe messi circa
seicento; con novanta, seimila. Il costo di adesso dipende da quante zone la
modifica tocca — una, o due se si scava sul confine — e non da quanto è grande
il mondo.

Tre cose che il lavoro ha tirato fuori, e che non erano nel piano:

- **Le celle toccate non sono le celle cambiate.** `riclassifica()` rifà biomi e
  acque su tutta la mappa, ed è quello che fa funzionare il canale scavato a
  mano: un colpo di badile qui può spostare una riva dall'altra parte del mondo.
  Rifare «la zona della cella toccata» sarebbe stato sbagliato in modo
  invisibile finché uno non scava un canale. Così `CityTerrain` ha imparato a
  farsi una `fotografia()` di quote, biomi e pelo dell'acqua, e a dire con
  `celle_cambiate()` cosa si vede diverso: costa una scansione dell'array, che
  è nulla accanto a una mesh.
- **Il vicinato va rifatto insieme.** Il fianco di un gradino appartiene alla
  cella più alta, che può stare nella zona accanto: alzare una cella sul confine
  scopre una parete che l'altra zona ha in carico. Per questo una cella cambiata
  sporca la sua zona e quelle delle sue quattro vicine — ed è il motivo per cui
  il colpo sul confine costa il doppio invece di uguale.
- **La maschera di visibilità e il riquadro sono due cose diverse.** La maschera
  dice cosa esiste, il riquadro dice di chi è il compito di disegnarlo. Non si
  possono fondere: una cella fuori dal riquadro va guardata comunque, per sapere
  se quella dentro ha un fianco scoperto.

Dove vanno i 64 ms, per il giorno che non basteranno: 43 a costruire la mesh del
terreno con `SurfaceTool`, 11 ad acqua e reticolo, 8 al trimesh di collisione. Il
collo è la mesh, non la fisica — il contrario di quello che ci si aspetterebbe,
e vuol dire che il prossimo guadagno sta nell'emettere meno quadri, non nel
cambiare forma di collisione.

Il velo sulle zone non tue resta una mesh sola per tutte, e va bene così: cambia
quando cambia cosa è tuo, cioè una volta ogni acquisto, non a ogni gradino.

## Prossimo passo

Il mondo infinito, qui sopra: il primo passo dell'ordine di lavoro è fatto, e
resta il terreno come funzione. Le cinque fasi erano chiuse da un pezzo; quello
che è venuto dopo — servizi, strada, conti, spostamento, abitanti, lavoro,
felicità, aree, mondo e zone — è la città che chiede qualcosa a chi la
costruisce.

Restano anche due cose che non sono debiti ma scelte, e si decidono giocando:

- **Il bilanciamento con sette servizi di zona.** Coprire 32x32 con sette aree è
  parecchio; con nove zone lo è nove volte. Se la felicità si rivela un muro
  invece che un obiettivo, i raggi e la soglia sono due numeri in
  `economy.json`.
- **Cosa succede a una città infelice**, oltre allo spopolamento: per ora la
  felicità è un punteggio da far salire, non una tassa da pagare.
