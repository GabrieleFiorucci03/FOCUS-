# FOCUS! — galleria della proposta 02

Apri **index.html** nel browser. I pulsanti filtrano le categorie; la ricerca
accetta nome o ID. Seleziona **Retro + sinistra** per vedere i due lati nascosti.
Clicca un'immagine per ingrandire la coppia; le frecce scorrono gli asset.
Il collegamento **Modello GLB** apre o scarica il file della nuova proposta.

Ogni coppia deriva dai GLB reimportati in Blender, con la stessa camera,
scala, illuminazione e gestione colore. I materiali mostrati sono quelli
incorporati nei file, non una simulazione aggiunta alle immagini.

- `comparison.jpg`: selezione dei confronti prima/dopo.
- `catalog_residenze.jpg`: tutte le 25 abitazioni.
- `catalog_citta.jpg`: commercio, uffici, industria, scuole e servizi.
- `catalog_paesaggio.jpg`: vegetazione, parchi, agricoltura, impianti e sport.
- `catalog_trasporti.jpg`: tutti i moduli stradali e dei ponti.
- `renders/`: due versioni e due angoli per ogni asset.
- `validation.json`: controlli dei 91 GLB e confronto delle collisioni.
- `original_hashes.json`: impronte SHA-256 dei file precedenti, prima del lavoro.

La libreria è in `assets/models/refined_v2`. Il gioco continua a usare
`assets/models/realistic`. Le note tecniche e i comandi di rigenerazione
sono nel [README dei modelli](../../models/refined_v2/README.md).
