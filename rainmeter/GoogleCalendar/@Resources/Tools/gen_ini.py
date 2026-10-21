# Genera GoogleCalendar.ini: le pool di meter (42 celle, 120 barre, righe del
# pannello) sono troppo ripetitive da scrivere a mano, e generarle evita errori
# di copia-incolla nelle coordinate.
# Uso (da questa cartella): python gen_ini.py ..\..\GoogleCalendar.ini
# Il file viene scritto in ASCII: le icone usano i riferimenti [\xE76B] di
# Rainmeter, quindi non serve salvare il .ini in UTF-16.
import sys

# Dimensioni delle pool: devono coincidere con MAX_DAYS, MAX_BARS, GRID_LINES,
# DAY_ROWS e BUTTONS in Scripts\GCal.lua (42 = 6 settimane, il massimo di un mese).
DAYS, BARS, GRID_LINES, DAY_ROWS, BUTTONS = 42, 120, 13, 8, 3

# Geometria del pannello in sovrimpressione (giorno / dettaglio / nuovo).
# Deve coincidere con PANEL_Y, PANEL_IX, ROW_Y0, ROW_H, BTN_Y in GCal.lua.
PY = 86            # bordo superiore del pannello = GRID_TOP - 4
IX = 24            # margine interno sinistro (PAD 10 + 14)
INNER_W = '(#Width#-48)'
ROW_Y0, ROW_H = PY + 52, 30
BTN_Y, BTN_H, BTN_GAP = PY + 336, 34, 8
HALF_W = 136       # campi affiancati (Data/Tutto il giorno, Inizio/Fine)
COL2_X = IX + 146

out = []
w = out.append


def lua(call):
    """Azione che chiama una funzione di GCal.lua."""
    return f'[!CommandMeasure MeasureScript "{call}"]'


def text_meter(name, x, y, extra='', groups='Panel', style='StyleText'):
    # Text= vuoto solo se extra non ne porta gia' uno: con due chiavi uguali
    # Rainmeter usa la prima, e l'etichetta resterebbe vuota.
    text = '' if 'Text=' in extra else 'Text=\n'
    w(f"[{name}]\nMeter=String\nMeterStyle={style}\nX={x}\nY={y}\n{text}Hidden=1\nGroup={groups}\n{extra}\n")


def field(name, label, label_text, x, y, width, groups, action):
    """Etichetta + riquadro arrotondato + testo cliccabile di un campo del modulo."""
    text_meter(label, x, y - 16, f"FontSize=8\nFontColor=#ColorDim#\nText={label_text}\n", groups)
    w(f"[{name}Bg]\nMeter=Shape\nX={x}\nY={y}\nShape=Rectangle 0,0,{width},30,8 | Fill Color #ColorField# | StrokeWidth 0\n"
      f"Hidden=1\nGroup={groups}\nLeftMouseUpAction={action}\n\n")
    tw = width if isinstance(width, int) else f"({width[1:-1]})"
    w(f"[{name}]\nMeter=String\nMeterStyle=StyleText\nX={x + 10}\nY={y + 6}\nW=({tw}-20)\nH=18\nClipString=1\nFontSize=10\n"
      f"Text=\nHidden=1\nGroup={groups}\nSolidColor=0,0,0,1\nLeftMouseUpAction={action}\n\n")


def input_measure(name, field_name, x, y, width):
    """Casella InputText sovrapposta al campo. Il testo si legge dal valore del
    measure (non da $UserInput$ dentro un bang) cosi' virgolette e simboli nel
    titolo non rompono l'azione; !SetVariable serve solo a DefaultValue."""
    var = 'Form' + field_name.capitalize()
    w(f"""[{name}]
Measure=Plugin
Plugin=InputText
X={x + 4}
Y={y + 3}
W={width}
H=24
SolidColor=#ColorFieldInput#
FontColor=#ColorText#
FontFace=#FontFace#
FontSize=10
FocusDismiss=1
DefaultValue=#{var}#
DynamicVariables=1
Command1=[!SetVariable {var} \"\"\"$UserInput$\"\"\"]{lua(f"OnInput('{field_name}')")}

""")


