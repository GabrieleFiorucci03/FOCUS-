# Edifici civici — revisione 3

Dieci GLB nella libreria attiva `assets/models/refined_v2`: due presidi sanitari,
tre caserme, due presidi di polizia, due scuole e un'università nuova.
La galleria mostra le viste frontali e posteriori dei GLB reimportati.

Le ricette condivise sono in `tools/blender/refined_civic_geometry.py`.
Si rigenerano tramite i normali generatori `generate_refined_assets.py` (ID CIV/EDU)
e `generate_refined_expansion.py` (ID EXP), entrambi con `--asset ID` ripetibile.

```powershell
blender -b --python tools/blender/generate_refined_expansion.py -- --asset EXP_UNIVERSITY
blender -b --python tools/blender/review_civic_assets.py
```

La revisione verifica unicità del catalogo, corrispondenza dei JSON, geometria
finita, triangoli, collisioni, UV, texture incorporate, finestre sui quattro
lati e contenimento nel lotto. Produce 20 render, galleria HTML e tavola PNG.
`--skip-existing` riutilizza le immagini già presenti: ometterlo dopo modifiche
alla geometria, oppure renderizzare gli ID cambiati con `--asset ID`.

Il servizio università è l'ottavo contributo alla felicità: 12,5 punti percentuali
entro 22 celle dal centro del campus, con strada, acqua e corrente disponibili.
La scena `tests/TestFelicita.tscn` verifica gli otto contributi, il raggio anche
dopo rotazione, demolizione e ricostruzione del campus, la media pesata e l'abbandono.
