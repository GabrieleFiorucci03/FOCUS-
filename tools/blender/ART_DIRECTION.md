# Direzione artistica — Focus Grove

## Obiettivo

La citta deve comunicare crescita, calma e leggibilita. Le forme sono semplici
ma non infantili: basi solide, spigoli leggermente smussati, tetti marcati e
dettagli grandi abbastanza da restare visibili dalla camera isometrica.

## Linguaggio visivo

- proporzioni leggermente compatte e verticali;
- colori flat con elevata separazione tra facciata, tetto e finestre;
- terracotta per legare visivamente i quartieri;
- teal per ingressi, trasporti e accenti positivi;
- corallo per emergenza e dettagli ad alta attenzione;
- niente testo incorporato nei modelli;
- dettagli funzionali riconoscibili tramite silhouette e colore;
- bevel piccoli, un solo segmento, shading piatto.

## Scala e orientamento

- `1 tile = 2 metri`;
- origine al centro della base;
- asse verticale `+Z` in Blender;
- fronte edificio verso `-Y`;
- footprint sempre conservativo: nessuna geometria essenziale deve invadere la
  cella adiacente.

## Budget indicativi per LOD0

| Categoria | Triangoli obiettivo |
|---|---:|
| Albero | 100–300 |
| Casa / negozio | 250–900 |
| Condominio / servizio | 700–2.500 |
| Torre | 1.500–4.000 |
| Parco completo | 1.000–3.500 |
| Modulo stradale | 100–400 |

I dettagli sono mesh geometriche semplici e condividono materiali. In Godot,
alberi e decorazioni ripetute dovranno essere istanziati con `MultiMesh`.

## Evoluzione prevista

Il kit MVP stabilisce palette, scala e naming. I generatori successivi potranno
aggiungere classi economiche, facciate, balconi, giardini e LOD senza cambiare
le convenzioni di importazione.

## Paesaggio con la libreria refined_v2

Il terreno riprende la palette di `generate_refined_assets.py`: pianura
`grass` (#737f54), collina `leaf` (#586b43), prateria `grass_light` (#8c9368),
spiaggia sabbia dorata (#cebc86, dal `cream` #c9bea9),
scarpata `soil` (#70624f). L'acqua usa una variante
piu scura di `water` (#365c64, dal #547e85 del kit), con fondali freddi e
trasparenza leggera (opacita 0,761).

`scripts/city/terrain_mesh.gd` mantiene i colori dei biomi nei vertici, con
una variazione fra celle ridotta a 0,018. `assets/shaders/terreno.gdshader`
aggiunge grana opaca in coordinate mondo, continua fra zone e attenuata a
distanza. `assets/shaders/acqua.gdshader` mantiene tinta e rugosita uniformi,
con piccole increspature irregolari e lente nei soli riflessi, attenuate a
distanza: nessuna banda sinusoidale o pulsazione di colore sugli oceani.
Il pelo dell'acqua e tutti i vertici restano fermi. Nessuna texture aggiuntiva,
nessuna nuova superficie per cella.

La revisione riguarda esclusivamente la presentazione: generazione, quote,
biomi, idrografia, collisioni e salvataggi mantengono le regole esistenti.
