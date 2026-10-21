# gcal.ps1 - ponte tra la skin Rainmeter e le API Google Calendar / Google Tasks.
#
# La skin (GCal.lua) scrive una richiesta in un file "chiave=valore" e lancia questo
# script tramite il plugin RunCommand. Lo script esegue l'azione, poi risincronizza
# e scrive data.tsv, che Lua rilegge. L'ultima riga di stdout e' l'esito:
#   OK                    tutto bene
#   AUTH <messaggio>      serve (di nuovo) l'accesso a Google
#   ERR <messaggio>       errore da mostrare nella riga di stato
#
# Scelte di fondo:
#  * Windows PowerShell 5.1: e' gia' presente in ogni Windows 10/11, quindi nessuna
#    installazione (Python, Node, librerie Google). Le API REST bastano.
#  * Richiesta via file invece che via riga di comando: i titoli scritti dall'utente
#    possono contenere virgolette e caratteri speciali che la riga di comando
#    (Rainmeter -> RunCommand -> powershell.exe) altererebbe.
#  * Output in TSV (una riga per elemento, campi separati da tab): Lua lo legge con
#    poche righe di codice, mentre un parser JSON in Lua sarebbe molto piu' lungo.
#  * OAuth "app desktop" con redirect su 127.0.0.1 e PKCE, come raccomanda Google
#    per le app installate. Il listener usa TcpListener e non HttpListener perche'
#    HttpListener su 127.0.0.1 puo' richiedere una URL ACL (diritti di admin).
#  * Il refresh token e' salvato cifrato con DPAPI (ConvertFrom-SecureString):
#    leggibile solo dal tuo utente Windows su questo PC.
#  * File di sola ASCII: Windows PowerShell 5.1 legge i .ps1 senza BOM come ANSI.

param(
	[Parameter(Mandatory = $true)][string]$RequestFile
)

$ErrorActionPreference = 'Stop'
# Google accetta solo TLS 1.2+; .NET 4.x in PowerShell 5.1 non lo abilita sempre di default.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# RunCommand legge stdout come UTF-8 (OutputType=UTF8 nel .ini).
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$GoogleDir  = Join-Path (Split-Path $PSScriptRoot -Parent) 'Google'
$ClientFile = Join-Path $GoogleDir 'client_secret.json'
$TokenFile  = Join-Path $GoogleDir 'token.dat'
$DataFile   = Join-Path $GoogleDir 'data.tsv'

# Calendar completo (lettura + scrittura eventi + elenco calendari + colori) e Tasks.
$Scopes = 'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks'
$CalApi  = 'https://www.googleapis.com/calendar/v3'
$TaskApi = 'https://tasks.googleapis.com/tasks/v1'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

# Eccezione dedicata: distingue "serve un nuovo login" dagli altri errori, cosi'
# la skin puo' mostrare il pulsante di accesso invece di un errore generico.
class AuthRequired : Exception { AuthRequired([string]$m) : base($m) {} }

# --------------------------------------------------------------- utilita' --

# Legge il file richiesta: righe "chiave=valore", il valore e' tutto cio' che segue
# il primo "=" (cosi' un titolo puo' contenere "=").
function Read-Request([string]$path) {
	$req = @{}
	foreach ($line in [IO.File]::ReadAllLines($path, $Utf8NoBom)) {
		$i = $line.IndexOf('=')
		if ($i -gt 0) { $req[$line.Substring(0, $i)] = $line.Substring($i + 1) }
	}
	return $req
}

function Get-Client {
	if (-not (Test-Path $ClientFile)) {
		throw [AuthRequired]::new('Configura Google: vedi LEGGIMI.txt')
	}
	$json = Get-Content $ClientFile -Raw | ConvertFrom-Json
	# Il file scaricato da Google ha la chiave "installed" per i client "App desktop".
	if ($json.installed) { return $json.installed }
	throw 'client_secret.json non e'' di tipo "App desktop"'
}

# base64url senza padding, richiesto da PKCE (RFC 7636).
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
	if (-not (Test-Path $TokenFile)) { throw [AuthRequired]::new('Accesso a Google non ancora fatto') }
	$sec = ConvertTo-SecureString (Get-Content $TokenFile -Raw).Trim()
	$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
	try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
	finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
	return $plain | ConvertFrom-Json
}

# ------------------------------------------------------------------ OAuth --

