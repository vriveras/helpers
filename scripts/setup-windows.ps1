# Windows Development Environment Setup Script
# PowerShell equivalent of setup-wsl.sh

# ── Self-elevate if not running as admin ─────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  ⚠  Not running as Administrator — requesting elevation..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "  ✗  Elevation cancelled or failed. Please run as Administrator." -ForegroundColor Red
        exit 1
    }
    exit 0
}

$ErrorActionPreference = 'Stop'

# ── Colors / Helpers ─────────────────────────────────────────────────────────
function Log     { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "→" -ForegroundColor Blue -NoNewline; Write-Host " $msg" }
function Ok      { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "✓" -ForegroundColor Green -NoNewline; Write-Host " $msg" }
function Warn    { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "⚠" -ForegroundColor Yellow -NoNewline; Write-Host "  $msg" }
function Fail    { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "✗" -ForegroundColor Red -NoNewline; Write-Host " $msg"; exit 1 }
function Section { param([string]$msg) Write-Host ""; Write-Host "┌─ $msg " -ForegroundColor Cyan -NoNewline; Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray }

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

Write-Host "  Setting up Vicente's Development Environment" -ForegroundColor DarkGray
Write-Host "  Windows · PowerShell · $(Get-Date -Format 'dddd, MMMM dd yyyy  HH:mm')" -ForegroundColor DarkGray
Write-Host ""

# ── Modern PowerShell (pwsh) ─────────────────────────────────────────────────
Section "PowerShell 7+"
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    $pwshVer = (pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') 2>$null
    Ok "PowerShell $pwshVer already installed"
} else {
    Log "Installing PowerShell 7 via winget..."
    winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Warn "winget install failed — trying MSI installer..."
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $msiUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.5.1-win-$arch.msi"
        $msiPath = "$env:TEMP\pwsh-install.msi"
        Log "Downloading from $msiUrl..."
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
        Log "Running MSI installer..."
        Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait
        Remove-Item $msiPath -ErrorAction SilentlyContinue
    }
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $pwshVer = (pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') 2>$null
        Ok "PowerShell $pwshVer installed"
    } else {
        Warn "PowerShell 7 installed — restart your terminal and re-run to use pwsh"
    }
}

# ── Directories ──────────────────────────────────────────────────────────────
Section "Directories"
Log "Creating ~/local workspace..."
$dirs = @("sources", "tools", "vault", "scratch")
foreach ($d in $dirs) {
    $path = Join-Path $HOME "local\$d"
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}
Ok "~/local/{$($dirs -join ', ')}"

# ── Git ──────────────────────────────────────────────────────────────────────
Section "Git"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Ok "git $(git --version)"
} else {
    Log "Installing Git..."
    winget install --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Ok "git $(git --version)"
}

Log "Setting up git tree alias..."
git config --global alias.tree "log --graph --pretty=format:'%C(yellow)%h%Creset%C(auto)%d%Creset %s %Cblue[%an]%Creset %Cgreen(%ar)%Creset' --abbrev-commit --all"
Ok "Alias ready — use: git tree"

# ── GitHub CLI ───────────────────────────────────────────────────────────────
Section "GitHub CLI"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Ok "$(gh --version | Select-Object -First 1)"
} else {
    Log "Installing GitHub CLI..."
    winget install --id GitHub.cli --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Ok "$(gh --version | Select-Object -First 1)"
}

# ── GitHub Copilot CLI ───────────────────────────────────────────────────────
Section "GitHub Copilot CLI"
Log "Installing gh copilot extension..."
try {
    gh extension install github/gh-copilot 2>$null
    Ok "gh copilot extension installed"
} catch {
    Warn "Skipped — run 'gh auth login' first, then 'gh extension install github/gh-copilot'"
}

