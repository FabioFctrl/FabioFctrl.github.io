# NoteEditor.ps1 - file helper and borderless editor for the sticky notes.
#
# Notes are saved as @Resources\Notes\<title>.txt. Rainmeter's Lua cannot open
# or rename files whose names contain accented letters (its io library uses the
# ANSI code page: "caffe" with an accent comes out garbled), so every operation
# that writes, renames or moves a note file is done here. The skin only reads
# the files, through WebParser and FileView, which do handle Unicode names.
#
# The skin (Notes.lua) starts this script through RunCommand with a request
# file ("key=value" lines, UTF-8) and gets RunCommand's FinishAction when it
# exits. Three modes:
#   mode=text    editor laid over the note body (multi-line)
#                  Enter = new line; Ctrl+S, Esc or a click elsewhere = close.
#                  Autosaves 400 ms after each change, so closing never loses
#                  anything; the cursor position is kept in the "caret" file.
#   mode=title   one-line editor laid over the title row. Enter, Esc or a click
#                  elsewhere = close. On close the note file is renamed after
#                  the title and the new name is written to the "slot" file.
#   mode=delete  no window: moves the note text to the "deleted" folder
#                  (timestamped); with keep=1 the note stays, emptied.
# Other keys: file (note path), dir (notes folder), name (current title),
# close (signal file: the note's save button asks the editor to close),
# x, y, w, h, back, fore, font, size, bold (editor geometry and look).
#
# Windows PowerShell 5.1 + Windows Forms: both ship with Windows, nothing to install.
# ASCII-only file (PowerShell 5.1 reads .ps1 files without a BOM as ANSI).

param([Parameter(Mandatory = $true)][string]$Request)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

$req = @{}
foreach ($line in [IO.File]::ReadAllLines($Request, $Utf8NoBom)) {
	$i = $line.IndexOf('=')
	if ($i -gt 0) { $req[$line.Substring(0, $i)] = $line.Substring($i + 1) }
}
$noteFile = $req.file
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($noteFile))   # fresh install: Notes folder may not exist yet

# Moves/renames a file, retrying for up to a second: the skin's WebParser reads
# the note every 2 s, and while it holds the file open Windows refuses to
# replace or rename it ("used by another process").
function Move-WithRetry([string]$from, [string]$to) {
	for ($try = 1; ; $try++) {
		try { Move-Item -LiteralPath $from $to -Force; return }
		catch { if ($try -ge 10) { throw }; Start-Sleep -Milliseconds 100 }
	}
}

# Writes through a temporary file and a rename, so the skin never reads a
# half-written file while it is polling it.
function Write-Atomic([string]$path, [string]$content) {
	$tmp = "$path.tmp"
	[IO.File]::WriteAllText($tmp, $content, $Utf8NoBom)
	Move-WithRetry $tmp $path
}

# ------------------------------------------------------------------ delete --

if ($req.mode -eq 'delete') {
	if (Test-Path -LiteralPath $noteFile) {
		$content = [IO.File]::ReadAllText($noteFile, $Utf8NoBom)
		if ($content -ne '') {
			[void][IO.Directory]::CreateDirectory($req.deleted)
			$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
			$name = [IO.Path]::GetFileNameWithoutExtension($noteFile)
			[IO.File]::WriteAllText((Join-Path $req.deleted "${name}_$stamp.txt"), $content, $Utf8NoBom)
		}
		if ($req.keep -eq '1') { Write-Atomic $noteFile '' }
		else { Move-WithRetry $noteFile "$noteFile.del"; Remove-Item -LiteralPath "$noteFile.del" }   # rename first: retried if WebParser holds it
	}
	exit 0
}

# ----------------------------------------------------------------- editors --

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Rainmeter positions skins in physical pixels. Declaring the process DPI-aware
# makes Windows Forms use the same coordinates instead of scaled ones, so the
# editor lands exactly on the note at any display scaling.
Add-Type -Namespace Native -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr hWnd);
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
'@
[void][Native.User32]::SetProcessDPIAware()

$isTitle = $req.mode -eq 'title'
Remove-Item -LiteralPath $req.close -ErrorAction SilentlyContinue   # leftover from a previous run

function ConvertTo-Color([string]$rgb) {
	$p = $rgb -split ','
	return [Drawing.Color]::FromArgb([int]$p[0], [int]$p[1], [int]$p[2])
}

