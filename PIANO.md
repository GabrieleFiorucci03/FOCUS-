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

- [ ] Ricostruzione della mesh a blocchi. Oggi si rifà tutto il terreno a ogni
      modifica: su 32x32 regge, su una mappa grande no.
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
  assets/models/generated/   # 91 .glb + catalog.json
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

## Prossimo passo

Le cinque fasi sono chiuse: il giro è completo e rifinito. Quello che resta
sono scelte, non debiti — la mesh del terreno a blocchi se la mappa dovrà
crescere, e il bilanciamento da riguardare dopo averci vissuto qualche
settimana, che è l'unica prova che il simulatore non sa fare.