# Primo accesso: apre il browser sulla pagina di consenso Google e attende il
# redirect su http://127.0.0.1:<porta libera>/ con il codice di autorizzazione.
function Invoke-Login {
	$client = Get-Client

	# Porta 0 = il sistema sceglie una porta libera (Google accetta qualunque porta di loopback).
	$tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
	$tcp.Start()
	$port = $tcp.LocalEndpoint.Port
	$redirect = "http://127.0.0.1:$port/"

	$verifier = ConvertTo-Base64Url (New-RandomBytes 48)          # 64 caratteri, nel range 43-128
	$sha = [Security.Cryptography.SHA256]::Create()
	$challenge = ConvertTo-Base64Url ($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier)))
	$state = ConvertTo-Base64Url (New-RandomBytes 16)             # contro risposte non richieste

	$q = @{
		client_id = $client.client_id; redirect_uri = $redirect; response_type = 'code'
		scope = $Scopes; code_challenge = $challenge; code_challenge_method = 'S256'
		state = $state; access_type = 'offline'; prompt = 'consent'
	}
	$query = ($q.GetEnumerator() | ForEach-Object { $_.Key + '=' + [Uri]::EscapeDataString($_.Value) }) -join '&'
	Start-Process ($client.auth_uri + '?' + $query)

	try {
		# 5 minuti per completare il consenso nel browser, poi si rinuncia.
		$accept = $tcp.AcceptTcpClientAsync()
		if (-not $accept.Wait(300000)) { throw 'Tempo scaduto in attesa del login' }
		$conn = $accept.Result
		$stream = $conn.GetStream()
		$reader = New-Object IO.StreamReader($stream)
		$requestLine = $reader.ReadLine()                           # es. "GET /?code=...&state=... HTTP/1.1"
		$html = '<html><body style="font-family:sans-serif"><h2>Fatto.</h2>Puoi chiudere questa pagina e tornare al widget.</body></html>'
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
	if ($params['error']) { throw "Accesso negato: $($params['error'])" }
	if ($params['state'] -ne $state) { throw 'Risposta di login non valida (state)' }

	$tok = Invoke-RestMethod -Method Post -Uri $client.token_uri -Body @{
		code = $params['code']; client_id = $client.client_id; client_secret = $client.client_secret
		redirect_uri = $redirect; grant_type = 'authorization_code'; code_verifier = $verifier
	}
	if (-not $tok.refresh_token) { throw 'Google non ha restituito un refresh token' }
	Save-Token @{ refresh_token = $tok.refresh_token }
}

# Scambia il refresh token salvato con un access token (valido ~1 ora): costa una
# richiesta per esecuzione ma evita di dover salvare e gestire la scadenza.
function Get-AccessToken {
	$client = Get-Client
	$t = Read-Token
	try {
		$r = Invoke-RestMethod -Method Post -Uri $client.token_uri -Body @{
			client_id = $client.client_id; client_secret = $client.client_secret
			refresh_token = $t.refresh_token; grant_type = 'refresh_token'
		}
	} catch {
		# invalid_grant = token revocato o scaduto: va rifatto il login.
		if ("$_" -match 'invalid_grant') {
			Remove-Item $TokenFile -ErrorAction SilentlyContinue
			throw [AuthRequired]::new('Accesso scaduto o revocato: ricollega Google')
		}
		throw
	}
	return $r.access_token
}

# Chiamata REST autenticata. Il corpo JSON va inviato come byte UTF-8: con una
# stringa, PowerShell 5.1 la codificherebbe in ISO-8859-1 rovinando gli accenti.
function Invoke-Google([string]$method, [string]$uri, $body = $null) {
	$p = @{ Method = $method; Uri = $uri; Headers = @{ Authorization = "Bearer $script:Access" } }
	if ($null -ne $body) {
		$p.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 5))
		$p.ContentType = 'application/json; charset=utf-8'
	}
	return Invoke-RestMethod @p
}

# Scorre tutte le pagine di un elenco (nextPageToken) e restituisce gli items.
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

# ------------------------------------------------------------ conversioni --

# "#9fe1e7" -> "159,225,231" (formato colori di Rainmeter).
function ConvertTo-Rgb([string]$hex) {
	$h = $hex.TrimStart('#')
	return '{0},{1},{2}' -f [Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16)
}

