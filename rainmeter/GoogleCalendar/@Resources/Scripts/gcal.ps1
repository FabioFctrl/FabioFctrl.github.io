# gcal.ps1 - bridge between the Rainmeter skin and the Google Calendar / Google Tasks APIs.
#
# The skin (GCal.lua) writes a request to a "key=value" file and runs this script
# through the RunCommand plugin. The script performs the action, then syncs and
# writes data.tsv, which Lua reads back. The last line of stdout is the outcome:
#   OK                 all good
#   AUTH <code>        a (new) Google sign-in is needed: NO_CLIENT, NO_TOKEN, EXPIRED
#   ERR <message>      error to show in the status line
# AUTH uses codes rather than sentences so that the skin can translate them.
#
# Design notes:
#  * Windows PowerShell 5.1: it ships with every Windows 10/11, so nothing has to
#    be installed (Python, Node, Google libraries). The REST APIs are enough.
#  * The request comes through a file, not the command line: titles typed by the
#    user can contain quotes and special characters that the command line
#    (Rainmeter -> RunCommand -> powershell.exe) would mangle.
#  * Output is TSV (one row per item, tab-separated fields): Lua parses it in a
#    few lines, while a JSON parser in Lua would be much longer.
#  * OAuth "desktop app" flow with a 127.0.0.1 redirect and PKCE, as Google
#    recommends for installed apps. The listener uses TcpListener rather than
#    HttpListener because HttpListener on 127.0.0.1 may need a URL ACL (admin rights).
#  * The refresh token is stored encrypted with DPAPI (ConvertFrom-SecureString):
#    only the same Windows user on the same PC can read it.
#  * ASCII-only file: Windows PowerShell 5.1 reads .ps1 files without a BOM as ANSI.
#
# data.tsv rows (tab-separated):
#   R  from  to                                         period covered (Unix seconds)
#   C  calendarId  r,g,b  writable  primary  name       one per calendar shown
#   L  listId  name                                     one per task list
#   E  calendarId  eventId  start  end  allDay  r,g,b  link  eventType  title
#   T  listId  taskId  due  done  title

param(
	[Parameter(Mandatory = $true)][string]$RequestFile
)

$ErrorActionPreference = 'Stop'
# Google only accepts TLS 1.2+; .NET 4.x in PowerShell 5.1 does not always enable it by default.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# RunCommand reads stdout as UTF-8 (OutputType=UTF8 in the .ini).
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$GoogleDir  = Join-Path (Split-Path $PSScriptRoot -Parent) 'Google'
$ClientFile = Join-Path $GoogleDir 'client_secret.json'
$TokenFile  = Join-Path $GoogleDir 'token.dat'
$DataFile   = Join-Path $GoogleDir 'data.tsv'

# Full Calendar scope (read + write events + calendar list + colors) and Tasks.
$Scopes = 'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks'
$CalApi  = 'https://www.googleapis.com/calendar/v3'
$TaskApi = 'https://tasks.googleapis.com/tasks/v1'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

# Dedicated exception: tells "a new sign-in is needed" apart from other errors,
# so the skin can show the sign-in prompt instead of a generic error.
class AuthRequired : Exception { AuthRequired([string]$code) : base($code) {} }

# ---------------------------------------------------------------- helpers --

# Reads the request file: "key=value" lines; the value is everything after the
# first "=" (so a title may contain "=").
function Read-Request([string]$path) {
	$req = @{}
	foreach ($line in [IO.File]::ReadAllLines($path, $Utf8NoBom)) {
		$i = $line.IndexOf('=')
		if ($i -gt 0) { $req[$line.Substring(0, $i)] = $line.Substring($i + 1) }
	}
	return $req
}

function Get-Client {
	if (-not (Test-Path $ClientFile)) { throw [AuthRequired]::new('NO_CLIENT') }
	$json = Get-Content $ClientFile -Raw | ConvertFrom-Json
	# The file downloaded from Google has an "installed" key for "Desktop app" clients.
	if ($json.installed) { return $json.installed }
	throw 'client_secret.json is not a "Desktop app" client'
}

