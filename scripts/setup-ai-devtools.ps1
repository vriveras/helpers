# AI Development Tools Setup Script (Windows + NVIDIA RTX 6000)
# CUDA, cuDNN, PyTorch, Triton, and WSL AI environment

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

# Resolve the directory this script lives in (robust against Invoke-Expression contexts)
if ($PSScriptRoot) {
    $ScriptDir = $PSScriptRoot
} elseif ($PSCommandPath) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
} else {
    # Running via iex (no file on disk) — download companion files from GitHub
    $ScriptDir = Join-Path $env:TEMP "helpers-setup-ai"
    if (-not (Test-Path $ScriptDir)) { New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null }
    $baseUrl = "https://raw.githubusercontent.com/vriveras/helpers/main/scripts"
    Write-Host "  " -NoNewline; Write-Host "→" -ForegroundColor Blue -NoNewline; Write-Host " Running via Invoke-Expression — downloading companion files..."
    try {
        Invoke-WebRequest -Uri "$baseUrl/setup-ai-wsl.sh" -OutFile (Join-Path $ScriptDir "setup-ai-wsl.sh") -UseBasicParsing
    } catch {
        # Will handle missing WSL script later
    }
}

# ── Log File ─────────────────────────────────────────────────────────────────
$logDir = Join-Path $HOME "local\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "setup-ai-devtools_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

              █████╗ ██╗    ██████╗ ███████╗██╗   ██╗
             ██╔══██╗██║    ██╔══██╗██╔════╝██║   ██║
             ███████║██║    ██║  ██║█████╗  ██║   ██║
           · ██╔══██║██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝
             ██║  ██║██║    ██████╔╝███████╗ ╚████╔╝
             ╚═╝  ╚═╝╚═╝    ╚═════╝ ╚══════╝  ╚═══╝

"@ -ForegroundColor Cyan

Write-Host "  Setting up Vicente's AI Development Environment" -ForegroundColor DarkGray
Write-Host "  Windows · NVIDIA RTX 6000 · $(Get-Date -Format 'dddd, MMMM dd yyyy  HH:mm')" -ForegroundColor DarkGray
Write-Host ""

# ── NVIDIA GPU Detection ─────────────────────────────────────────────────────
Section "NVIDIA GPU Detection"
$nvidiaSmiAvailable = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)
if ($nvidiaSmiAvailable) {
    try {
        $smiOutput = nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>$null
        if ($smiOutput) {
            $parts = $smiOutput.Split(',').Trim()
            $gpuName = $parts[0]
            $driverVer = $parts[1]
            Ok "GPU: $gpuName"
            Ok "Driver: $driverVer"
        }
        $cudaVer = (nvidia-smi 2>$null | Select-String "CUDA Version:" | ForEach-Object { ($_ -split "CUDA Version:\s*")[1].Trim() })
        if ($cudaVer) {
            Ok "CUDA (driver-reported): $cudaVer"
        }
    } catch {
        Warn "nvidia-smi found but failed to query GPU: $_"
    }
} else {
    Warn "nvidia-smi not found — NVIDIA driver may not be installed yet"
    Warn "Install the NVIDIA driver for RTX 6000 from https://www.nvidia.com/drivers/"
}

# ── NVIDIA GPU Driver ────────────────────────────────────────────────────────
Section "NVIDIA GPU Driver"
if ($nvidiaSmiAvailable) {
    $driverInfo = nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>$null
    if ($driverInfo) {
        Ok "NVIDIA driver $($driverInfo.Trim()) active (workstation GPU — managed via NVIDIA Enterprise drivers or Windows Update)"
    } else {
        Warn "Could not query driver version"
    }
} else {
    Warn "NVIDIA driver not detected — install from https://www.nvidia.com/drivers/ (select RTX 6000 / Ada Generation)"
    Warn "After installing the driver, re-run this script"
}

# ── CUDA Toolkit ─────────────────────────────────────────────────────────────
Section "CUDA Toolkit"
$cudaInstalled = $false
$cudaPath = $null

# Check if CUDA is already installed
if ($env:CUDA_PATH -and (Test-Path $env:CUDA_PATH)) {
    $cudaPath = $env:CUDA_PATH
    $cudaInstalled = $true
} else {
    # Search for CUDA installations
    $cudaBase = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
    if (Test-Path $cudaBase) {
        $cudaVersions = Get-ChildItem -Path $cudaBase -Directory | Sort-Object Name -Descending
        if ($cudaVersions) {
            $cudaPath = $cudaVersions[0].FullName
            $cudaInstalled = $true
        }
    }
}