w(r"""; Google Calendar per Rainmeter - vista mensile con eventi e attivita'.
; File generato da @Resources\Tools\gen_ini.py: modificare il generatore, non questo file.
; Le sezioni ripetute (celle, barre, righe del pannello) sono pool di meter che
; GCal.lua posiziona e mostra/nasconde. Impostazioni in @Resources\Variables.inc.
; I dati arrivano dalle API Google tramite Scripts\gcal.ps1 (vedi Google\LEGGIMI.txt).

[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1
ContextTitle=Aggiorna ora
ContextAction=[!CommandMeasure MeasureScript "RefreshAll()"]
ContextTitle2=Apri Google Calendar
ContextAction2=["https://calendar.google.com"]
ContextTitle3=Collega / ricollega account Google
ContextAction3=[!CommandMeasure MeasureScript "Login()"]
ContextTitle4=Modifica impostazioni
ContextAction4=["#@#Variables.inc"]

[Metadata]
Name=Google Calendar
Information=Vista mensile di Google Calendar e Google Tasks: legge, crea, completa ed elimina eventi e attivita'. Guida in @Resources\Google\LEGGIMI.txt.
Version=3.0
License=MIT

@Include=#@#Variables.inc

; ---------------------------------------------------------------- Measures --

; UpdateDivider=30: ogni 30 s lo script controlla cambio giorno e scadenza
; dell'aggiornamento automatico; ridisegna solo se serve.
[MeasureScript]
Measure=Script
ScriptFile=#@#Scripts\GCal.lua
UpdateDivider=30

; Lancia gcal.ps1 senza finestra. La richiesta passa da un file (vedi gcal.ps1),
; quindi Parameter e' fisso. La coppia di virgolette esterna serve perche'
; Rainmeter toglie una coppia di virgolette agli estremi delle opzioni: senza,
; perderebbe quelle che chiudono il percorso di request.txt.
[MeasureRun]
Measure=Plugin
Plugin=RunCommand
Program=powershell.exe
Parameter="-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "#@#Scripts\gcal.ps1" -RequestFile "#@#Google\request.txt""
State=Hide
OutputType=UTF8
FinishAction=[!CommandMeasure MeasureScript "OnRunFinished()"]

""")
input_measure('InputTitle', 'title', IX, PY + 108, '(#Width#-56)')
input_measure('InputDate', 'date', IX, PY + 164, HALF_W - 8)
input_measure('InputStart', 'start', IX, PY + 220, HALF_W - 8)
input_measure('InputEnd', 'end', COL2_X, PY + 220, HALF_W - 8)