# Data "yyyy-MM-dd" -> epoch della mezzanotte LOCALE (come la calcola os.time in Lua).
function ConvertFrom-LocalDate([string]$d) {
	$dt = [datetime]::ParseExact($d.Substring(0, 10), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
	return ([DateTimeOffset]$dt).ToUnixTimeSeconds()
}

# dateTime RFC 3339 con offset -> epoch. In PS 5.1 ConvertFrom-Json lascia le date
# come stringhe; si gestisce anche [datetime] per sicurezza.
function ConvertFrom-RfcTime($v) {
	if ($v -is [datetime]) { return ([DateTimeOffset]$v).ToUnixTimeSeconds() }
	return [DateTimeOffset]::Parse($v, [Globalization.CultureInfo]::InvariantCulture).ToUnixTimeSeconds()
}

function ConvertTo-RfcTime([long]$epoch) {
	return [DateTimeOffset]::FromUnixTimeSeconds($epoch).ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# I campi di testo non devono contenere tab/a-capo: romperebbero il formato TSV.
function Clean([string]$s) {
	if (-not $s) { return '' }
	return ($s -replace '[\t\r\n]+', ' ').Trim()
}

# ------------------------------------------------------------------- sync --

# Scarica calendari, eventi (ricorrenze gia' espanse da Google: singleEvents=true)
# e attivita' nell'intervallo [from, to) e scrive data.tsv in modo atomico.
function Invoke-Sync([long]$from, [long]$to) {
	$lines = New-Object Collections.Generic.List[string]
	$lines.Add("R`t$from`t$to")
	$tMin = [Uri]::EscapeDataString((ConvertTo-RfcTime $from))
	$tMax = [Uri]::EscapeDataString((ConvertTo-RfcTime $to))

	# Palette dei colori per-evento (colorId 1..11) definita da Google.
	$palette = @{}
	$colors = Invoke-Google 'Get' "$CalApi/colors"
	foreach ($p in $colors.event.PSObject.Properties) { $palette[$p.Name] = ConvertTo-Rgb $p.Value.background }

	# Solo i calendari spuntati nell'interfaccia di Google (selected): lo stesso
	# insieme che vedi su calendar.google.com.
	$cals = Get-AllItems "$CalApi/users/me/calendarList?maxResults=250&fields=nextPageToken,items(id,summary,summaryOverride,backgroundColor,accessRole,selected,primary)"
	foreach ($c in $cals) {
		if (-not $c.selected) { continue }
		$name = if ($c.summaryOverride) { $c.summaryOverride } else { $c.summary }
		$color = ConvertTo-Rgb $c.backgroundColor
		$writable = if ($c.accessRole -eq 'owner' -or $c.accessRole -eq 'writer') { 1 } else { 0 }
		$primary = if ($c.primary) { 1 } else { 0 }
		$lines.Add("C`t$($c.id)`t$color`t$writable`t$primary`t$(Clean $name)")

		$evs = Get-AllItems ("$CalApi/calendars/$([Uri]::EscapeDataString($c.id))/events?singleEvents=true&maxResults=2500" +
			"&timeMin=$tMin&timeMax=$tMax&fields=nextPageToken,items(id,status,summary,start,end,colorId,htmlLink)")
		foreach ($e in $evs) {
			if ($e.status -eq 'cancelled') { continue }
			if ($e.start.date) {
				$s = ConvertFrom-LocalDate $e.start.date; $en = ConvertFrom-LocalDate $e.end.date; $all = 1
			} else {
				$s = ConvertFrom-RfcTime $e.start.dateTime; $en = ConvertFrom-RfcTime $e.end.dateTime; $all = 0
			}
			$ec = if ($e.colorId -and $palette[$e.colorId]) { $palette[$e.colorId] } else { $color }
			$lines.Add("E`t$($c.id)`t$($e.id)`t$s`t$en`t$all`t$ec`t$(Clean $e.htmlLink)`t$(Clean $e.summary)")
		}
	}

	# Attivita': l'API tratta "due" come sola data (l'orario viene scartato da Google),
	# quindi si usa la parte yyyy-MM-dd come giorno locale. Quelle senza scadenza non
	# hanno un posto nel calendario e non vengono scaricate.
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

	# Scrittura atomica: Lua non deve mai leggere un file a meta'.
	$tmp = "$DataFile.tmp"
	[IO.File]::WriteAllLines($tmp, $lines, $Utf8NoBom)
	Move-Item -Force $tmp $DataFile
}

# ----------------------------------------------------------------- azioni --

# Data e ora locali dal modulo ("2026-10-21", "10:30") -> stringa RFC 3339 con
# l'offset locale. Si usa l'offset e non un fuso IANA perche' Windows conosce solo
# i propri nomi di fuso ("W. Europe Standard Time"), che Google non accetta.
function ConvertTo-LocalRfc([string]$date, [string]$time) {
	$dt = [datetime]::ParseExact("$date $time", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
	return ([DateTimeOffset]$dt).ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Invoke-Action($req) {
	switch ($req.action) {
		'add-event' {
			$body = @{ summary = $req.title }
			if ($req.allday -eq '1') {
				# Fine esclusiva: un evento di un giorno finisce il giorno dopo.
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
			# Per un evento ricorrente l'id e' quello della singola istanza: si elimina solo quella.
			Invoke-Google 'Delete' "$CalApi/calendars/$([Uri]::EscapeDataString($req.calendar))/events/$([Uri]::EscapeDataString($req.id))" | Out-Null
		}
		'delete-task' {
			Invoke-Google 'Delete' "$TaskApi/lists/$([Uri]::EscapeDataString($req.list))/tasks/$([Uri]::EscapeDataString($req.id))" | Out-Null
		}
		'sync' { }
		default { throw "Azione sconosciuta: $($req.action)" }
	}
}

# ------------------------------------------------------------------- main --

try {
	$req = Read-Request $RequestFile
	if ($req.action -eq 'login') { Invoke-Login; $req.action = 'sync' }
	$script:Access = Get-AccessToken
	Invoke-Action $req
	# Ogni azione si chiude con una sincronizzazione: la skin vede subito il risultato
	# senza dover lanciare un secondo processo.
	Invoke-Sync ([long]$req.from) ([long]$req.to)
	Write-Output 'OK'
} catch [AuthRequired] {
	Write-Output "AUTH $($_.Exception.Message)"
} catch {
	# Messaggio su una riga sola: Lua mostra solo l'ultima riga di stdout.
	$msg = ($_.Exception.Message -replace '\s+', ' ')
	if ($_.ErrorDetails.Message) {
		try { $msg = (($_.ErrorDetails.Message | ConvertFrom-Json).error.message) -replace '\s+', ' ' } catch { }
	}
	Write-Output "ERR $msg"
}