if ($cudaInstalled) {
    $nvccPath = Join-Path $cudaPath "bin\nvcc.exe"
    if (Test-Path $nvccPath) {
        $nvccVer = & $nvccPath --version 2>$null | Select-String "release" | ForEach-Object { ($_ -split "release\s+")[1].TrimEnd(',') }
        Ok "CUDA Toolkit $nvccVer already installed at $cudaPath"
    } else {
        Ok "CUDA path found at $cudaPath (nvcc not in expected location)"
    }
} else {
    Log "Installing CUDA Toolkit via winget..."
    winget install --id Nvidia.CUDA --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>$null
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        # Refresh environment and find CUDA
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $cudaBase = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
        if (Test-Path $cudaBase) {
            $cudaVersions = Get-ChildItem -Path $cudaBase -Directory | Sort-Object Name -Descending
            if ($cudaVersions) {
                $cudaPath = $cudaVersions[0].FullName
                $env:CUDA_PATH = $cudaPath
                [System.Environment]::SetEnvironmentVariable("CUDA_PATH", $cudaPath, "Machine")
                $nvccPath = Join-Path $cudaPath "bin\nvcc.exe"
                if (Test-Path $nvccPath) {
                    $nvccVer = & $nvccPath --version 2>$null | Select-String "release" | ForEach-Object { ($_ -split "release\s+")[1].TrimEnd(',') }
                    Ok "CUDA Toolkit $nvccVer installed at $cudaPath"
                } else {
                    Ok "CUDA Toolkit installed at $cudaPath"
                }
            }
        } else {
            Warn "CUDA installed but path not found — restart terminal and re-run"
        }
    } else {
        Warn "CUDA Toolkit installation failed (winget exit code: $LASTEXITCODE)"
        Warn "Try manually: winget install --id Nvidia.CUDA --source winget"
    }
}

# ── cuDNN ────────────────────────────────────────────────────────────────────
Section "cuDNN"
$cudnnFound = $false

# Check if cuDNN is already in the CUDA toolkit path
if ($cudaPath) {
    $cudnnDlls = Get-ChildItem -Path (Join-Path $cudaPath "bin") -Filter "cudnn*.dll" -ErrorAction SilentlyContinue
    if ($cudnnDlls) {
        $cudnnFound = $true
        Ok "cuDNN libraries found in $cudaPath\bin ($($cudnnDlls.Count) DLLs)"
    }
}

# Check if cuDNN is installed via pip (nvidia-cudnn-cu12 package)
if (-not $cudnnFound -and (Get-Command python -ErrorAction SilentlyContinue)) {
    $cudnnPipPath = python -c "import importlib.util; spec = importlib.util.find_spec('nvidia.cudnn'); print(spec.submodule_search_locations[0] if spec else '')" 2>$null
    if ($cudnnPipPath -and (Test-Path $cudnnPipPath)) {
        $cudnnBin = Join-Path $cudnnPipPath "bin"
        if (Test-Path $cudnnBin) {
            $cudnnDlls = Get-ChildItem -Path $cudnnBin -Filter "cudnn*.dll" -ErrorAction SilentlyContinue
            if ($cudnnDlls) {
                $cudnnFound = $true
                Ok "cuDNN found via pip nvidia-cudnn-cu12 ($($cudnnDlls.Count) DLLs in $cudnnBin)"
            }
        }
    }
}

# Install cuDNN via pip if not found anywhere
if (-not $cudnnFound) {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Log "Installing cuDNN via pip (nvidia-cudnn-cu12)..."
        python -m pip install --quiet nvidia-cudnn-cu12 2>$null
        if ($LASTEXITCODE -eq 0) {
            $cudnnPipPath = python -c "import importlib.util; spec = importlib.util.find_spec('nvidia.cudnn'); print(spec.submodule_search_locations[0] if spec else '')" 2>$null
            if ($cudnnPipPath -and (Test-Path $cudnnPipPath)) {
                $cudnnBin = Join-Path $cudnnPipPath "bin"
                if (Test-Path $cudnnBin) {
                    # Add to current session PATH
                    $env:Path = "$cudnnBin;$env:Path"
                    Ok "cuDNN installed via pip and added to PATH ($cudnnBin)"
                } else {
                    Ok "nvidia-cudnn-cu12 installed (PyTorch will find it automatically)"
                }
            } else {
                Ok "nvidia-cudnn-cu12 installed (PyTorch will find it automatically)"
            }
        } else {
            Warn "pip install nvidia-cudnn-cu12 failed — PyTorch bundles cuDNN so this is non-blocking"
            Warn "For standalone CUDA dev: download from https://developer.nvidia.com/cudnn"
        }
    } else {
        Warn "Python not available yet — cuDNN will be installed with PyTorch libraries later"
    }
}

