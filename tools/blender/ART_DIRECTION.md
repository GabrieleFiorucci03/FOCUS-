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

