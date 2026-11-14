[Variables]
; ---------------------------------------------------------------------------
; Sticky notes settings (shared by every note). After editing: right-click a
; note > "Refresh skin" (or Rainmeter > Refresh all).
; Notes are plain UTF-8 text files @Resources\Notes\<title>.txt (the title row
; of a note renames its file); deleted notes are moved to @Resources\Data\Deleted,
; never erased.
; ---------------------------------------------------------------------------

; Interface language: file @Resources\Lang\<Language>.inc (en, it).
Language=en

; Default size of a note (pixels). Dragging an edge or a corner of a note
; resizes that window only: its size is then kept in its own NoteNN\Note.ini.
NoteWidth=230
NoteHeight=240

; Text
FontFace=Segoe UI
FontSize=10
ColorText=40,40,46,255
ColorPlaceholder=110,110,118,255

; Note colours (R,G,B), cycled with the colour button. Pastel tones so that the
; dark text stays readable on all of them.
NoteColors=255,240,150|200,235,170|175,210,245|250,200,220|255,210,160|215,195,245|232,232,232

; --- Internal values managed by the script: do not edit. ---
NoteColor=255,240,150
NoteBarColor=230,215,120
