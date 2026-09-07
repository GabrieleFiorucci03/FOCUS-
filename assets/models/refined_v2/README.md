# FOCUS! — la libreria del gioco

140 modelli GLB: è **questa** la libreria che il gioco carica, l'unica.
`CityCatalog.CARTELLA_MODELLI` punta qui e `catalog.json` le tiene tutte
insieme. Le librerie precedenti — `generated` e `realistic` — restano su disco
come storia del progetto, ma nessuno le legge più.

Dentro ci sono due serie, che si distinguono per il campo `collection` della
voce di catalogo e nient'altro:

- **il kit di base**, 91 modelli, senza `collection`. Stessi ID, seed,
  footprint, orientamento e collisioni della vecchia libreria `realistic`: una
  città salvata si riapre identica e cambia solo di aspetto. Li genera
  `tools/blender/generate_refined_assets.py`.
- **l'espansione**, 49 modelli con ID `EXP_*` e `collection:
  refined_expansion`: case e ville con giardino, palazzi, grattacieli, negozi,
  fabbriche, centrali, stadio e presidi civici. Li genera
  `tools/blender/generate_refined_expansion.py`.

La revisione civica `civic_v3` sostituisce otto presidi del kit di base e
`EXP_FIRE_STATION`, e aggiunge `EXP_UNIVERSITY`. Conserva ID e lotti degli
edifici esistenti; le collisioni sono ora scatole dei singoli corpi, per seguire
ali e cortili. La geometria condivisa è in `tools/blender/refined_civic_geometry.py`.
Materiali, UV metriche e mappe incorporate usano la stessa pipeline refined.

L'università occupa 5×4 celle, costa 144 crediti e fornisce il nuovo servizio
`universita`: raggio base 18 + 4 del lotto = 22 celle, contributo alla felicità
12,5%, attivo con strada, corrente e acqua. I consumi e i posti di lavoro sono
calcolati sulle 12 celle costruite. Le città precedenti restano caricabili;
con i sette servizi precedenti la felicità è ora 87,5%.

[Galleria civica aggiornata](../../previews/civic_v3/index.html) ·
[Verifica dei dieci modelli](../../previews/civic_v3/validation.json).
Le statistiche e le gallerie qui sotto documentano la revisione precedente.

I due generatori restano due perché sono due liste di modelli diverse, ma
scrivono nella stessa cartella: ognuno rimette a posto le proprie voci di
`catalog.json` e lascia dove stanno quelle dell'altro. Nessuno dei due può
riscrivere il catalogo da zero senza portarsi via i modelli dell'altro.

Le `.png` accanto ai `.glb` non le scrive nessun generatore: le estrae Godot
importando i modelli, perché `gltf/embedded_image_handling` è impostato su
«estrai». Vanno lasciate dove sono — spostarle spezza i materiali degli asset
importati — e come tutto il resto dell'import si rifanno da sole.

Le gallerie di revisione: [i 91 a confronto](../../previews/refined_v2/index.html)
con la versione precedente, e [i 48 nuovi](../../previews/refined_expansion/index.html).

## Il kit di base

La revisione conserva soggetto, famiglia, ID, seed, footprint dichiarato,
orientamento, quota delle connessioni e geometria delle collisioni originali.
Le facciate seguono i singoli corpi degli edifici, comprese le ali e i rientri.
Le coperture dei corpi separati sono state riallineate e le porte collocate
sulle pareti effettive. Le finestre coprono i quattro lati; nella casa con
garage, la vetratura anteriore è integrata nel portone.

Materiali: palette di intonaci, pietra, verde oliva, metallo e terracotta;
mappe colore e rugosità incorporate nel GLB, UV metriche e dettagli geometrici.
Nessuna texture esterna o nodo procedurale necessario per la visualizzazione.
Le serre hanno pannelli traslucidi, montanti metallici e coltivazioni interne.

Verifica finale: 91 GLB e 364 immagini; 550 file precedenti identici e 91
collisioni corrispondenti. La libreria contiene 644.894 triangoli contro
358.950 della versione attuale (circa +80%); i GLB occupano circa 64 MiB.

Dettagli: telai, montanti, davanzali, persiane sulle abitazioni basse,
parapetti a bacchette, giunti di copertura, elementi sulle falde, scossaline,
comignoli, pluviali, portoni sezionati e maniglie. Verde, impianti, sport e
trasporti conservano le rispettive varianti con materiali e dettagli nuovi.

La scala resta quella compatta del gioco: è un kit diorama più credibile,
non un rilievo architettonico a scala reale. La densità geometrica aumenta;
le torri sono gli oggetti più onerosi. Non è stato misurato il framerate
in una città popolata e non sono ancora stati prodotti LOD dedicati.
Alcuni aggetti già presenti nelle ricette originali restano fuori dal lotto;
il rapporto documenta gli ingombri effettivi oltre ai footprint dichiarati.

## Rigenerazione

```powershell
blender --background --python tools/blender/generate_refined_assets.py
blender --background --python tools/blender/generate_refined_assets.py -- --asset RES_LOW_1x1_001
```

Il generatore scrive esclusivamente in `assets/models/refined_v2`.
Le ricette originali vengono riutilizzate in memoria, senza modificarne i file.
La generazione singola aggiorna la relativa voce nel nuovo catalogo.

```powershell
blender --background --python tools/blender/render_refined_assets.py -- --size 512 --samples 12
python tools/blender/review_refined_assets.py
```

L'ultimo comando richiede NumPy e Pillow, verifica integrità dei GLB,
collisioni e file precedenti, e ricrea galleria e tavole dai render.
La galleria funziona anche aprendo direttamente `index.html`, senza rete.

Rapporto: [validation.json](../../previews/refined_v2/validation.json).

I sette ponti `BRG_LOCAL_*` usano ora parapetti `continuous_miter_v3`.
Cordolo, traverso e corrimano sono profili continui con vertici condivisi nei
raccordi ad angolo. Il terminale ha un unico profilo a U, aperto sul lato
connesso. I rettilinei non hanno interruzioni centrali. Sulle rampe tutti i
profili seguono la quota del piano; larghezze ed estremità coincidono con i
moduli piani. La distanza minima cordolo/carreggiata è 0,1625 unità.

Le collisioni di origine rimangono invariate: la revisione riguarda le mesh
visive, non aggiunge collisioni fisiche per i parapetti.

Verifica dedicata: `python tools/blender/verify_bridge_barriers.py`.
Composizione di prova: `blender -b --python tools/blender/render_bridge_review.py`.
[Galleria dei ponti](../../previews/refined_v2/bridge_v3/index.html).
