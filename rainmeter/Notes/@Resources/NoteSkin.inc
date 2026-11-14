; Sticky note - shared skin body. Every Notes\NoteNN\Note.ini only includes this
; file: Rainmeter needs one config (folder) per independent window, so 12 slots
; exist; "+" and the side menu activate them. The slot number comes from
; #CURRENTCONFIG#, so all slots share exactly the same code (Scripts\Notes.lua).
; Each note is the file @Resources\Notes\<title>.txt; the title row renames it.
; Editing happens in Scripts\NoteEditor.ps1, a borderless window laid over the
; title or the text. Edges and corners resize the window (Resize.inc +
; Scripts\Resize.ps1).

[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1
ContextTitle=#TxtNewNote#
ContextAction=[!CommandMeasure MeasureScript "NewNote()"]
ContextTitle2=#TxtOpenFolder#
ContextAction2=["#@#Notes"]
ContextTitle3=#TxtSettings#
ContextAction3=["#@#Variables.inc"]

[Metadata]
Name=Sticky Notes
Information=Sticky notes saved as plain text files @Resources\Notes\<title>.txt. Click the title to rename, the text to write; saved automatically.
Version=3.0
License=MIT

@Include=#@#Variables.inc
@Include2=#@#Lang\#Language#.inc

[Variables]
BarH=30
Pad=12
MenuW=210
; Title row under the bar (height, font size) and where the text starts
; (BodyTop = BarH + TitleH + 10; Notes.lua also uses it to place the editor).
TitleH=26
TitleSize=11
BodyTop=66
; Set by the script at load: the slot name (Note01...), used in the editor
; request path, and the full path of the note file shown in this window.
NoteId=Note01
NotePath=

; ---------------------------------------------------------------- Measures --

; Update every second: the script redraws only when something changed (notes
; opened/closed elsewhere, a temporary message expired, new text).
[MeasureScript]
Measure=Script
ScriptFile=#@#Scripts\Notes.lua
UpdateDivider=1

; Reads the note file. WebParser is used instead of Lua's io library because
; it opens files with Unicode names (titles with accented letters); Lua does
; not. Re-read every 2 s (UpdateRate=2 at Update=1000) so the note follows
; edits made with any program; ForceReload avoids a cached copy. The RegExp
; captures the whole file; (.*) rather than (.+) so that an empty note is not a
; matching error. The error actions cover a file renamed or deleted outside the skin.
[MeasureNoteText]
Measure=WebParser
URL=file://#NotePath#
RegExp=(?s)^(.*)$
StringIndex=1
CodePage=65001
UpdateRate=2
ForceReload=1
DynamicVariables=1
FinishAction=[!CommandMeasure MeasureScript "OnTextLoaded()"]
OnConnectErrorAction=[!CommandMeasure MeasureScript "OnTextMissing()"]
OnRegExpErrorAction=[!CommandMeasure MeasureScript "OnTextMissing()"]

; List of the notes for the side menu, most recently modified first (FileView
; also handles Unicode names). Only .txt files, so the editor's short-lived
; .tmp files never appear. The script asks for a rescan every 2 s while the
; menu is open; one child measure per menu row.
[MeasureNotesFolder]
Measure=Plugin
Plugin=FileView
Path=#@#Notes\
Extensions=txt
ShowDotDot=0
ShowFolder=0
SortType=Date
SortDateType=Modified
SortAscending=0
Count=12
FinishAction=[!CommandMeasure MeasureScript "OnFolderScanned()"]

[MeasureNoteFile1]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=1
[MeasureNoteFile2]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=2
[MeasureNoteFile3]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=3
[MeasureNoteFile4]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=4
[MeasureNoteFile5]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=5
[MeasureNoteFile6]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=6
[MeasureNoteFile7]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=7
[MeasureNoteFile8]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=8
[MeasureNoteFile9]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=9
[MeasureNoteFile10]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=10
[MeasureNoteFile11]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=11
[MeasureNoteFile12]
Measure=Plugin
Plugin=FileView
Path=[MeasureNotesFolder]
Type=FileName
Index=12

; Starts the editor without a console window. The request goes through a file
; (written by Notes.lua) so that paths, fonts and colours never need quoting on
; the command line. The outer pair of quotes is there because Rainmeter strips
; one pair from the ends of an option value. FinishAction runs when the editor
; window is closed.
[MeasureEditor]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter="-NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "#@#Scripts\NoteEditor.ps1" -Request "#@#Data\#NoteId#.edit""
State=Hide
DynamicVariables=1
FinishAction=[!CommandMeasure MeasureScript "OnEditorClosed()"]

; Resize helper (Scripts\Resize.ps1), started by the handles of Resize.inc.
; Separate from MeasureEditor so the two can never block each other.
[MeasureResize]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter="-NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "#@#Scripts\Resize.ps1" -Request "#@#Data\#NoteId#.resize""
State=Hide
DynamicVariables=1
FinishAction=[!CommandMeasure MeasureScript "OnResized()"]

; ------------------------------------------------------------------ Styles --

[StyleIcon]
FontFace=Segoe MDL2 Assets
FontSize=10
FontColor=#ColorText#
AntiAlias=1
StringAlign=CenterCenter
SolidColor=0,0,0,1
Padding=6,6,6,6

[StyleMenuText]
FontFace=#FontFace#
AntiAlias=1
ClipString=1
Hidden=1
Group=Menu

; ------------------------------------------------------------------ Meters --

; Note body, the slightly darker top bar (both colours set by the script) and
; a thin line between the title and the text.
[MeterBg]
Meter=Shape
Shape=Rectangle 0,0,#NoteWidth#,#NoteHeight#,8 | Fill Color #NoteColor# | StrokeWidth 0
Shape2=Rectangle 0,0,#NoteWidth#,#BarH#,8 | Fill Color #NoteBarColor# | StrokeWidth 0
Shape3=Rectangle 0,(#BarH#-8),#NoteWidth#,8 | Fill Color #NoteBarColor# | StrokeWidth 0
Shape4=Rectangle #Pad#,(#BarH#+#TitleH#+5),(#NoteWidth#-2*#Pad#),1 | Fill Color 0,0,0,45 | StrokeWidth 0
DynamicVariables=1

; Left of the bar: menu (list of notes) and new note.
[MeterMenu]
Meter=String
MeterStyle=StyleIcon
X=16
Y=(#BarH#/2)
Text=[\xE700]
ToolTipText=#TxtMenu#
LeftMouseUpAction=[!CommandMeasure MeasureScript "ToggleMenu()"]

[MeterNew]
Meter=String
MeterStyle=StyleIcon
X=42
Y=(#BarH#/2)
Text=[\xE710]
ToolTipText=#TxtNewNote#
LeftMouseUpAction=[!CommandMeasure MeasureScript "NewNote()"]

; Right of the bar: save (only while editing), colour, delete, close (hidden
; when this is the only open note). The script sets their X so that no gap is
; left where a hidden button would be.
[MeterSave]
Meter=String
MeterStyle=StyleIcon
X=0
Y=(#BarH#/2)
Text=[\xE74E]
ToolTipText=#TxtSave#
Hidden=1
LeftMouseUpAction=[!CommandMeasure MeasureScript "SaveEdit()"]

[MeterColor]
Meter=String
MeterStyle=StyleIcon
X=0
Y=(#BarH#/2)
Text=[\xE790]
ToolTipText=#TxtColor#
LeftMouseUpAction=[!CommandMeasure MeasureScript "CycleColor()"]

[MeterTrash]
Meter=String
MeterStyle=StyleIcon
X=0
Y=(#BarH#/2)
Text=[\xE74D]
ToolTipText=#TxtDelete#
LeftMouseUpAction=[!CommandMeasure MeasureScript "DeleteNote()"]

[MeterClose]
Meter=String
MeterStyle=StyleIcon
X=0
Y=(#BarH#/2)
Text=[\xE711]
ToolTipText=#TxtClose#
LeftMouseUpAction=[!CommandMeasure MeasureScript "CloseNote()"]

; The title = the note's file name. Clicking it opens a one-line editor; the
; file is renamed when the editor closes.
[MeterTitle]
Meter=String
X=#Pad#
Y=(#BarH#+6)
W=(#NoteWidth#-2*#Pad#)
H=#TitleH#
ClipString=1
FontFace=#FontFace#
FontSize=#TitleSize#
FontWeight=700
FontColor=#ColorText#
AntiAlias=1
SolidColor=0,0,0,1
Text=
ToolTipText=#TxtTitle#
LeftMouseUpAction=[!CommandMeasure MeasureScript "EditTitle()"]

; The note text. Clicking anywhere on it opens the editor. SolidColor alpha 1
; makes the empty area clickable too.
[MeterText]
Meter=String
X=#Pad#
Y=#BodyTop#
W=(#NoteWidth#-2*#Pad#)
H=(#NoteHeight#-#BodyTop#-#Pad#)
ClipString=2
FontFace=#FontFace#
FontSize=#FontSize#
FontColor=#ColorText#
AntiAlias=1
SolidColor=0,0,0,1
Text=
LeftMouseUpAction=[!CommandMeasure MeasureScript "Edit()"]

; ------------------------------------------------------------- Side menu --
; Panel to the right of the note listing the 12 most recently modified notes
; (one row per FileView child measure). The window grows to show it
; (DynamicWindowSize) and shrinks back when it is closed.

[MenuBg]
Meter=Shape
X=(#NoteWidth#+6)
Y=0
Shape=Rectangle 0,0,#MenuW#,100,8 | Fill Color 250,250,250,245 | StrokeWidth 1 | Stroke Color 0,0,0,40
Hidden=1
Group=Menu

[MenuTitle]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+18)
Y=8
W=(#MenuW#-24)
FontSize=10
FontWeight=600
FontColor=#ColorText#
Text=#TxtMenuTitle#

[MenuDots]
Meter=Shape
X=(#NoteWidth#+6)
Y=0
Hidden=1
Group=Menu
Shape=Ellipse 0,0,0 | StrokeWidth 0
Shape2=Ellipse 0,0,0 | StrokeWidth 0
Shape3=Ellipse 0,0,0 | StrokeWidth 0
Shape4=Ellipse 0,0,0 | StrokeWidth 0
Shape5=Ellipse 0,0,0 | StrokeWidth 0
Shape6=Ellipse 0,0,0 | StrokeWidth 0
Shape7=Ellipse 0,0,0 | StrokeWidth 0
Shape8=Ellipse 0,0,0 | StrokeWidth 0
Shape9=Ellipse 0,0,0 | StrokeWidth 0
Shape10=Ellipse 0,0,0 | StrokeWidth 0
Shape11=Ellipse 0,0,0 | StrokeWidth 0
Shape12=Ellipse 0,0,0 | StrokeWidth 0

[MenuRow1]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=36
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(1)"]
Text=

[MenuTitle1]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=38
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub1]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=54
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow2]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=72
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(2)"]
Text=

[MenuTitle2]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=74
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub2]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=90
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow3]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=108
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(3)"]
Text=

[MenuTitle3]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=110
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub3]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=126
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow4]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=144
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(4)"]
Text=

[MenuTitle4]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=146
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub4]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=162
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow5]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=180
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(5)"]
Text=

[MenuTitle5]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=182
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub5]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=198
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow6]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=216
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(6)"]
Text=

[MenuTitle6]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=218
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub6]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=234
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow7]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=252
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(7)"]
Text=

[MenuTitle7]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=254
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub7]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=270
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow8]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=288
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(8)"]
Text=

[MenuTitle8]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=290
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub8]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=306
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow9]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=324
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(9)"]
Text=

[MenuTitle9]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=326
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub9]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=342
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow10]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=360
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(10)"]
Text=

[MenuTitle10]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=362
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub10]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=378
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow11]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=396
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(11)"]
Text=

[MenuTitle11]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=398
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub11]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=414
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=

[MenuRow12]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+12)
Y=432
W=(#MenuW#-12)
H=34
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,18][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]
LeftMouseUpAction=[!CommandMeasure MeasureScript "OpenNote(12)"]
Text=

[MenuTitle12]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=434
W=(#MenuW#-40)
FontSize=9
FontColor=#ColorText#
Text=

[MenuSub12]
Meter=String
MeterStyle=StyleMenuText
X=(#NoteWidth#+30)
Y=450
W=(#MenuW#-40)
FontSize=8
FontColor=#ColorPlaceholder#
Text=


; ------------------------------------------------------- Resize handles --
; Last in the file so they sit on top of every other meter (see Resize.inc).
; @Include must sit in a section; this one holds nothing else (no Meter=, so
; Rainmeter treats it like a style section and ignores it).
[ResizeHandles]
@Include4=#@#Resize.inc
