# Launch Microsoft Edge on Windows with CDP remote debugging enabled
$ErrorActionPreference = 'Stop'

# ── Helpers ──────────────────────────────────────────────────────────────────
function Log     { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "→" -ForegroundColor Blue -NoNewline; Write-Host " $msg" }
function Ok      { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "✓" -ForegroundColor Green -NoNewline; Write-Host " $msg" }
function Warn    { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "⚠" -ForegroundColor Yellow -NoNewline; Write-Host "  $msg" }
function Fail    { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "✗" -ForegroundColor Red -NoNewline; Write-Host " $msg"; exit 1 }
function Section { param([string]$msg) Write-Host ""; Write-Host "┌─ $msg " -ForegroundColor Cyan -NoNewline; Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray }

# ── Config ───────────────────────────────────────────────────────────────────
$CdpPort = 9222
$UserDataDir = Join-Path $env:USERPROFILE "EdgePlaywright"

$EdgeCandidates = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)

# ── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Host @"

  ██╗   ██╗██████╗ ██╗██╗   ██╗███████╗██████╗  █████╗ ███████╗
  ██║   ██║██╔══██╗██║██║   ██║██╔════╝██╔══██╗██╔══██╗██╔════╝
  ██║   ██║██████╔╝██║██║   ██║█████╗  ██████╔╝███████║███████╗
  ╚██╗ ██╔╝██╔══██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██╔══██║╚════██║
   ╚████╔╝ ██║  ██║██║ ╚████╔╝ ███████╗██║  ██║██║  ██║███████║
    ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝

                    ██████╗ ███████╗██╗   ██╗
                    ██╔══██╗██╔════╝██║   ██║
                    ██║  ██║█████╗  ██║   ██║
                  · ██║  ██║██╔══╝  ╚██╗ ██╔╝
                    ██████╔╝███████╗ ╚████╔╝
                    ╚═════╝ ╚══════╝  ╚═══╝

"@ -ForegroundColor Cyan

Write-Host "  Launching Edge with CDP remote debugging · port $CdpPort" -ForegroundColor DarkGray
Write-Host ""

# ── Already running? ─────────────────────────────────────────────────────────
Section "Checking Edge"
try {
    $versionJson = Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 2 -ErrorAction Stop
    Ok "Edge is already running in CDP mode: $($versionJson.Browser)"
    Ok "CDP endpoint ready at http://127.0.0.1:$CdpPort"
    Write-Host ""
    exit 0
} catch {
    Log "Edge not running on port $CdpPort — will launch now"
}

# ── Find Edge executable ─────────────────────────────────────────────────────
Section "Locating Edge"
$edgeExe = $null
foreach ($candidate in $EdgeCandidates) {
    if (Test-Path $candidate) {
        $edgeExe = $candidate
        break
    }
}

if (-not $edgeExe) { Fail "Could not find msedge.exe. Is Edge installed on Windows?" }
Ok "Found Edge: $edgeExe"

# ── Launch Edge ──────────────────────────────────────────────────────────────
Section "Launching Edge"
Log "Starting Edge with remote debugging on port $CdpPort..."
Log "Profile: $UserDataDir"

Start-Process -FilePath $edgeExe -ArgumentList @(
    "--remote-debugging-port=$CdpPort"
    "--user-data-dir=$UserDataDir"
    "--no-first-run"
    "--no-default-browser-check"
)

# ── Wait for CDP to be ready ─────────────────────────────────────────────────
Section "Waiting for CDP"
Log "Waiting for Edge to be ready..."
$maxAttempts = 30
for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
        $versionJson = Invoke-RestMethod -Uri "http://127.0.0.1:$CdpPort/json/version" -TimeoutSec 2 -ErrorAction Stop
        Ok "Edge ready: $($versionJson.Browser)"
        Ok "CDP endpoint: http://127.0.0.1:$CdpPort"
        break
    } catch {
        Write-Host "`r  attempt $i/$maxAttempts..." -ForegroundColor DarkGray -NoNewline
        Start-Sleep -Milliseconds 500
        if ($i -eq $maxAttempts) {
            Write-Host ""
            Fail "Edge did not become ready in time. Check if Windows firewall is blocking port $CdpPort."
        }
    }
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║           Edge is ready for Playwright!              ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "  CDP endpoint: http://127.0.0.1:$CdpPort" -ForegroundColor DarkGray
Write-Host "  Profile dir:  $UserDataDir" -ForegroundColor DarkGray
Write-Host ""