# base64url without padding, as required by PKCE (RFC 7636).
function ConvertTo-Base64Url([byte[]]$bytes) {
	return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-RandomBytes([int]$n) {
	$b = New-Object byte[] $n
	[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
	return $b
}

function Save-Token($obj) {
	$plain = $obj | ConvertTo-Json -Compress
	$sec = ConvertTo-SecureString $plain -AsPlainText -Force
	Set-Content -Path $TokenFile -Value (ConvertFrom-SecureString $sec) -Encoding ASCII
}

function Read-Token {
	if (-not (Test-Path $TokenFile)) { throw [AuthRequired]::new('NO_TOKEN') }
	$sec = ConvertTo-SecureString (Get-Content $TokenFile -Raw).Trim()
	$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
	try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
	finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
	return $plain | ConvertFrom-Json
}

# ------------------------------------------------------------------ OAuth --

# First sign-in: opens the browser on Google's consent page and waits for the
# redirect to http://127.0.0.1:<free port>/ carrying the authorization code.
function Invoke-Login {
	$client = Get-Client

	# Port 0 = the OS picks a free port (Google accepts any loopback port).
	$tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
	$tcp.Start()
	$port = $tcp.LocalEndpoint.Port
	$redirect = "http://127.0.0.1:$port/"

	$verifier = ConvertTo-Base64Url (New-RandomBytes 48)          # 64 characters, within 43-128
	$sha = [Security.Cryptography.SHA256]::Create()
	$challenge = ConvertTo-Base64Url ($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier)))
	$state = ConvertTo-Base64Url (New-RandomBytes 16)             # protects against unsolicited responses

	$q = @{
		client_id = $client.client_id; redirect_uri = $redirect; response_type = 'code'
		scope = $Scopes; code_challenge = $challenge; code_challenge_method = 'S256'
		state = $state; access_type = 'offline'; prompt = 'consent'
	}
	$query = ($q.GetEnumerator() | ForEach-Object { $_.Key + '=' + [Uri]::EscapeDataString($_.Value) }) -join '&'
	Start-Process ($client.auth_uri + '?' + $query)

	try {
		# 5 minutes to complete the consent in the browser, then give up.
		$accept = $tcp.AcceptTcpClientAsync()
		if (-not $accept.Wait(300000)) { throw 'Timed out waiting for the sign-in' }
		$conn = $accept.Result
		$stream = $conn.GetStream()
		$reader = New-Object IO.StreamReader($stream)
		$requestLine = $reader.ReadLine()                           # e.g. "GET /?code=...&state=... HTTP/1.1"
		$html = '<html><body style="font-family:sans-serif"><h2>Done.</h2>You can close this page and go back to the widget.</body></html>'
		$body = [Text.Encoding]::UTF8.GetBytes($html)
		$head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n")
		$stream.Write($head, 0, $head.Length)
		$stream.Write($body, 0, $body.Length)
		$conn.Close()
	} finally {
		$tcp.Stop()
	}

	$target = ($requestLine -split ' ')[1]
	$params = @{}
	if ($target -match '\?(.*)$') {
		foreach ($pair in $Matches[1] -split '&') {
			$kv = $pair -split '=', 2
			$params[$kv[0]] = [Uri]::UnescapeDataString(($kv[1] -replace '\+', ' '))
		}
	}
	if ($params['error']) { throw "Sign-in refused: $($params['error'])" }
	if ($params['state'] -ne $state) { throw 'Invalid sign-in response (state)' }

	$tok = Invoke-RestMethod -Method Post -Uri $client.token_uri -Body @{
		code = $params['code']; client_id = $client.client_id; client_secret = $client.client_secret
		redirect_uri = $redirect; grant_type = 'authorization_code'; code_verifier = $verifier
	}
	if (-not $tok.refresh_token) { throw 'Google did not return a refresh token' }
	Save-Token @{ refresh_token = $tok.refresh_token }
}

# Exchanges the stored refresh token for an access token (valid ~1 hour). One
# extra request per run, but no expiry bookkeeping to store and manage.
function Get-AccessToken {
	$client = Get-Client
	$t = Read-Token
	try {
		$r = Invoke-RestMethod -Method Post -Uri $client.token_uri -Body @{
			client_id = $client.client_id; client_secret = $client.client_secret
			refresh_token = $t.refresh_token; grant_type = 'refresh_token'
		}
	} catch {
		# invalid_grant = token revoked or expired: a new sign-in is needed.
		if ("$_" -match 'invalid_grant') {
			Remove-Item $TokenFile -ErrorAction SilentlyContinue
			throw [AuthRequired]::new('EXPIRED')
		}
		throw
	}
	return $r.access_token
}

# Authenticated REST call. A JSON body is sent as UTF-8 bytes: given a string,
# PowerShell 5.1 would encode it as ISO-8859-1 and break accented characters.
function Invoke-Google([string]$method, [string]$uri, $body = $null) {
	$p = @{ Method = $method; Uri = $uri; Headers = @{ Authorization = "Bearer $script:Access" } }
	if ($null -ne $body) {
		$p.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 5))
		$p.ContentType = 'application/json; charset=utf-8'
	}
	return Invoke-RestMethod @p
}