w(r"""; ------------------------------------------------------------------ Styles --

[StyleText]
FontFace=#FontFace#
AntiAlias=1
FontColor=#ColorText#

[StyleIcon]
FontFace=Segoe MDL2 Assets
AntiAlias=1
StringAlign=CenterCenter

; Cella cliccabile: SolidColor con alpha 1 perche' un'area del tutto trasparente
; non riceve i clic. Al passaggio del mouse si schiarisce leggermente.
[StyleHover]
SolidColor=0,0,0,1
MouseOverAction=[!SetOption #CURRENTSECTION# SolidColor 255,255,255,10][!UpdateMeter #CURRENTSECTION#][!Redraw]
MouseLeaveAction=[!SetOption #CURRENTSECTION# SolidColor 0,0,0,1][!UpdateMeter #CURRENTSECTION#][!Redraw]

[StyleDayNum]
FontSize=9
StringAlign=CenterCenter
Hidden=1

[StyleBarText]
FontSize=8
ClipString=1
SolidColor=0,0,0,1
Hidden=1

; ------------------------------------------------------------------ Meters --

[MeterBackground]
Meter=Shape
Shape=Rectangle 0,0,#Width#,#BgHeight#,22 | Fill Color #ColorBg# | StrokeWidth 0
DynamicVariables=1

; Intestazione: mese (clic = torna a oggi), frecce, pulsante "+" (nuovo elemento).
[MeterMonth]
Meter=String
MeterStyle=StyleText
X=20
Y=22
FontSize=15
Text=
ToolTipText=Torna al mese corrente
LeftMouseUpAction=[!CommandMeasure MeasureScript "Nav(0)"]

[MeterPrev]
Meter=String
MeterStyle=StyleIcon
X=(#Width#-138)
Y=36
FontSize=13
FontColor=#ColorText#
Padding=10,10,10,10
SolidColor=0,0,0,1
Text=[\xE76B]
ToolTipText=Mese precedente
LeftMouseUpAction=[!CommandMeasure MeasureScript "Nav(-1)"]

[MeterNext]
Meter=String
MeterStyle=StyleIcon
X=(#Width#-92)
Y=36
FontSize=13
FontColor=#ColorText#
Padding=10,10,10,10
SolidColor=0,0,0,1
Text=[\xE76C]
ToolTipText=Mese successivo
LeftMouseUpAction=[!CommandMeasure MeasureScript "Nav(1)"]

[MeterAddBg]
Meter=Shape
Shape=Rectangle (#Width#-62),12,48,48,14 | Fill Color #ColorButton# | StrokeWidth 0
LeftMouseUpAction=[!CommandMeasure MeasureScript "NewForm()"]
ToolTipText=Nuovo evento o attivita'

[MeterAddIcon]
Meter=String
MeterStyle=StyleIcon
X=(#Width#-38)
Y=36
FontSize=16
FontColor=#ColorTodayText#
Text=[\xE710]
LeftMouseUpAction=[!CommandMeasure MeasureScript "NewForm()"]

""")
for i in range(1, 8):
    w(f"[Wd{i}]\nMeter=String\nMeterStyle=StyleText\nFontSize=8\nFontColor=#ColorDim#\nStringAlign=Center\nY=74\nText=\n\n")

w("; Griglia: 6 linee verticali + fino a 7 orizzontali, coordinate impostate dallo script.\n")
w("; Tutte le ShapeN devono esistere gia' qui: il meter Shape legge Shape, Shape2, ... in sequenza.\n")
w("[MeterGrid]\nMeter=Shape\n")
for i in range(1, GRID_LINES + 1):
    w(f"Shape{'' if i == 1 else i}=Line 0,0,0,0 | StrokeWidth 0\n")
w("\n")
for i in range(1, DAYS + 1):
    w(f"[DayHit{i}]\nMeter=String\nMeterStyle=StyleHover\nHidden=1\n\n")
w("""; Cerchio evidenziato sotto il numero del giorno di oggi. Centro in (11,11) = raggio
; (TODAY_R in GCal.lua): lo script posiziona il meter a centro - raggio.
[MeterToday]
Meter=Shape
Shape=Ellipse 11,11,11 | Fill Color #ColorAccent# | StrokeWidth 0
Hidden=1

""")
for i in range(1, DAYS + 1):
    w(f"[DayNum{i}]\nMeter=String\nMeterStyle=StyleText | StyleDayNum\nText=\n\n")
w("; Sfondi arrotondati delle barre evento: un solo meter Shape con 120 forme.\n[MeterBarShapes]\nMeter=Shape\n")
for i in range(1, BARS + 1):
    w(f"Shape{'' if i == 1 else i}=Rectangle 0,0,0,0 | StrokeWidth 0 | Fill Color 0,0,0,0\n")
w("\n")
for i in range(1, BARS + 1):
    w(f"[BarText{i}]\nMeter=String\nMeterStyle=StyleText | StyleBarText\nText=\n\n")