# ── Rust ─────────────────────────────────────────────────────────────────────
Section "Rust"
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    Ok "$(rustc --version)  |  cargo $(cargo --version | ForEach-Object { ($_ -split ' ')[1] })"
} else {
    Log "Downloading rustup-init.exe..."
    $rustupPath = "$env:TEMP\rustup-init.exe"
    Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupPath -UseBasicParsing
    Log "Installing Rust toolchain..."
    & $rustupPath -y --no-modify-path
    Remove-Item $rustupPath -ErrorAction SilentlyContinue
    # Add cargo to PATH for this session
    $cargoBin = Join-Path $HOME ".cargo\bin"
    if ($env:Path -notlike "*$cargoBin*") { $env:Path = "$cargoBin;$env:Path" }
    Ok "$(rustc --version)  |  cargo $(cargo --version | ForEach-Object { ($_ -split ' ')[1] })"
}

# ── fnm + Node.js LTS ───────────────────────────────────────────────────────
Section "fnm + Node.js LTS"
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    Ok "fnm already installed"
} else {
    Log "Installing fnm (Fast Node Manager)..."
    winget install --id Schniz.fnm --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Initialize fnm for this session
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
    Log "Installing Node.js LTS..."
    fnm install --lts
    fnm use lts-latest
    fnm default lts-latest
    Ok "Node $(node --version)  |  npm $(npm --version)"
} else {
    Warn "fnm not found in PATH — restart terminal and re-run"
}

# ── Bun ──────────────────────────────────────────────────────────────────────
Section "Bun"
if (Get-Command bun -ErrorAction SilentlyContinue) {
    Ok "Bun $(bun --version) already installed"
} else {
    Log "Installing Bun..."
    irm bun.sh/install.ps1 | iex
    $bunBin = Join-Path $HOME ".bun\bin"
    if ($env:Path -notlike "*$bunBin*") { $env:Path = "$bunBin;$env:Path" }
    if (Get-Command bun -ErrorAction SilentlyContinue) {
        Ok "Bun $(bun --version)"
    } else {
        Warn "Bun installed — restart terminal to use"
    }
}

# ── .NET SDK (LTS) ───────────────────────────────────────────────────────────
Section ".NET SDK + Runtime"
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Ok ".NET SDK $(dotnet --version) already installed"
} else {
    Log "Downloading dotnet-install.ps1..."
    $dotnetInstall = "$env:TEMP\dotnet-install.ps1"
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstall -UseBasicParsing
    Log "Installing .NET SDK (LTS)..."
    & $dotnetInstall -Channel LTS
    Log "Installing .NET Runtime (LTS)..."
    & $dotnetInstall -Channel LTS -Runtime dotnet
    Remove-Item $dotnetInstall -ErrorAction SilentlyContinue
    $dotnetRoot = Join-Path $HOME ".dotnet"
    if ($env:Path -notlike "*$dotnetRoot*") { $env:Path = "$dotnetRoot;$dotnetRoot\tools;$env:Path" }
    Ok ".NET SDK $(dotnet --version)"
}

# ── pyenv-win ────────────────────────────────────────────────────────────────
Section "pyenv"
$pyenvRoot = Join-Path $HOME ".pyenv\pyenv-win"
if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    Ok "$(pyenv --version)"
} else {
    Log "Installing pyenv-win..."
    winget install --id pyenv-win.pyenv-win --source winget --accept-package-agreements --accept-source-agreements 2>$null
    if ($LASTEXITCODE -ne 0) {
        Log "winget failed — installing via pip..."
        pip install pyenv-win --target "$HOME\.pyenv" 2>$null
    }
    # Add pyenv to PATH for this session
    $pyenvBin = Join-Path $pyenvRoot "bin"
    $pyenvShims = Join-Path $pyenvRoot "shims"
    if (Test-Path $pyenvBin) {
        if ($env:Path -notlike "*$pyenvBin*") { $env:Path = "$pyenvBin;$pyenvShims;$env:Path" }
    }
    if (Get-Command pyenv -ErrorAction SilentlyContinue) {
        Ok "$(pyenv --version)"
    } else {
        Warn "pyenv-win installed — restart terminal to use"
    }
}

