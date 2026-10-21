# Rainmeter Calendar

Widget per [Rainmeter](https://www.rainmeter.net/) (Windows) con la vista mensile di **Google Calendar** e
**Google Tasks**: mostra eventi e attività di tutti i calendari selezionati nel tuo account, e permette di
crearli, completarli ed eliminarli direttamente dal desktop.

Questo repository contiene anche le due pagine pubbliche (`index.html`, `privacy.html`) servite da
GitHub Pages su <https://fabiofctrl.github.io/>: Google le richiede per pubblicare il client OAuth.

## Contenuto

```
index.html, privacy.html          sito GitHub Pages (home + informativa privacy)
rainmeter/GoogleCalendar/         la skin, da copiare nella cartella Skins di Rainmeter
  GoogleCalendar.ini              skin (generata da Tools/gen_ini.py)
  @Resources/Variables.inc        impostazioni: aggiornamento, dimensioni, colori
  @Resources/Scripts/GCal.lua     griglia, pannelli, modulo (file UTF-16 LE)
  @Resources/Scripts/gcal.ps1     chiamate alle API Google e login OAuth (PowerShell 5.1)
  @Resources/Tools/gen_ini.py     rigenera GoogleCalendar.ini
  @Resources/Google/LEGGIMI.txt   guida completa: configurazione Google, limiti, altri PC
```

## Installazione

- **Primo PC**: segui la parte A di
  [`LEGGIMI.txt`](rainmeter/GoogleCalendar/@Resources/Google/LEGGIMI.txt) (progetto Google Cloud,
  API, client OAuth "App desktop", collegamento).
- **Altri PC**: parte B. Basta copiare la skin e il proprio `client_secret.json`, poi ricollegare
  l'account. Il progetto Google non va ricreato.

Non serve installare altro: PowerShell 5.1 e i plugin InputText/RunCommand sono già inclusi in
Windows e Rainmeter. Python serve solo per rigenerare il `.ini` dopo aver modificato `gen_ini.py`.

## Privacy

`client_secret.json`, `token.dat` e i dati scaricati sono esclusi da `.gitignore`. Il widget comunica
solo con le API Google; vedi [privacy.html](privacy.html).

## Note per chi modifica il codice

- `GCal.lua` va mantenuto in **UTF-16 LE**: è l'unico modo perché Rainmeter gestisca i caratteri
  accentati. `.gitattributes` (`* -text`) lo conserva byte per byte; su GitHub appare come file binario.
- Le coordinate dei pannelli sono condivise tra `gen_ini.py` e `GCal.lua` (vedi i commenti in testa a
  entrambi): se cambi una, cambia anche l'altra.