w(r"""; Piede: pulsante di aggiornamento manuale + stato (cliccabile quando serve il login).
[MeterRefresh]
Meter=String
MeterStyle=StyleText
X=18
Y=0
FontSize=9
FontColor=#ColorAccent#
SolidColor=0,0,0,1
Padding=4,4,8,4
InlineSetting=Face | Segoe MDL2 Assets
InlinePattern=^(.)
Text=[\xE72C]  Aggiorna
ToolTipText=Riscarica ora calendari e attivita'
LeftMouseUpAction=[!CommandMeasure MeasureScript "RefreshAll()"]

[MeterStatus]
Meter=String
MeterStyle=StyleText
X=(#Width#-20)
Y=0
W=(#Width#-150)
ClipString=1
FontSize=8
FontColor=#ColorDim#
StringAlign=Right
SolidColor=0,0,0,1
Text=Caricamento...

; ------------------------------------------------------------------- Panel --
; Pannello in sovrimpressione sulla griglia. Gruppi: Panel (tutto), PDay (elenco
; del giorno), PDetail (dettaglio elemento), PForm (nuovo), PFormTime (Inizio/Fine,
; nascosti per "tutto il giorno" e per le attivita'). Sta dopo la griglia nel file,
; quindi e' disegnato sopra e riceve i clic al suo posto.

; L'azione vuota (Noop) fa si' che lo sfondo intercetti i clic: senza, passerebbero
; alle celle della griglia nascoste sotto.
[PanelBg]
Meter=Shape
Shape=Rectangle 0,0,0,0 | StrokeWidth 0
Hidden=1
Group=Panel
LeftMouseUpAction=[!CommandMeasure MeasureScript "Noop()"]

""")
text_meter('PanelTitle', IX, PY + 14, 'W=(#Width#-90)\nH=44\nClipString=2\nFontSize=13\n')
w(f"""[PanelClose]
Meter=String
MeterStyle=StyleIcon
X=(#Width#-34)
Y={PY + 26}
FontSize=11
FontColor=#ColorDim#
Padding=8,8,8,8
SolidColor=0,0,0,1
Text=[\\xE711]
ToolTipText=Chiudi
Hidden=1
Group=Panel
LeftMouseUpAction={lua('ClosePanel()')}

""")

# --- elenco del giorno
w("; Pallini colorati delle righe: un solo meter Shape, una forma per riga.\n[DayRowDots]\nMeter=Shape\nHidden=1\nGroup=Panel | PDay\n")
for i in range(1, DAY_ROWS + 1):
    w(f"Shape{'' if i == 1 else i}=Ellipse 0,0,0 | StrokeWidth 0\n")
w("\n")
for i in range(1, DAY_ROWS + 1):
    y = ROW_Y0 + (i - 1) * ROW_H
    w(f"[DayRowHit{i}]\nMeter=String\nMeterStyle=StyleHover\nX={IX - 6}\nY={y}\nW=(#Width#-36)\nH={ROW_H - 2}\n"
      f"Hidden=1\nGroup=Panel | PDay\nLeftMouseUpAction={lua(f'OpenDayRow({i})')}\n\n")
    text_meter(f'DayRowTime{i}', IX + 16, y + 6, 'W=84\nH=18\nClipString=1\nFontSize=9\nFontColor=#ColorDim#\n', 'Panel | PDay')
    text_meter(f'DayRowTitle{i}', IX + 104, y + 5, 'W=(#Width#-138)\nH=20\nClipString=1\nFontSize=10\n', 'Panel | PDay')
text_meter('DayEmpty', IX, ROW_Y0 + 6, 'FontSize=10\nFontColor=#ColorDim#\n', 'Panel | PDay')

# --- dettaglio
text_meter('DetWhen', IX, PY + 66, 'W=(#Width#-48)\nH=40\nClipString=2\nFontSize=10\nFontColor=#ColorDim#\n', 'Panel | PDetail')
w(f"[DetDot]\nMeter=Shape\nX={IX}\nY={PY + 112}\nShape=Ellipse 5,5,5 | StrokeWidth 0\nHidden=1\nGroup=Panel | PDetail\n\n")
text_meter('DetCal', IX + 16, PY + 106, 'W=(#Width#-64)\nH=20\nClipString=1\nFontSize=10\n', 'Panel | PDetail')
text_meter('DetInfo', IX, PY + 140, 'W=(#Width#-48)\nH=60\nClipString=2\nFontSize=9\nFontColor=#ColorDim#\n', 'Panel | PDetail')

