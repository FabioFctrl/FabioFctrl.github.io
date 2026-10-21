[Variables]
; ---------------------------------------------------------------------------
; Il widget legge e scrive tramite le API Google (calendari + attivita').
; Configurazione iniziale: vedi @Resources\Google\LEGGIMI.txt.
; Vengono mostrati i calendari spuntati in "I miei calendari" / "Altri calendari"
; su calendar.google.com, con i loro colori: niente URL da incollare.
; Dopo aver modificato questo file: tasto destro sul widget > Aggiorna skin.
; ---------------------------------------------------------------------------

; Ogni quanti secondi risincronizzare (300 = 5 minuti, minimo 60).
; Ogni sincronizzazione costa ~10 richieste alle API: vedi i limiti in Google\LEGGIMI.txt.
RefreshSeconds=300
; Primo giorno della settimana: 1 = lunedi', 0 = domenica.
WeekStart=1

; Dimensioni (pixel). L'altezza totale dipende da quante settimane ha il mese.
Width=380
CellHeight=88

; Aspetto
FontFace=Segoe UI
ColorBg=38,42,64,235
ColorGrid=255,255,255,22
ColorText=236,236,242,255
ColorDim=150,152,170,255
ColorOtherMonth=110,112,130,255
ColorAccent=168,199,250,255
ColorTodayText=20,24,40,255
ColorButton=219,231,255,255
; Pannelli (giorno, dettaglio, nuovo) e campi del modulo
ColorPanel=30,33,52,250
ColorField=255,255,255,22
; Sfondo delle caselle di testo: InputText applica l'alpha a tutta la casella,
; quindi qui serve un colore pieno.
ColorFieldInput=50,54,78,255
ColorDanger=214,80,80,255
; --- Colori come su Google Calendar (valori presi dal sito, tema scuro) ---
; L'API di Google restituisce i colori della vecchia tavolozza, piu' chiari di
; quelli che vedi sul sito. ColorMap li converte: "colore API=colore voluto",
; separati da ";". Un colore API si trova nelle righe C/E di Google\data.tsv.
; Nel widget ogni elemento e' una barra, quindi si usa il colore delle barre
; "tutto il giorno" del sito (per gli eventi con orario il sito usa un pallino
; di tonalita' diversa).
;   146,225,192 = calendario principale  -> verde delle barre del sito
;    22,167,101 = Festivita' in Italia   -> verde scuro del sito
ColorMap=146,225,192=133,173,89;22,167,101=72,145,96
; Compleanni (eventi di tipo "birthday"): Google li colora a parte
ColorBirthday=133,173,89
; Attivita' (Google Tasks): da fare / completate
ColorTask=102,139,225
ColorTaskDone=102,139,225,110

; --- Valori interni gestiti dallo script: non modificarli. ---
BgHeight=600
FormTitle=
FormDate=
FormStart=
FormEnd=
