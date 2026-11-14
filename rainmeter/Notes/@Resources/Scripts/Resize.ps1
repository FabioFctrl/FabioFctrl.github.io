# Resize.ps1 - resizes a Rainmeter skin by dragging one of its edges or corners.
#
# Rainmeter has no built-in way to resize a skin: it can only move it. The skin
# draws thin "handles" along its edges (Resize.inc) with the Windows resize
# cursors; pressing one starts this script through RunCommand. While the left
# button stays down, a translucent outline follows the mouse; on release the new
# rectangle is written to the result file and the script exits. RunCommand's
# FinishAction then lets the skin's Lua script apply the size (its own variables)
# and refresh once. A live resize of the skin itself would need a refresh per
# mouse move, which makes the skin flicker and lag; the outline does not.
#
# Request file ("key=value" lines):
#   edge   l, r, t, b, tl, tr, bl or br: which side or corner is dragged
#   x, y, w, h   the skin's current rectangle (screen pixels)
#   minw, minh   smallest allowed size
#   out    result file: "x y w h", or no file when cancelled (Esc, no change)
#
# No starting point of the drag is needed: the new edge is simply where the
# mouse is. That matters because PowerShell takes a moment to start, so the
# mouse has usually moved already; a release before the script is ready is
# still handled (the rectangle is computed once from the current position).
#
# Windows PowerShell 5.1 + Windows Forms: both ship with Windows, nothing to install.
# ASCII-only file (PowerShell 5.1 reads .ps1 files without a BOM as ANSI).

param([Parameter(Mandatory = $true)][string]$Request)

$ErrorActionPreference = 'Stop'
$req = @{}
foreach ($line in [IO.File]::ReadAllLines($Request)) {
	$i = $line.IndexOf('=')
	if ($i -gt 0) { $req[$line.Substring(0, $i)] = $line.Substring($i + 1) }
}
$edge = $req.edge
$x0, $y0, $w0, $h0 = [int]$req.x, [int]$req.y, [int]$req.w, [int]$req.h
$minW, $minH = [int]$req.minw, [int]$req.minh
Remove-Item -LiteralPath $req.out -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
# The outline window: shown without taking the focus (the skin keeps it),
# click-through, always on top and absent from the taskbar and Alt+Tab.
# Ex-styles: 0x20 TRANSPARENT, 0x80 TOOLWINDOW, 0x08000000 NOACTIVATE, 0x8 TOPMOST.
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
public class ResizeGhost : System.Windows.Forms.Form {
	protected override bool ShowWithoutActivation { get { return true; } }
	protected override System.Windows.Forms.CreateParams CreateParams {
		get {
			System.Windows.Forms.CreateParams cp = base.CreateParams;
			cp.ExStyle |= 0x20 | 0x80 | 0x08000000 | 0x8;
			return cp;
		}
	}
}
public static class ResizeNative {
	[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
	[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
}
'@
# Rainmeter positions skins in physical pixels; DPI awareness makes the cursor
# position and the outline use the same pixels at any display scaling.
[void][ResizeNative]::SetProcessDPIAware()

# New rectangle for the current mouse position: only the dragged sides move,
# and they stop where the skin would become smaller than its minimum size.
# The edge codes are tested by letter (-match is a substring test), so "br"
# moves both the bottom and the right side.
function Get-Rect {
	$p = [Windows.Forms.Cursor]::Position
	$l, $t, $r, $b = $x0, $y0, ($x0 + $w0), ($y0 + $h0)
	if ($edge -match 'l') { $l = [Math]::Min($p.X, $r - $minW) }
	if ($edge -match 'r') { $r = [Math]::Max($p.X, $l + $minW) }
	if ($edge -match 't') { $t = [Math]::Min($p.Y, $b - $minH) }
	if ($edge -match 'b') { $b = [Math]::Max($p.Y, $t + $minH) }
	return New-Object Drawing.Rectangle($l, $t, ($r - $l), ($b - $t))
}

# Writes the result unless the size barely changed: a plain click on a handle
# (no drag) lands a few pixels inside the edge and must not shrink the skin.
function Save-Rect($rc) {
	if ([Math]::Abs($rc.Width - $w0) -lt 4 -and [Math]::Abs($rc.Height - $h0) -lt 4) { return }
	[IO.File]::WriteAllText($req.out, ('{0} {1} {2} {3}' -f $rc.X, $rc.Y, $rc.Width, $rc.Height))
}

function Test-LeftDown { return ([Windows.Forms.Control]::MouseButtons -band [Windows.Forms.MouseButtons]::Left) -ne 0 }

if (-not (Test-LeftDown)) { Save-Rect (Get-Rect); exit 0 }   # released before the script was ready

$ghost = New-Object ResizeGhost
$ghost.FormBorderStyle = 'None'
$ghost.StartPosition = 'Manual'
$ghost.ShowInTaskbar = $false
$ghost.TopMost = $true
# Light blue at 35 %: reads as a selection rectangle and leaves the skin and
# the desktop visible underneath.
$ghost.BackColor = [Drawing.Color]::FromArgb(100, 150, 255)
$ghost.Opacity = 0.35
$ghost.Bounds = Get-Rect

# 15 ms (about 60 updates per second): smooth to the eye, negligible CPU.
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 15
$timer.Add_Tick({
	if ([ResizeNative]::GetAsyncKeyState(0x1B) -band 0x8000) { $ghost.Close(); return }   # Esc: cancel
	$rc = Get-Rect
	if (-not (Test-LeftDown)) { Save-Rect $rc; $ghost.Close(); return }
	if ($ghost.Bounds -ne $rc) { $ghost.Bounds = $rc }
})
$ghost.Add_Shown({ $timer.Start() })
[Windows.Forms.Application]::Run($ghost)
