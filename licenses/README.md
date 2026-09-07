# Licenze e avvisi della distribuzione

FOCUS! è distribuito sotto [GNU GPL-3.0](../LICENSE).
Il motore e le sue dipendenze conservano le rispettive licenze.

[THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) contiene la licenza MIT
di Godot, gli avvisi di copyright dei componenti e i testi integrali delle
licenze restituiti da Godot 4.7.2 ufficiale (ed1daf0bf), la versione usata
per compilare FOCUS! v1.2. L'elenco completo include anche componenti opzionali
o dell'editor e conserva tutti gli avvisi forniti dal motore.
Gli avvisi sono inclusi nello ZIP e disponibili anche come allegato
separato della release per chi scarica soltanto `FOCUS.exe`.

Conservare `LICENSE.txt` e `THIRD_PARTY_NOTICES.txt` insieme all'eseguibile
quando lo si ridistribuisce. I sorgenti della build v1.2 corrispondono al
[tag v1.2](https://github.com/GabrieleFiorucci03/FOCUS-/tree/v1.2).
L'integrazione documentale successiva non modifica l'eseguibile o quel tag.

La procedura segue le [indicazioni ufficiali di Godot sulle licenze](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).
I testi sono estratti tramite `Engine.get_license_text()`,
`Engine.get_copyright_info()` e `Engine.get_license_info()`; non sono una
selezione manuale di poche dipendenze.

Per rigenerarli con la stessa versione di Godot usata per la build, dalla
radice del repository:

```powershell
$destination = Join-Path (Get-Location) 'licenses/THIRD_PARTY_NOTICES.txt'
godot --headless --path . --script res://tools/release/genera_avvisi.gd -- $destination
```

## Verifica delle condizioni di Claude

Verifica del 7 settembre 2026: il progetto è stato sviluppato anche con
l'aiuto di Claude. Nei termini standard consultati non è stato individuato
un obbligo generale di inserire un credito a Claude o Anthropic per la sola
pubblicazione di un programma realizzato con tale assistenza:

- [Consumer Terms, sezione 4](https://www.anthropic.com/legal/consumer-terms):
  assegnazione all'utente degli eventuali diritti di Anthropic sugli output,
  subordinata al rispetto delle condizioni.
- [Commercial Terms, sezione B](https://www.anthropic.com/legal/commercial-terms):
  diritti del cliente sugli output nei limiti della legge applicabile.
- [Service Specific Terms](https://www.anthropic.com/legal/service-specific-terms):
  nessun obbligo generale aggiuntivo di attribuzione individuato per questo caso.

Questa nota documenta la verifica e l'assistenza allo sviluppo; non attribuisce
ad Anthropic la titolarità del gioco e non indica sponsorizzazione o approvazione.
Eventuali contratti individuali o condizioni di altri fornitori tramite cui
sia stato utilizzato Claude non sono stati verificati. Restano da rispettare
le licenze di eventuale materiale di terzi presente negli output.