# Turns a typed title into a valid file name. Removed: characters Windows
# forbids in file names, plus # [ ] % which Rainmeter would read as variable,
# section or URL escapes when the path is put into the skin. Also trims the
# spaces and dots Windows drops from the end of names, caps the length so the
# full path stays short, and suffixes reserved device names (CON, NUL, ...).
function Get-SafeName([string]$title) {
	$s = ($title -replace '[\\/:*?"<>|#\[\]%\x00-\x1F]', '').Trim().TrimEnd('.', ' ')
	if ($s.Length -gt 80) { $s = $s.Substring(0, 80).TrimEnd('.', ' ') }
	if ($s -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { $s += '_' }
	return $s
}

# Renames the note after the title typed in the box and tells the skin the
# final name through the slot file. A name already used by another note gets
# " (2)", " (3)"... An empty or unchanged title keeps the current name. A change
# of capitals only ("spesa" -> "Spesa") is a plain rename: on Windows the old
# and new names are the same file, so the "already used" test must skip it.
function Save-Title {
	$new = Get-SafeName $box.Text
	$old = $req.name
	if ($new -eq '' -or $new -ceq $old) { return }
	$final = $new
	if ($new -ine $old) {
		$n = 2
		while (Test-Path -LiteralPath (Join-Path $req.dir "$final.txt")) { $final = "$new ($n)"; $n++ }
	}
	$target = Join-Path $req.dir "$final.txt"
	if (Test-Path -LiteralPath $noteFile) { Move-WithRetry $noteFile $target }
	else { [IO.File]::WriteAllText($target, '', $Utf8NoBom) }
	Write-Atomic $req.slot $final
}

function Save-Text {
	Write-Atomic $noteFile $box.Text
	$script:dirty = $false
}

$form = New-Object Windows.Forms.Form
$form.Text = 'Note'
$form.FormBorderStyle = 'None'
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point([int]$req.x, [int]$req.y)
$form.Size = New-Object Drawing.Size([int]$req.w, [int]$req.h)
$form.BackColor = ConvertTo-Color $req.back
# No taskbar button: the editor closes as soon as another window is used, so a
# button would only flash in and out of the taskbar.
$form.ShowInTaskbar = $false

$box = New-Object Windows.Forms.TextBox
$box.BorderStyle = 'None'
$box.Dock = 'Fill'
$box.BackColor = $form.BackColor
$box.ForeColor = ConvertTo-Color $req.fore
$style = if ($req.bold -eq '1') { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
$box.Font = New-Object Drawing.Font($req.font, [float]$req.size, $style)

if ($isTitle) {
	$box.Multiline = $false
	$box.MaxLength = 80
	$box.Text = $req.name
	$box.SelectAll()                     # typing replaces the old title, arrows keep it
} else {
	$box.Multiline = $true
	$box.AcceptsReturn = $true
	$box.AcceptsTab = $true
	$box.WordWrap = $true
	$box.ScrollBars = 'Vertical'
	if (Test-Path -LiteralPath $noteFile) { $box.Text = [IO.File]::ReadAllText($noteFile, $Utf8NoBom) }
	# Resume at the cursor position of the last edit (end of the text if unknown,
	# or if the text got shorter outside the editor).
	$caret = $box.Text.Length
	if (Test-Path -LiteralPath $req.caret) {
		$saved = 0
		if ([int]::TryParse(([IO.File]::ReadAllText($req.caret)).Trim(), [ref]$saved) -and $saved -le $caret) { $caret = $saved }
	}
	$box.SelectionStart = $caret

	# Autosave: every change restarts a short timer; the save happens when typing
	# pauses. 400 ms keeps disk writes rare while losing almost nothing on a crash.
	$script:dirty = $false
	$saveTimer = New-Object Windows.Forms.Timer
	$saveTimer.Interval = 400
	$saveTimer.Add_Tick({ $saveTimer.Stop(); if ($script:dirty) { Save-Text } })
	$box.Add_TextChanged({ $script:dirty = $true; $saveTimer.Stop(); $saveTimer.Start() })
}
$form.Controls.Add($box)

$box.Add_KeyDown({
	param($s, $e)
	$done = ($e.KeyCode -eq 'Escape') -or ($e.Control -and $e.KeyCode -eq 'S') -or ($isTitle -and $e.KeyCode -eq 'Enter')
	if ($done) { $e.SuppressKeyPress = $true; $form.Close() }
	elseif ($e.Control -and $e.KeyCode -eq 'A') { $e.SuppressKeyPress = $true; $box.SelectAll() }   # multi-line TextBox has no Ctrl+A
})

# Focus watch and the skin's close signal, checked four times per second
# (fast enough to feel immediate, cheap enough to run for hours).
$watchTimer = New-Object Windows.Forms.Timer
$watchTimer.Interval = 250
$watchTimer.Add_Tick({
	# "Click elsewhere closes": done by watching the foreground window instead of
	# the Deactivate event, because Windows may refuse to give the editor focus
	# when it starts (foreground lock) and Deactivate then never fires. Rule:
	# once the editor has been in front, any other window in front closes it;
	# if it never got there, a change from the window that was in front at
	# start-up closes it.
	$fg = [Native.User32]::GetForegroundWindow()
	if ($fg -eq $form.Handle) { $script:wasActive = $true }
	elseif ($script:wasActive -or $fg -ne $script:startFg) { $form.Close(); return }
	if (Test-Path -LiteralPath $req.close) { Remove-Item -LiteralPath $req.close -ErrorAction SilentlyContinue; $form.Close() }
})

# RunCommand starts the process hidden, and Windows applies that "hidden" state
# to the first window the process shows. Showing it again explicitly here makes
# the editor visible regardless of how it was launched.
$form.Add_Shown({
	[void][Native.User32]::ShowWindow($form.Handle, 5)                # SW_SHOW
	[void][Native.User32]::SetForegroundWindow($form.Handle)
	$box.Focus()
	$script:wasActive = $false
	$script:startFg = [Native.User32]::GetForegroundWindow()
	$watchTimer.Start()
})
$form.Add_FormClosing({
	$watchTimer.Stop()
	if ($isTitle) { Save-Title }
	else {
		$saveTimer.Stop(); Save-Text
		[IO.File]::WriteAllText($req.caret, [string]$box.SelectionStart)
	}
})

[Windows.Forms.Application]::Run($form)