# Walks all pages of a list (nextPageToken) and returns the items.
function Get-AllItems([string]$uri) {
	$all = @()
	$token = $null
	do {
		$u = $uri
		if ($token) { $u += '&pageToken=' + [Uri]::EscapeDataString($token) }
		$r = Invoke-Google 'Get' $u
		if ($r.items) { $all += $r.items }
		$token = $r.nextPageToken
	} while ($token)
	return $all
}

# ------------------------------------------------------------ conversions --

# "#9fe1e7" -> "159,225,231" (Rainmeter colour format).
function ConvertTo-Rgb([string]$hex) {
	$h = $hex.TrimStart('#')
	return '{0},{1},{2}' -f [Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16)
}

# Date "yyyy-MM-dd" -> epoch of LOCAL midnight (as Lua's os.time computes it).
function ConvertFrom-LocalDate([string]$d) {
	$dt = [datetime]::ParseExact($d.Substring(0, 10), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
	return ([DateTimeOffset]$dt).ToUnixTimeSeconds()
}

# RFC 3339 dateTime with offset -> epoch. In PS 5.1 ConvertFrom-Json keeps dates
# as strings; [datetime] is handled too, just in case.
function ConvertFrom-RfcTime($v) {
	if ($v -is [datetime]) { return ([DateTimeOffset]$v).ToUnixTimeSeconds() }
	return [DateTimeOffset]::Parse($v, [Globalization.CultureInfo]::InvariantCulture).ToUnixTimeSeconds()
}

function ConvertTo-RfcTime([long]$epoch) {
	return [DateTimeOffset]::FromUnixTimeSeconds($epoch).ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# Text fields must not contain tabs/newlines: they would break the TSV format.
function Clean([string]$s) {
	if (-not $s) { return '' }
	return ($s -replace '[\t\r\n]+', ' ').Trim()
}

# ------------------------------------------------------------------- sync --

# Downloads calendars, events (recurrences already expanded by Google:
# singleEvents=true) and tasks in [from, to) and writes data.tsv atomically.
function Invoke-Sync([long]$from, [long]$to) {
	$lines = New-Object Collections.Generic.List[string]
	$lines.Add("R`t$from`t$to")
	$tMin = [Uri]::EscapeDataString((ConvertTo-RfcTime $from))
	$tMax = [Uri]::EscapeDataString((ConvertTo-RfcTime $to))

	# Google's palette of per-event colours (colorId 1..11).
	$palette = @{}
	$colors = Invoke-Google 'Get' "$CalApi/colors"
	foreach ($p in $colors.event.PSObject.Properties) { $palette[$p.Name] = ConvertTo-Rgb $p.Value.background }

	# Only calendars ticked in Google's UI (selected): the same set you see on
	# calendar.google.com.
	$cals = Get-AllItems "$CalApi/users/me/calendarList?maxResults=250&fields=nextPageToken,items(id,summary,summaryOverride,backgroundColor,accessRole,selected,primary)"
	foreach ($c in $cals) {
		if (-not $c.selected) { continue }
		$name = if ($c.summaryOverride) { $c.summaryOverride } else { $c.summary }
		$color = ConvertTo-Rgb $c.backgroundColor
		$writable = if ($c.accessRole -eq 'owner' -or $c.accessRole -eq 'writer') { 1 } else { 0 }
		$primary = if ($c.primary) { 1 } else { 0 }
		$lines.Add("C`t$($c.id)`t$color`t$writable`t$primary`t$(Clean $name)")

		$evs = Get-AllItems ("$CalApi/calendars/$([Uri]::EscapeDataString($c.id))/events?singleEvents=true&maxResults=2500" +
			"&timeMin=$tMin&timeMax=$tMax&fields=nextPageToken,items(id,status,summary,start,end,colorId,htmlLink,eventType)")
		foreach ($e in $evs) {
			if ($e.status -eq 'cancelled') { continue }
			if ($e.start.date) {
				$s = ConvertFrom-LocalDate $e.start.date; $en = ConvertFrom-LocalDate $e.end.date; $all = 1
			} else {
				$s = ConvertFrom-RfcTime $e.start.dateTime; $en = ConvertFrom-RfcTime $e.end.dateTime; $all = 0
			}
			$ec = if ($e.colorId -and $palette[$e.colorId]) { $palette[$e.colorId] } else { $color }
			# eventType ("default", "birthday", ...) is used by the skin: Google
			# Calendar paints birthdays with their own colour, not the calendar's.
			$etype = if ($e.eventType) { $e.eventType } else { 'default' }
			$lines.Add("E`t$($c.id)`t$($e.id)`t$s`t$en`t$all`t$ec`t$(Clean $e.htmlLink)`t$etype`t$(Clean $e.summary)")
		}
	}

	# Tasks: the API treats "due" as a date only (Google drops the time), so the
	# yyyy-MM-dd part is used as a local day. Tasks without a due date have no
	# place in a calendar and are not downloaded. The API does not expose
	# repeating tasks: only the current occurrence of each one is returned.
	$lists = Get-AllItems "$TaskApi/users/@me/lists?maxResults=100&fields=nextPageToken,items(id,title)"
	foreach ($l in $lists) {
		$lines.Add("L`t$($l.id)`t$(Clean $l.title)")
		$tasks = Get-AllItems ("$TaskApi/lists/$([Uri]::EscapeDataString($l.id))/tasks?maxResults=100&showCompleted=true&showHidden=true" +
			"&dueMin=$tMin&dueMax=$tMax&fields=nextPageToken,items(id,title,due,status,deleted)")
		foreach ($t in $tasks) {
			if ($t.deleted -or -not $t.due) { continue }
			$dueStr = if ($t.due -is [datetime]) { $t.due.ToUniversalTime().ToString('yyyy-MM-dd') } else { $t.due }
			$done = if ($t.status -eq 'completed') { 1 } else { 0 }
			$lines.Add("T`t$($l.id)`t$($t.id)`t$(ConvertFrom-LocalDate $dueStr)`t$done`t$(Clean $t.title)")
		}
	}

	# Atomic write: Lua must never read a half-written file.
	$tmp = "$DataFile.tmp"
	[IO.File]::WriteAllLines($tmp, $lines, $Utf8NoBom)
	Move-Item -Force $tmp $DataFile
}

# ---------------------------------------------------------------- actions --

# Local date and time from the form ("2026-10-21", "10:30") -> RFC 3339 string
# with the local offset. An offset is used instead of an IANA time zone because
# Windows only knows its own zone names ("W. Europe Standard Time"), which
# Google does not accept.
function ConvertTo-LocalRfc([string]$date, [string]$time) {
	$dt = [datetime]::ParseExact("$date $time", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
	return ([DateTimeOffset]$dt).ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Invoke-Action($req) {
	switch ($req.action) {
		'add-event' {
			$body = @{ summary = $req.title }
			if ($req.allday -eq '1') {
				# Exclusive end: a one-day event ends the next day.
				$next = [datetime]::ParseExact($req.date, 'yyyy-MM-dd', $null).AddDays(1).ToString('yyyy-MM-dd')
				$body.start = @{ date = $req.date }; $body.end = @{ date = $next }
			} else {
				$body.start = @{ dateTime = (ConvertTo-LocalRfc $req.date $req.start) }
				$body.end = @{ dateTime = (ConvertTo-LocalRfc $req.date $req.end) }
			}
			Invoke-Google 'Post' "$CalApi/calendars/$([Uri]::EscapeDataString($req.calendar))/events" $body | Out-Null
		}
		'add-task' {
			Invoke-Google 'Post' "$TaskApi/lists/$([Uri]::EscapeDataString($req.list))/tasks" @{
				title = $req.title; due = "$($req.date)T00:00:00.000Z"
			} | Out-Null
		}
		'set-task-done' {
			$body = if ($req.done -eq '1') { @{ status = 'completed' } } else { @{ status = 'needsAction'; completed = $null } }
			Invoke-Google 'Patch' "$TaskApi/lists/$([Uri]::EscapeDataString($req.list))/tasks/$([Uri]::EscapeDataString($req.id))" $body | Out-Null
		}
		'delete-event' {
			# For a recurring event the id is that of the single occurrence: only that one is deleted.
			Invoke-Google 'Delete' "$CalApi/calendars/$([Uri]::EscapeDataString($req.calendar))/events/$([Uri]::EscapeDataString($req.id))" | Out-Null
		}
		'delete-task' {
			Invoke-Google 'Delete' "$TaskApi/lists/$([Uri]::EscapeDataString($req.list))/tasks/$([Uri]::EscapeDataString($req.id))" | Out-Null
		}
		'sync' { }
		default { throw "Unknown action: $($req.action)" }
	}
}

# ------------------------------------------------------------------- main --

try {
	$req = Read-Request $RequestFile
	if ($req.action -eq 'login') { Invoke-Login; $req.action = 'sync' }
	$script:Access = Get-AccessToken
	Invoke-Action $req
	# Every action ends with a sync: the skin sees the result immediately without
	# starting a second process.
	Invoke-Sync ([long]$req.from) ([long]$req.to)
	Write-Output 'OK'
} catch [AuthRequired] {
	Write-Output "AUTH $($_.Exception.Message)"
} catch {
	# Single-line message: Lua only shows the last line of stdout.
	$msg = ($_.Exception.Message -replace '\s+', ' ')
	if ($_.ErrorDetails.Message) {
		try { $msg = (($_.ErrorDetails.Message | ConvertFrom-Json).error.message) -replace '\s+', ' ' } catch { }
	}
	Write-Output "ERR $msg"
}
