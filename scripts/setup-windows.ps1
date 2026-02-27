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

# ── Log File ─────────────────────────────────────────────────────────────────
$logDir = Join-Path $HOME "local\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "setup-windows_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile -Append | Out-Null

# Summary tracking
$script:summary = [System.Collections.ArrayList]::new()
function Add-Summary { param([string]$icon, [string]$section, [string]$msg) $script:summary.Add([PSCustomObject]@{ Icon=$icon; Section=$section; Message=$msg }) | Out-Null }

# ── Colors / Helpers ─────────────────────────────────────────────────────────
function Log     { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "→" -ForegroundColor Blue -NoNewline; Write-Host " $msg" }
function Ok      { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "✓" -ForegroundColor Green -NoNewline; Write-Host " $msg"; Add-Summary "✓" $script:currentSection $msg }
function Warn    { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "⚠" -ForegroundColor Yellow -NoNewline; Write-Host "  $msg"; Add-Summary "⚠" $script:currentSection $msg }
function Fail    { param([string]$msg) Write-Host "  " -NoNewline; Write-Host "✗" -ForegroundColor Red -NoNewline; Write-Host " $msg"; Add-Summary "✗" $script:currentSection $msg; exit 1 }
function Section { param([string]$msg) Write-Host ""; Write-Host "┌─ $msg " -ForegroundColor Cyan -NoNewline; Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray; $script:currentSection = $msg }

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
Section "PowerShell 7+ (latest)"
$pwshInstalled = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$pwshNeedsWork = $true

if ($pwshInstalled) {
    Log "Upgrading PowerShell 7 via winget..."
    winget upgrade --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements 2>$null
    # Exit code 0 = upgraded, -1978335189 (0x8A150013) = no update available — both are fine
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { $pwshNeedsWork = $false }
} else {
    Log "Installing PowerShell 7 via winget..."
    winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { $pwshNeedsWork = $false }
}

if ($pwshNeedsWork) {
    Warn "winget failed — trying GitHub MSI installer..."
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    # Fetch the latest release tag from GitHub API
    try {
        $latestRelease = (Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest").tag_name -replace '^v', ''
        Log "Latest release: $latestRelease"
    } catch {
        $latestRelease = "7.5.1"
        Warn "Could not query GitHub API — falling back to v$latestRelease"
    }
    $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$latestRelease/PowerShell-$latestRelease-win-$arch.msi"
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
    Ok "PowerShell $pwshVer (latest)"
} else {
    Warn "PowerShell 7 installed — restart your terminal and re-run to use pwsh"
}

# ── WSL ──────────────────────────────────────────────────────────────────────
Section "Windows Subsystem for Linux"
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
$vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

if ($wslFeature.State -eq 'Enabled' -and $vmPlatform.State -eq 'Enabled') {
    Ok "WSL and Virtual Machine Platform already enabled"
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $wslVer = (wsl --version 2>$null | Select-Object -First 1)
        if ($wslVer) { Ok "$wslVer" }
    }
} else {
    Log "Enabling WSL and Virtual Machine Platform features..."
    $needsReboot = $false

    if ($wslFeature.State -ne 'Enabled') {
        Log "Enabling Microsoft-Windows-Subsystem-Linux..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
        $needsReboot = $true
    }

    if ($vmPlatform.State -ne 'Enabled') {
        Log "Enabling VirtualMachinePlatform..."
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
        $needsReboot = $true
    }

    Log "Setting WSL default version to 2..."
    wsl --set-default-version 2 2>$null

    Log "Updating WSL kernel..."
    wsl --update 2>$null

    if ($needsReboot) {
        Warn "WSL enabled — a REBOOT is required to finish setup"
    } else {
        Ok "WSL features enabled"
    }
}

# ── VS Code ─────────────────────────────────────────────────────────────────
Section "Visual Studio Code"
if (Get-Command code -ErrorAction SilentlyContinue) {
    $codeVer = (code --version 2>$null | Select-Object -First 1)
    Ok "VS Code $codeVer already installed"
} else {
    Log "Installing Visual Studio Code..."
    winget install --id Microsoft.VisualStudioCode --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $codeVer = (code --version 2>$null | Select-Object -First 1)
        Ok "VS Code $codeVer installed"
    } else {
        Warn "VS Code installed — restart terminal to use 'code' command"
    }
}

# ── Visual Studio Enterprise ────────────────────────────────────────────────
Section "Visual Studio Enterprise"
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstalled = $false
if (Test-Path $vsWhere) {
    $vsPath = & $vsWhere -products 'Microsoft.VisualStudio.Product.Enterprise' -latest -property installationPath 2>$null
    if ($vsPath) { $vsInstalled = $true }
}

# Workload IDs
$workloads = @(
    "Microsoft.VisualStudio.Workload.NativeDesktop",     # C++ / CMake
    "Microsoft.VisualStudio.Workload.ManagedDesktop",     # C# / .NET
    "Microsoft.VisualStudio.Workload.NetWeb",             # ASP.NET / Web
    "Microsoft.VisualStudio.Workload.NativeGame"          # Windows Development (DirectX, Win32)
)
# Include the CMake component explicitly
$components = @(
    "Microsoft.VisualStudio.Component.VC.CMake.Project"
)