# --- modulo "nuovo"
for name, label, x, wdt in (('ChipEvent', 'Evento', IX, 84), ('ChipTask', "Attivit[\\x00E0]", IX + 92, 96)):
    act = lua(f"SetType('{'event' if name == 'ChipEvent' else 'task'}')")
    w(f"[{name}Bg]\nMeter=Shape\nX={x}\nY={PY + 52}\nShape=Rectangle 0,0,{wdt},28,14 | StrokeWidth 0\n"
      f"Hidden=1\nGroup=Panel | PForm\nLeftMouseUpAction={act}\n\n")
    w(f"[{name}]\nMeter=String\nMeterStyle=StyleText\nX={x + wdt // 2}\nY={PY + 66}\nStringAlign=CenterCenter\nFontSize=9\n"
      f"Text={label}\nHidden=1\nGroup=Panel | PForm\nLeftMouseUpAction={act}\n\n")
field('FieldTitle', 'LblTitle', 'Titolo', IX, PY + 108, INNER_W, 'Panel | PForm', lua("Edit('title')"))
field('FieldDate', 'LblDate', 'Data (gg/mm/aaaa)', IX, PY + 164, HALF_W, 'Panel | PForm', lua("Edit('date')"))
w(f"[ChipAllDayBg]\nMeter=Shape\nX={COL2_X}\nY={PY + 164}\nShape=Rectangle 0,0,{HALF_W},30,8 | StrokeWidth 0\n"
  f"Hidden=1\nGroup=Panel | PForm\nLeftMouseUpAction={lua('ToggleAllDay()')}\n\n")
w(f"[ChipAllDay]\nMeter=String\nMeterStyle=StyleText\nX={COL2_X + HALF_W // 2}\nY={PY + 179}\nStringAlign=CenterCenter\nFontSize=9\n"
  f"Text=Tutto il giorno\nHidden=1\nGroup=Panel | PForm\nLeftMouseUpAction={lua('ToggleAllDay()')}\n\n")
field('FieldStart', 'LblStart', 'Inizio', IX, PY + 220, HALF_W, 'Panel | PForm | PFormTime', lua("Edit('start')"))
field('FieldEnd', 'LblEnd', 'Fine', COL2_X, PY + 220, HALF_W, 'Panel | PForm | PFormTime', lua("Edit('end')"))
field('FieldCal', 'LblCal', 'Calendario', IX, PY + 276, INNER_W, 'Panel | PForm', lua('CycleTarget()'))
w(f"[FieldCalDot]\nMeter=Shape\nX=(#Width#-46)\nY={PY + 286}\nShape=Ellipse 5,5,5 | StrokeWidth 0\nHidden=1\nGroup=Panel | PForm\n"
  f"LeftMouseUpAction={lua('CycleTarget()')}\n\n")
text_meter('FormError', IX, PY + 312, 'W=(#Width#-48)\nH=18\nClipString=1\nFontSize=9\nFontColor=#ColorDanger#\n', 'Panel | PForm')

# --- pulsanti in basso, condivisi dai tre pannelli: testo, colore e azione li
# decide lo script (Btn(i) richiama il gestore registrato in Lua).
for i in range(1, BUTTONS + 1):
    x = f"({IX}+({i - 1})*(({INNER_W[1:-1]}-{2 * BTN_GAP})/3+{BTN_GAP}))"
    bw = f"(({INNER_W[1:-1]}-{2 * BTN_GAP})/3)"
    w(f"[BtnBg{i}]\nMeter=Shape\nX={x}\nY={BTN_Y}\nShape=Rectangle 0,0,{bw},{BTN_H},10 | StrokeWidth 0\n"
      f"Hidden=1\nGroup=Panel\nLeftMouseUpAction={lua(f'Btn({i})')}\n\n")
    w(f"[BtnText{i}]\nMeter=String\nMeterStyle=StyleText\nX=({x}+{bw}/2)\nY={BTN_Y + BTN_H // 2}\nStringAlign=CenterCenter\n"
      f"FontSize=9\nText=\nHidden=1\nGroup=Panel\nLeftMouseUpAction={lua(f'Btn({i})')}\n\n")

open(sys.argv[1], 'w', encoding='ascii', newline='\r\n').write(''.join(out))
