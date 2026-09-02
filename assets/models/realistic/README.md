# FOCUS! — realistic preview library

Questa cartella contiene la libreria dei 91 asset che il gioco carica oggi:
`CityCatalog` punta qui per i `.glb` e per `catalog.json`. Il kit MVP resta in
`assets/models/generated/` come riferimento e come via di ritorno: per tornarci
bastano le due costanti in `scripts/city/city_catalog.gd`.

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
