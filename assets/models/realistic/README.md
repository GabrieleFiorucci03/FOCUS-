# FOCUS! — realistic preview library

Questa cartella contiene una variante sperimentale dei 91 asset del kit MVP.
Non sostituisce `assets/models/generated/` e non e attualmente caricata dal
gioco. Il file `.gdignore` evita inoltre che Godot importi i GLB prima della
valutazione.

Caratteristiche mantenute:

- stessi ID e seed;
- stessi footprint e unita di griglia;
- stesso asse frontale `-Y`;
- stesse modalita di origine e collisioni;
- catalogo JSON compatibile con `CityCatalog`.

Caratteristiche della variante:

- palette piu naturale e materiali PBR differenziati;
- bevel a due segmenti e primitive curve piu dense;
- infissi, davanzali, illuminazione esterna e dettagli sui tetti;
- dettagli specifici per strade, ponti, servizi, verde e infrastrutture;
- circa 4,4 volte i triangoli del kit MVP.

La libreria si rigenera con:

```powershell
./tools/blender/generate_realistic_assets.ps1
```

Le tavole di controllo sono in `assets/previews/realistic/`.
