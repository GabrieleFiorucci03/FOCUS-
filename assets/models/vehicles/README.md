# Veicoli stilizzati

Sei modelli originali per il traffico decorativo di FOCUS!: compatta teal,
berlina corallo, station wagon ocra, ambulanza, autopompa e polizia.
Forme a blocchi, smussi minimi, colori opachi e nessuna texture esterna.

I file GLB sono gli asset da importare. `source/vehicles.blend` contiene la
collezione modificabile; la cartella sorgente e esclusa dall'import Godot.
`catalog.json` e i JSON individuali riportano dimensioni e nodi animabili.

## Scala e animazione

- Larghezza totale di 0,324–0,354 unita, ruote comprese; corsia da 0,46 unita.
- Lunghezza di 0,566–0,816 unita. Proporzioni da miniatura, coerenti con le strade.
- Origine a terra, al centro del veicolo. Scala di importazione 1.
- Blender: alto +Z, fronte -Y. GLB/Godot: alto +Y, fronte **+Z**.
  Per un futuro `Node3D.look_at`, usare `use_model_front=true`.
- `Body` e una mesh statica. `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`
  hanno il pivot al centro della ruota e asse di rotazione locale X.
  Raggio 0,054: l'angolo di rotazione deriva dalla distanza percorsa / raggio.
- `Beacon_L` e `Beacon_R` sono mesh separate sui mezzi di emergenza.
  Per farle lampeggiare si potra variare l'emissione con materiali per istanza.
- 352–688 triangoli e 5–7 nodi mesh per veicolo; diversi materiali per mesh.
  Il costo del traffico dipendera anche da superfici, ombre e numero di istanze.
- Nessuna collisione statica, rig scheletrico o animazione incorporata.

Il runtime `scripts/city/traffico_decorativo.gd` li usa come traffico ambientale:
percorsi automatici, velocita diverse, ruote animate e lampeggianti senza sirene
o interventi. I pedoni sono piccoli blocchi colorati generati dal runtime.
Le superfici GLB vengono riunite per colore nei vertici e disegnate con
MultiMesh: sei batch carrozzerie, uno ruote, uno lampeggianti e tre per i pedoni.

Il limite e 32 veicoli e 64 persone vicino alla camera; niente ombre dinamiche
per questi elementi. Il traffico si ferma insieme alla vista citta in pausa
o durante il focus. Le modifiche stradali ricostruiscono i percorsi, senza dati
aggiuntivi nei salvataggi e senza conseguenze sull'economia.

Le auto tengono la destra, attendono agli incroci e controllano l'ingombro
orientato completo prima di ogni passo. Ai capolinea vengono ricreate altrove;
un raro ingorgo circolare viene sciolto ritirando un mezzo dopo 18 secondi.
Non ci sono corpi fisici o simulazione di incidenti. I pedoni seguono i bordi
dei marciapiedi e dei ponti, senza attraversare l'asfalto; niente pedoni sullo
sterrato. Allontanandosi con la camera, la popolazione decorativa si rinnova.

La scena `tests/TestTraffico.tscn` verifica 120 secondi di circolazione,
separazione fra veicoli, continuita dei percorsi, rampe ruotate e demolizioni.
Con `-- --preview` produce un render Godot in `traffic_in_game.png`.

## Rigenerare e verificare

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/blender/generate_vehicle_assets.py
```

Il generatore controlla dimensioni, budget poligonale, integrita GLB, nomi dei
nodi e corrispondenza fra triangoli esportati e metadata. Reimporta poi i GLB
per produrre `assets/previews/vehicles/catalog.png` e `road_scale.png`, usando
nel secondo render la strada `refined_v2` reale. I risultati automatici sono
in `assets/previews/vehicles/validation.json`.
