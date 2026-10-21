[Variables]
; ---------------------------------------------------------------------------
; Rainmeter Calendar settings. After editing: right-click the widget >
; "Refresh skin". First-time setup: README.md in the repository.
; The widget shows the calendars ticked under "My calendars" / "Other calendars"
; on calendar.google.com, with their colours: there are no URLs to paste.
; ---------------------------------------------------------------------------

; Interface language: file @Resources\Lang\<Language>.inc (en, it).
Language=en

; Seconds between automatic syncs (minimum 60). Each sync costs about
; 3 + calendars + task lists API requests: see "API usage limits" in the README.
RefreshSeconds=60
; First day of the week: 1 = Monday, 0 = Sunday.
WeekStart=1

; Size (pixels). The total height depends on how many weeks the month spans.
Width=380
CellHeight=88

; Appearance
FontFace=Segoe UI
ColorBg=38,42,64,235
ColorGrid=255,255,255,22
ColorText=236,236,242,255
ColorDim=150,152,170,255
ColorOtherMonth=110,112,130,255
ColorAccent=168,199,250,255
ColorTodayText=20,24,40,255
ColorButton=219,231,255,255
; Panels (day, details, new) and form fields
ColorPanel=30,33,52,250
ColorField=255,255,255,22
; Background of the text boxes: InputText applies the alpha to the whole box,
; so this must be an opaque colour.
ColorFieldInput=50,54,78,255
ColorDanger=214,80,80,255
; --- Colours as on Google Calendar (values taken from the website, dark theme) ---
; Google's API returns colours from the old palette, lighter than what the
; website shows. ColorMap converts them: "API colour=wanted colour", separated
; by ";". An API colour can be found in the C/E rows of Google\data.tsv.
; ColorMap is for bars (all-day or multi-day events); ColorMapTimed is for the
; dot of timed events, which the website paints with a different shade. A colour
; missing from ColorMapTimed falls back to ColorMap.
;   146,225,192 = Google's "Sage" calendar colour -> light green bars / teal dot
;    22,167,101 = Google's "Basil" (e.g. holidays) -> dark green
ColorMap=146,225,192=133,173,89;22,167,101=72,145,96
ColorMapTimed=146,225,192=85,176,128
; Birthdays (events of type "birthday"): Google colours them separately
ColorBirthday=133,173,89
; Tasks (Google Tasks): to do / completed
ColorTask=102,139,225
ColorTaskDone=102,139,225,110

; --- Internal values managed by the script: do not edit. ---
BgHeight=600
FormTitle=
FormDate=
FormStart=
FormEnd=
