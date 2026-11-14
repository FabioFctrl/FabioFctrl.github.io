; Resize handles: invisible strips along the edges and squares in the corners
; that show the Windows resize cursors and start Scripts\Resize.ps1 when pressed
; (through the skin script's StartResize). Include this file AFTER all other
; meters: later meters are drawn on top and receive the mouse first.
; The skin script keeps ResizeW / ResizeH equal to the skin's size (that is why
; DynamicVariables=1). SolidColor alpha 1 makes the transparent strips clickable.
; ResizeGrip = edge thickness, ResizeCorner = corner square: small enough not
; to cover the skin's own buttons, big enough to hit without aiming.

[Variables]
ResizeW=200
ResizeH=200
ResizeGrip=5
ResizeCorner=12

[ResizeL]
Meter=Image
X=0
Y=#ResizeCorner#
W=#ResizeGrip#
H=(#ResizeH#-2*#ResizeCorner#)
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_WE
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('l')"]

[ResizeR]
Meter=Image
X=(#ResizeW#-#ResizeGrip#)
Y=#ResizeCorner#
W=#ResizeGrip#
H=(#ResizeH#-2*#ResizeCorner#)
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_WE
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('r')"]

[ResizeT]
Meter=Image
X=#ResizeCorner#
Y=0
W=(#ResizeW#-2*#ResizeCorner#)
H=#ResizeGrip#
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_NS
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('t')"]

[ResizeB]
Meter=Image
X=#ResizeCorner#
Y=(#ResizeH#-#ResizeGrip#)
W=(#ResizeW#-2*#ResizeCorner#)
H=#ResizeGrip#
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_NS
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('b')"]

[ResizeTL]
Meter=Image
X=0
Y=0
W=#ResizeCorner#
H=#ResizeCorner#
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_NWSE
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('tl')"]

[ResizeTR]
Meter=Image
X=(#ResizeW#-#ResizeCorner#)
Y=0
W=#ResizeCorner#
H=#ResizeCorner#
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_NESW
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('tr')"]

[ResizeBL]
Meter=Image
X=0
Y=(#ResizeH#-#ResizeCorner#)
W=#ResizeCorner#
H=#ResizeCorner#
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_NESW
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('bl')"]

[ResizeBR]
Meter=Image
X=(#ResizeW#-#ResizeCorner#)
Y=(#ResizeH#-#ResizeCorner#)
W=#ResizeCorner#
H=#ResizeCorner#
SolidColor=0,0,0,1
DynamicVariables=1
MouseActionCursorName=SIZE_NWSE
LeftMouseDownAction=[!CommandMeasure MeasureScript "StartResize('br')"]