if ($vsInstalled) {
    $vsVer = & $vsWhere -products 'Microsoft.VisualStudio.Product.Enterprise' -latest -property catalog_productDisplayVersion 2>$null
    Ok "Visual Studio Enterprise $vsVer already installed"
    Log "Ensuring required workloads are present (modify)..."
    $modifyArgs = @("modify", "--installPath", $vsPath, "--passive", "--norestart")
    foreach ($wl in $workloads) { $modifyArgs += "--add"; $modifyArgs += $wl }
    foreach ($comp in $components) { $modifyArgs += "--add"; $modifyArgs += $comp }
    $installer = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
    if (Test-Path $installer) {
        Log "Running VS Installer modify — a progress window will appear..."
        $proc = Start-Process -FilePath $installer -ArgumentList $modifyArgs -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            Ok "Workloads verified / updated"
        } else {
            Warn "VS Installer exited with code $($proc.ExitCode) — open Visual Studio Installer to verify workloads"
        }
    } else {
        Warn "VS Installer not found — open Visual Studio Installer manually to add workloads"
    }
} else {
    Log "Installing Visual Studio Enterprise with workloads (this will take a while)..."
    $bootstrapperUrl = "https://aka.ms/vs/17/release/vs_enterprise.exe"
    $bootstrapperPath = "$env:TEMP\vs_enterprise.exe"
    Log "Downloading VS Enterprise bootstrapper..."
    Invoke-WebRequest -Uri $bootstrapperUrl -OutFile $bootstrapperPath -UseBasicParsing
    $installArgs = @("--passive", "--wait", "--norestart")
    foreach ($wl in $workloads) { $installArgs += "--add"; $installArgs += $wl }
    foreach ($comp in $components) { $installArgs += "--add"; $installArgs += $comp }
    $installArgs += "--includeRecommended"
    Log "Running installer — a progress window will appear (this may take 15-30+ minutes)..."
    $proc = Start-Process -FilePath $bootstrapperPath -ArgumentList $installArgs -Wait -PassThru
    Remove-Item $bootstrapperPath -ErrorAction SilentlyContinue
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        # 3010 = success but reboot required
        if (Test-Path $vsWhere) {
            $vsVer = & $vsWhere -products 'Microsoft.VisualStudio.Product.Enterprise' -latest -property catalog_productDisplayVersion 2>$null
            Ok "Visual Studio Enterprise $vsVer installed"
        } else {
            Ok "Visual Studio Enterprise installed — restart to complete"
        }
        if ($proc.ExitCode -eq 3010) { Warn "A reboot is required to complete VS installation" }
    } else {
        Warn "VS installer exited with code $($proc.ExitCode) — open Visual Studio Installer to verify"
    }
}

# ── Oh My Posh ──────────────────────────────────────────────────────────────
Section "Oh My Posh"
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Ok "Oh My Posh $(oh-my-posh --version) already installed"
} else {
    Log "Installing Oh My Posh..."
    winget install --id JanDeDobbeleer.OhMyPosh --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Ok "Oh My Posh $(oh-my-posh --version) installed"
    } else {
        Warn "Oh My Posh installed — restart terminal to use"
    }
}

# Install a Nerd Font for Oh My Posh icons
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Log "Installing Meslo Nerd Font (recommended for Oh My Posh)..."
    try {
        oh-my-posh font install Meslo 2>$null
        Ok "Meslo Nerd Font installed — set it as your terminal font"
    } catch {
        Warn "Font install skipped — run 'oh-my-posh font install Meslo' manually"
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
    Log "Installing Bun via winget..."
    winget install --id Oven-sh.Bun --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
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
    Log "Installing pyenv-win via installer script..."
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "$env:TEMP\install-pyenv-win.ps1"
        & "$env:TEMP\install-pyenv-win.ps1"
        Remove-Item "$env:TEMP\install-pyenv-win.ps1" -ErrorAction SilentlyContinue
    } catch {
        Warn "pyenv-win install script failed: $_"
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

# Oh My Posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh | Invoke-Expression
}

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

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌─ Setup Summary " -ForegroundColor Cyan -NoNewline; Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$okCount = ($script:summary | Where-Object { $_.Icon -eq "✓" }).Count
$warnCount = ($script:summary | Where-Object { $_.Icon -eq "⚠" }).Count
$failCount = ($script:summary | Where-Object { $_.Icon -eq "✗" }).Count

foreach ($entry in $script:summary) {
    $color = switch ($entry.Icon) { "✓" { "Green" } "⚠" { "Yellow" } "✗" { "Red" } default { "White" } }
    Write-Host "  $($entry.Icon)" -ForegroundColor $color -NoNewline
    Write-Host " [$($entry.Section)]" -ForegroundColor DarkGray -NoNewline
    Write-Host " $($entry.Message)"
}

Write-Host ""
Write-Host "  Totals: " -NoNewline
Write-Host "$okCount passed" -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host "$warnCount warnings" -ForegroundColor Yellow -NoNewline
Write-Host ", " -NoNewline
Write-Host "$failCount failed" -ForegroundColor Red
Write-Host ""

Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1." -ForegroundColor DarkGray -NoNewline; Write-Host "  Restart your terminal (or run: . `$PROFILE)"
Write-Host "  2." -ForegroundColor DarkGray -NoNewline; Write-Host "  gh auth login"
Write-Host "  3." -ForegroundColor DarkGray -NoNewline; Write-Host "  Set terminal font to 'MesloLGM Nerd Font' for Oh My Posh icons"
Write-Host "  4." -ForegroundColor DarkGray -NoNewline; Write-Host "  wsl --install Ubuntu  (if WSL distro not yet installed)"
Write-Host "  5." -ForegroundColor DarkGray -NoNewline; Write-Host "  Consider running from pwsh (PowerShell 7) going forward"
Write-Host ""
Write-Host "  Log file: $logFile" -ForegroundColor DarkGray
Write-Host "  Finished: $(Get-Date -Format 'HH:mm')" -ForegroundColor DarkGray
Write-Host ""

Stop-Transcript | Out-Null