# ── Python Environment ───────────────────────────────────────────────────────
Section "Python Environment"
$pyenvAvailable = [bool](Get-Command pyenv -ErrorAction SilentlyContinue)
$pythonVersion = "3.11.9"

if ($pyenvAvailable) {
    # Check if target version is already installed
    $installedVersions = pyenv versions 2>$null
    if ($installedVersions -match $pythonVersion) {
        Ok "Python $pythonVersion already installed via pyenv"
    } else {
        Log "Installing Python $pythonVersion via pyenv..."
        pyenv install $pythonVersion 2>$null
        if ($LASTEXITCODE -eq 0) {
            Ok "Python $pythonVersion installed via pyenv"
        } else {
            Warn "pyenv install failed — check pyenv-win installation"
        }
    }
    Log "Setting pyenv global to $pythonVersion..."
    pyenv global $pythonVersion 2>$null
    pyenv rehash 2>$null
    # Refresh PATH for pyenv shims
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Warn "pyenv-win not found — run setup-windows.ps1 first to install pyenv-win"
    Warn "Checking for system Python as fallback..."
}

# Verify Python
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pyVer = python --version 2>$null
    Ok "$pyVer available"
} else {
    Warn "Python not found in PATH — install Python $pythonVersion and re-run"
}

# ── PyTorch + AI Libraries (Windows) ─────────────────────────────────────────
Section "PyTorch + AI Libraries (Windows)"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Warn "Python not available — skipping PyTorch installation"
} else {
    Log "Upgrading pip..."
    python -m pip install --upgrade pip --quiet 2>$null

    Log "Installing PyTorch with CUDA 12.4 support..."
    python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "PyTorch with CUDA 12.4 installed"
    } else {
        Warn "PyTorch installation may have had issues (exit code: $LASTEXITCODE)"
    }

    Log "Installing Hugging Face ecosystem and ML tools..."
    python -m pip install transformers accelerate bitsandbytes datasets evaluate safetensors tokenizers huggingface-hub --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "Hugging Face libraries installed"
    } else {
        Warn "Some Hugging Face packages may have failed (exit code: $LASTEXITCODE)"
    }

    Ok "Triton — skipped on Windows (Linux/WSL only, will be installed by setup-ai-wsl.sh)"

    Log "Installing build tools (ninja, packaging, wheel, setuptools)..."
    python -m pip install ninja packaging wheel setuptools --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "Build tools installed"
    } else {
        Warn "Some build tools may have failed"
    }

    # Verify PyTorch + CUDA
    Log "Verifying PyTorch CUDA availability..."
    $torchCheck = python -c "import torch; avail = torch.cuda.is_available(); dev = torch.cuda.get_device_name(0) if avail else 'N/A'; print('PyTorch ' + torch.__version__ + ', CUDA available: ' + str(avail) + ', Device: ' + dev)" 2>$null
    if ($torchCheck) {
        Ok $torchCheck
    } else {
        Warn "Could not verify PyTorch — try: python -c `"import torch; print(torch.cuda.is_available())`""
    }
}

# ── WSL CUDA/AI Development ──────────────────────────────────────────────────
Section "WSL CUDA/AI Development"
$wslAvailable = [bool](Get-Command wsl -ErrorAction SilentlyContinue)
if (-not $wslAvailable) {
    Warn "WSL not available — skipping WSL AI setup"
} else {
    # Check if Ubuntu is installed (wsl --list outputs UTF-16 with null bytes)
    $env:WSL_UTF8 = '1'
    $wslOutput = wsl --list --quiet 2>$null
    $wslDistros = @($wslOutput | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
    $ubuntuDistro = $wslDistros | Where-Object { $_ -match 'Ubuntu' } | Select-Object -First 1
    $ubuntuInstalled = [bool]$ubuntuDistro
    if ($ubuntuInstalled) {
        Log "Found WSL distro: $ubuntuDistro"
    }
    if (-not $ubuntuInstalled) {
        Warn "Ubuntu not found in WSL — install with: wsl --install -d Ubuntu"
    } else {
        # Determine the WSL script path — prefer the Windows repo path converted via wslpath
        $windowsWslScript = Join-Path $ScriptDir "setup-ai-wsl.sh"
        if (-not (Test-Path $windowsWslScript)) {
            # ScriptDir might be temp (iex mode) or repo root — check both
            $repoWslScript = Join-Path (Split-Path $ScriptDir -Parent) "scripts\setup-ai-wsl.sh"
            if (Test-Path $repoWslScript) { $windowsWslScript = $repoWslScript }
        }

        if (Test-Path $windowsWslScript) {
            # Convert Windows path to WSL path
            $winPathForWsl = $windowsWslScript -replace '\\', '/'
            $wslScriptResolved = (wsl -d $ubuntuDistro -- wslpath -u "$winPathForWsl" 2>$null)
            if ($LASTEXITCODE -ne 0 -or -not $wslScriptResolved) {
                # Fallback: construct /mnt/c/... path manually
                $driveLetter = $windowsWslScript.Substring(0, 1).ToLower()
                $remainder = $windowsWslScript.Substring(2) -replace '\\', '/'
                $wslScriptResolved = "/mnt/$driveLetter$remainder"
            }
            $wslScriptResolved = $wslScriptResolved.Trim()
            Log "Running setup-ai-wsl.sh via WSL (path: $wslScriptResolved)..."
            # Use sed to strip any CRLF, pipe to bash --login to ensure PATH is set
            wsl -d $ubuntuDistro -- bash --login -c "sed 's/\r$//' '$wslScriptResolved' | bash --login"
            if ($LASTEXITCODE -eq 0) {
                Ok "WSL AI setup completed successfully"
            } else {
                Warn "WSL AI setup exited with code $LASTEXITCODE — check output above"
            }
        } else {
            Warn "setup-ai-wsl.sh not found"
            Warn "Clone the helpers repo inside WSL:"
            Warn "  wsl -d Ubuntu"
            Warn "  git clone https://github.com/vriveras/helpers ~/local/sources/helpers"
            Warn "  bash ~/local/sources/helpers/scripts/setup-ai-wsl.sh"
        }
    }
}

# ── Verification ─────────────────────────────────────────────────────────────
Section "Verification"
Write-Host ""
Log "System verification summary:"
Write-Host ""

# nvidia-smi
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $smiShort = nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>$null
    if ($smiShort) {
        Ok "GPU: $($smiShort.Trim())"
    }
} else {
    Warn "nvidia-smi: not available"
}

# nvcc
if ($cudaPath) {
    $nvccExe = Join-Path $cudaPath "bin\nvcc.exe"
    if (Test-Path $nvccExe) {
        $nvccVer = & $nvccExe --version 2>$null | Select-String "release" | ForEach-Object { ($_ -split "release\s+")[1].TrimEnd(',') }
        Ok "nvcc: CUDA $nvccVer"
    }
} elseif (Get-Command nvcc -ErrorAction SilentlyContinue) {
    $nvccVer = nvcc --version 2>$null | Select-String "release" | ForEach-Object { ($_ -split "release\s+")[1].TrimEnd(',') }
    Ok "nvcc: CUDA $nvccVer"
} else {
    Warn "nvcc: not found in PATH"
}

# Python
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pyVer = python --version 2>$null
    Ok "Python: $pyVer"
} else {
    Warn "Python: not found"
}

# torch.cuda
if (Get-Command python -ErrorAction SilentlyContinue) {
    $cudaAvail = python -c "import torch; print('YES' if torch.cuda.is_available() else 'NO')" 2>$null
    if ($cudaAvail -eq "YES") {
        Ok "torch.cuda.is_available(): True"
    } elseif ($cudaAvail -eq "NO") {
        Warn "torch.cuda.is_available(): False — CUDA may need restart or driver update"
    } else {
        Warn "torch not importable — verify installation"
    }
}

# WSL CUDA check
if ($wslAvailable -and $ubuntuInstalled) {
    $wslNvidiaSmi = wsl -d $ubuntuDistro -- nvidia-smi --query-gpu=name --format=csv,noheader 2>$null
    if ($LASTEXITCODE -eq 0 -and $wslNvidiaSmi) {
        Ok "WSL CUDA: $($wslNvidiaSmi.Trim()) accessible"
    } else {
        Warn "WSL CUDA: not accessible (may need WSL restart)"
    }
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host @"

  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║          AI Environment Ready!                       ║
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
Write-Host "  1." -ForegroundColor DarkGray -NoNewline; Write-Host "  Restart your terminal to pick up PATH changes"
Write-Host "  2." -ForegroundColor DarkGray -NoNewline; Write-Host "  Verify GPU: " -NoNewline; Write-Host "python -c `"import torch; print(torch.cuda.is_available())`"" -ForegroundColor Cyan
Write-Host "  3." -ForegroundColor DarkGray -NoNewline; Write-Host "  In WSL: " -NoNewline; Write-Host "bash ~/local/sources/helpers/scripts/setup-ai-wsl.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Log file: $logFile" -ForegroundColor DarkGray
Write-Host "  Finished: $(Get-Date -Format 'HH:mm')" -ForegroundColor DarkGray
Write-Host ""

Stop-Transcript | Out-Null
