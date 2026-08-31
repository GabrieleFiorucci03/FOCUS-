# FOCUS! — pipeline asset Blender

Questa cartella genera il kit low-poly dell'MVP senza modellazione manuale.
Gli asset sono originali e usano una direzione visiva comune chiamata
**Focus Grove**: volumi morbidi e leggibili, materiali flat, pareti calde,
tetti in terracotta e accenti teal/corallo.

## Convenzioni

- Blender 4.5 o successivo, scala metrica; pipeline verificata con Blender 5.2.1 LTS.
- Una cella della griglia misura `2 x 2 m`.
- Origine di ogni asset al centro della base, con il fronte rivolto verso `-Y`.
- Geometria visuale unita in una sola mesh per ridurre il numero di nodi.
- Materiali condivisi per colore, senza texture esterne.
- Collisione semplificata con suffisso Godot `-colonly`.
- Nomi come `RES_LOW_1x1_001.glb`.
- Metadata JSON affiancati ai GLB.

## Generazione

Da PowerShell, nella cartella principale del progetto:

```powershell
blender --background --python tools/blender/generate_mvp_assets.py
```

Per generare un solo asset:

```powershell
blender --background --python tools/blender/generate_mvp_assets.py -- --asset RES_LOW_1x1_001
```

Per scegliere una cartella di output:

```powershell
blender --background --python tools/blender/generate_mvp_assets.py -- --output C:\percorso\models
```

Gli output predefiniti finiscono in `assets/models/generated/`. Il file
`catalog.json` contiene footprint, seed, altezza e conteggio dei triangoli.

## Cataloghi visuali reali

Dopo aver generato i GLB, questo comando li reimporta e produce quattro scene
Blender e quattro render PNG:

```powershell
blender --background --python tools/blender/render_asset_catalog.py
```

Gli output finiscono in `assets/previews/` e sono suddivisi in residenziale,
urbano, infrastrutture e trasporti. Le collisioni `-colonly` vengono nascoste
nel render.

La composizione reale di un ponte sopra l'acqua e di una strada su due livelli
di collina viene generata con:

```powershell
blender --background --python tools/blender/render_transport_demo.py
```

## Kit generato — 91 asset

- 10 case, incluse varianti con garage, duplex, portico e corte
- 6 condomini e 2 palazzoni
- 4 ville e 3 torri residenziali
- 6 negozi, 3 uffici e 3 fabbriche/magazzini
- 4 parchi
- 2 stazioni di polizia, 2 caserme e 2 strutture sanitarie
- 5 moduli di strada locale e 5 moduli sterrati
- 6 alberi riutilizzabili
- 2 scuole
- fienile e serre
- turbina eolica, torre idrica e campo solare
- campo da calcio e campo da basket
- 8 rampe stradali modulari, asfaltate e sterrate, con dislivello di 0,5 m
- 7 moduli di impalcato/raccordo per ponti
- 3 piloni di altezze differenti e una spalla di ponte

## Contratto altimetrico

- una cella misura 2 m;
- un livello di terreno misura 0,5 m;
- le rampe dichiarano `connections` con quota nord/sud;
- gli impalcati dei ponti hanno origine sulla superficie stradale e possono
  essere piazzati dal runtime a qualunque quota;
- piloni e spalle sono asset separati, quindi la lunghezza del ponte non e
  prefissata;
- i tratti in salita e discesa includono collisioni inclinate `-colonly`.

Il generatore e deterministico: lo stesso ID e seed producono lo stesso asset.
Le specifiche sono centralizzate in `focus_asset_specs.py`.

## Variante realistica sperimentale

La variante realistica riusa gli stessi 91 ID, footprint, seed, orientamento e
collisioni del kit principale, ma applica materiali meno saturi, primitive piu
morbide e un livello aggiuntivo di dettagli architettonici e infrastrutturali.
Non sovrascrive il kit usato dal gioco: gli output finiscono in
`assets/models/realistic/` e le tavole in `assets/previews/realistic/`.

```powershell
./tools/blender/generate_realistic_assets.ps1
blender --background --python tools/blender/render_realistic_catalog.py
```

Per rigenerare un solo modello durante l'iterazione:

```powershell
./tools/blender/generate_realistic_assets.ps1 -Asset RES_LOW_1x1_001
```

Questa libreria e intenzionalmente separata e non e ancora referenziata da
`data/catalog.json` o dalle scene Godot. La sostituzione puo quindi avvenire in
un secondo momento, dopo la valutazione visiva e prestazionale.