# ── Global npm Packages ─────────────────────────────────────────────────────
Section "Global npm Packages"
if (Get-Command node -ErrorAction SilentlyContinue) {
    if (Get-Command vite -ErrorAction SilentlyContinue) {
        Warn "Vite already installed — skipping"
    } else {
        Log "Installing Vite..."
        npm install -g vite --silent
    }
    if (Get-Command vite -ErrorAction SilentlyContinue) { Ok "Vite $(vite --version)" }

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Warn "Claude Code already installed — skipping"
    } else {
        Log "Installing Claude Code CLI..."
        npm install -g @anthropic-ai/claude-code --silent
    }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Ok "Claude Code $(claude --version 2>&1 | Select-Object -First 1)"
    }
} else {
    Warn "Node.js not available yet — skipping npm global installs (restart and re-run)"
}

# ── PowerShell Profile ───────────────────────────────────────────────────────
Section "PowerShell Profile"
Log "Configuring PowerShell profile..."

$marker = "# >>> windows-setup >>>"
$profileDir = Split-Path $PROFILE -Parent

# Write to both Windows PowerShell and pwsh profiles
$profiles = @($PROFILE)
$pwshProfile = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Microsoft.PowerShell_profile.ps1"
if ($pwshProfile -ne $PROFILE) { $profiles += $pwshProfile }

$profileBlock = @'

# >>> windows-setup >>>
# Rust
$cargoEnv = Join-Path $HOME ".cargo\bin"
if (Test-Path $cargoEnv) { $env:Path = "$cargoEnv;$env:Path" }

# fnm (Node.js)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
}

# Bun
$bunBin = Join-Path $HOME ".bun\bin"
if (Test-Path $bunBin) { $env:Path = "$bunBin;$env:Path" }

# .NET
$dotnetRoot = Join-Path $HOME ".dotnet"
if (Test-Path $dotnetRoot) {
    $env:DOTNET_ROOT = $dotnetRoot
    $env:Path = "$dotnetRoot;$dotnetRoot\tools;$env:Path"
}

# pyenv-win
$pyenvBin = Join-Path $HOME ".pyenv\pyenv-win\bin"
$pyenvShims = Join-Path $HOME ".pyenv\pyenv-win\shims"
if (Test-Path $pyenvBin) { $env:Path = "$pyenvBin;$pyenvShims;$env:Path" }

# Local tools
$localTools = Join-Path $HOME "local\tools"
if (Test-Path $localTools) { $env:Path = "$localTools;$env:Path" }

# Aliases
Set-Alias -Name gohome -Value { Set-Location ~ }
function yolo { claude --dangerously-skip-permissions @args }
function yoloresume { claude --resume --dangerously-skip-permissions @args }
# <<< windows-setup <<<
'@

foreach ($prof in $profiles) {
    $profDir = Split-Path $prof -Parent
    if (-not (Test-Path $profDir)) { New-Item -ItemType Directory -Path $profDir -Force | Out-Null }

    if (Test-Path $prof) {
        $content = Get-Content $prof -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Contains($marker)) {
            Warn "$prof — config block already present, skipped"
            continue
        }
    }

    Add-Content -Path $prof -Value $profileBlock
    Ok "$prof updated"
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║              Environment Ready!                      ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1." -ForegroundColor DarkGray -NoNewline; Write-Host "  Restart your terminal (or run: . `$PROFILE)"
Write-Host "  2." -ForegroundColor DarkGray -NoNewline; Write-Host "  gh auth login"
Write-Host "  3." -ForegroundColor DarkGray -NoNewline; Write-Host "  Consider running from pwsh (PowerShell 7) going forward"
Write-Host ""
Write-Host "  Finished: $(Get-Date -Format 'HH:mm')" -ForegroundColor DarkGray
Write-Host ""
