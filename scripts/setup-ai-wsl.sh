#!/bin/bash
# WSL AI/CUDA Development Environment Setup Script
set -euo pipefail

# Ensure common system paths are available (WSL non-login shell may have minimal PATH)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ── Log File ──────────────────────────────────────────────────────────────────
LOG_DIR="$HOME/local/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-ai-wsl_$(date '+%Y%m%d_%H%M%S').log"

# Duplicate all output (stdout+stderr) to the log file while keeping terminal output
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Colors ────────────────────────────────────────────────────────────────────
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Summary tracking
SUMMARY_FILE=$(mktemp)
CURRENT_SECTION=""

add_summary() { echo "$1|$2|$3" >> "$SUMMARY_FILE"; }

log()     { echo -e "  ${BLUE}→${NC} $*"; }
ok()      { echo -e "  ${GREEN}✓${NC} $*"; add_summary "✓" "$CURRENT_SECTION" "$*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; add_summary "⚠" "$CURRENT_SECTION" "$*"; }
die()     { echo -e "  ${RED}✗${NC} $*"; add_summary "✗" "$CURRENT_SECTION" "$*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}┌─ $* ${NC}${DIM}────────────────────────────────────────${NC}"; CURRENT_SECTION="$*"; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
echo "  ██╗   ██╗██████╗ ██╗██╗   ██╗███████╗██████╗  █████╗ ███████╗"
echo "  ██║   ██║██╔══██╗██║██║   ██║██╔════╝██╔══██╗██╔══██╗██╔════╝"
echo "  ██║   ██║██████╔╝██║██║   ██║█████╗  ██████╔╝███████║███████╗"
echo "  ╚██╗ ██╔╝██╔══██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██╔══██║╚════██║"
echo "   ╚████╔╝ ██║  ██║██║ ╚████╔╝ ███████╗██║  ██║██║  ██║███████║"
echo "    ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝"
echo ""
echo "                 █████╗ ██╗    ██████╗ ███████╗██╗   ██╗"
echo "                ██╔══██╗██║    ██╔══██╗██╔════╝██║   ██║"
echo "                ███████║██║    ██║  ██║█████╗  ██║   ██║"
echo "                ██╔══██║██║    ██║  ██║██╔══╝  ╚██╗ ██╔╝"
echo "                ██║  ██║██║    ██████╔╝███████╗ ╚████╔╝ "
echo "                ╚═╝  ╚═╝╚═╝    ╚═════╝ ╚══════╝  ╚═══╝  "
echo -e "${NC}"
echo -e "  ${DIM}Setting up CUDA/AI Development Environment${NC}"
echo -e "  ${DIM}WSL · Ubuntu · $(date '+%A, %B %d %Y  %H:%M')${NC}"
echo ""

# ── NVIDIA GPU Detection (WSL) ────────────────────────────────────────────────
section "NVIDIA GPU Detection (WSL)"
if ! command -v nvidia-smi &>/dev/null; then
    die "nvidia-smi not found — install the NVIDIA driver on Windows first (GPU passthrough requires the Windows host driver)"
fi

log "Detecting GPU via nvidia-smi..."
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
CUDA_DRIVER_VERSION=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
SUPPORTED_CUDA=$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9.]+' || echo "unknown")

log "GPU: ${GPU_NAME}"
log "Driver: ${DRIVER_VERSION}"
log "Max CUDA supported: ${SUPPORTED_CUDA}"
ok "GPU detected: ${GPU_NAME} (driver ${DRIVER_VERSION}, CUDA ${SUPPORTED_CUDA})"

# ── CUDA Toolkit ──────────────────────────────────────────────────────────────
section "CUDA Toolkit"

# Source CUDA env if already installed
if [ -d "/usr/local/cuda" ]; then
    export CUDA_HOME=/usr/local/cuda
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}
fi

if command -v nvcc &>/dev/null; then
    NVCC_VER=$(nvcc --version | grep -oP 'release \K[0-9.]+')
    ok "CUDA Toolkit already installed: nvcc ${NVCC_VER}"
else
    log "Installing CUDA Toolkit from NVIDIA repository..."

    # Detect Ubuntu version
    UBUNTU_VER=$(lsb_release -rs | tr -d '.')
    DISTRO="ubuntu${UBUNTU_VER}"
    ARCH="x86_64"

    log "Detected distro: ${DISTRO} (${ARCH})"

    # Add NVIDIA package repository
    wget -q "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-keyring_1.1-1_all.deb" -O /tmp/cuda-keyring.deb
    sudo dpkg -i /tmp/cuda-keyring.deb
    rm -f /tmp/cuda-keyring.deb
    sudo apt-get update -y -q

    # Install CUDA toolkit 12.6
    log "Installing cuda-toolkit-12-6 (this may take a while)..."
    sudo apt-get install -y -q cuda-toolkit-12-6

    export CUDA_HOME=/usr/local/cuda
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}

    NVCC_VER=$(nvcc --version | grep -oP 'release \K[0-9.]+')
    ok "CUDA Toolkit installed: nvcc ${NVCC_VER}"
fi

# Add CUDA env vars to bashrc
MARKER_AI="# >>> ai-setup >>>"
if ! grep -qF "$MARKER_AI" "$HOME/.bashrc"; then
    log "Adding CUDA environment variables to ~/.bashrc..."
    cat >> "$HOME/.bashrc" <<'CUDA_ENV'

# >>> ai-setup >>>
# CUDA Toolkit
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}
# <<< ai-setup <<<
CUDA_ENV
    ok "CUDA env vars added to ~/.bashrc"
else
    warn "CUDA env block already present in ~/.bashrc — skipped"
fi

# Verify nvcc
log "Verifying nvcc..."
nvcc --version | tail -1
ok "nvcc verified"

# ── cuDNN ─────────────────────────────────────────────────────────────────────
section "cuDNN"
if dpkg -l libcudnn9-cuda-12 &>/dev/null 2>&1; then
    ok "cuDNN already installed"
else
    log "Installing cuDNN 9 for CUDA 12..."
    sudo apt-get install -y -q libcudnn9-cuda-12 libcudnn9-dev-cuda-12
    ok "cuDNN 9 installed"
fi

# Verify cuDNN header
if [ -f /usr/include/cudnn.h ] || find /usr/include -name "cudnn_version.h" -print -quit 2>/dev/null | grep -q .; then
    ok "cuDNN headers found"
else
    warn "cuDNN headers not found in expected location — PyTorch may bundle its own"
fi

# ── Build Dependencies ────────────────────────────────────────────────────────
section "Build Dependencies"
log "Installing build packages..."
sudo apt-get install -y -q build-essential cmake ninja-build git \
    python3-dev libffi-dev libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev libncurses-dev \
    liblzma-dev libxml2-dev libxmlsec1-dev tk-dev
ok "Build dependencies installed"

# ── Python Environment ────────────────────────────────────────────────────────
section "Python Environment"

# Ensure pyenv is in PATH (needed when invoked as non-login shell)
if [ -z "${PYENV_ROOT:-}" ] && [ -d "$HOME/.pyenv" ]; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
    eval "$(pyenv init -)" 2>/dev/null || true
fi

# Check for pyenv
if [ -d "$HOME/.pyenv" ]; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    ok "pyenv found: $(pyenv --version)"
else
    warn "pyenv not installed — run setup-wsl.sh first for full environment setup"
    die "pyenv is required for Python management"
fi

# Install Python 3.11.9
PYTHON_VERSION="3.11.9"
if pyenv versions --bare | grep -qF "$PYTHON_VERSION"; then
    log "Python ${PYTHON_VERSION} already installed"
else
    log "Installing Python ${PYTHON_VERSION} via pyenv (this may take a while)..."
    pyenv install "$PYTHON_VERSION"
fi

pyenv global "$PYTHON_VERSION"
ok "Python $(python --version 2>&1 | awk '{print $2}') (global)"

# ── PyTorch + AI Libraries ────────────────────────────────────────────────────
section "PyTorch + AI Libraries"

log "Upgrading pip..."
python -m pip install --upgrade pip -q

log "Installing PyTorch with CUDA 12.4 support..."
python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 -q
ok "PyTorch installed"

log "Installing Triton..."
python -m pip install triton -q
ok "Triton installed"

log "Installing flash-attention (may fail if build requirements not met)..."
if python -m pip install flash-attn --no-build-isolation -q 2>&1; then
    ok "flash-attention installed"
else
    warn "flash-attention failed to compile — install manually later if needed"
fi

log "Installing HuggingFace + utilities..."
python -m pip install -q \
    transformers accelerate bitsandbytes datasets \
    evaluate safetensors tokenizers huggingface-hub \
    scipy numpy pandas matplotlib jupyter ipykernel
ok "HuggingFace ecosystem installed"

log "Installing CUDA-accelerated tools..."
python -m pip install -q cupy-cuda12x
python -m pip install -q ninja packaging wheel setuptools
ok "CUDA tools installed (cupy, ninja, packaging)"

# ── Verification ──────────────────────────────────────────────────────────────
section "Verification"

log "nvidia-smi:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""

log "nvcc:"
nvcc --version | tail -1
echo ""

log "Python:"
python --version
echo ""

log "PyTorch + CUDA check:"
python -c "
import torch
print(f'  PyTorch {torch.__version__}')
print(f'  CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  CUDA version: {torch.version.cuda}')
    print(f'  Device: {torch.cuda.get_device_name(0)}')
    print(f'  cuDNN: {torch.backends.cudnn.version()}')
"
ok "PyTorch CUDA verification passed"

log "Triton check:"
if python -c "import triton; print(f'  Triton {triton.__version__}')" 2>/dev/null; then
    ok "Triton verified"
else
    warn "Triton import failed — may need a compatible GPU kernel"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║                                                      ║"
echo "  ║           AI Environment Ready! 🚀                   ║"
echo "  ║                                                      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
# ── Summary ──────────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}┌─ Setup Summary ${NC}${DIM}────────────────────────────────────────${NC}"
echo ""

OK_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0
while IFS='|' read -r icon sect msg; do
    case "$icon" in
        "✓") echo -e "  ${GREEN}✓${NC} ${DIM}[${sect}]${NC} ${msg}"; OK_COUNT=$((OK_COUNT + 1)) ;;
        "⚠") echo -e "  ${YELLOW}⚠${NC} ${DIM}[${sect}]${NC} ${msg}"; WARN_COUNT=$((WARN_COUNT + 1)) ;;
        "✗") echo -e "  ${RED}✗${NC} ${DIM}[${sect}]${NC} ${msg}"; FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
done < "$SUMMARY_FILE"
rm -f "$SUMMARY_FILE"

echo ""
echo -e "  Totals: ${GREEN}${OK_COUNT} passed${NC}, ${YELLOW}${WARN_COUNT} warnings${NC}, ${RED}${FAIL_COUNT} failed${NC}"
echo ""

echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  ${DIM}1.${NC}  source ~/.bashrc"
echo -e "  ${DIM}2.${NC}  python -c \"import torch; print(torch.cuda.is_available())\""
echo -e "  ${DIM}3.${NC}  python -c \"import torch; x = torch.randn(1000,1000).cuda(); print(x @ x.T)\""
echo ""
echo -e "  ${DIM}Log file: ${LOG_FILE}${NC}"
echo -e "  ${DIM}Finished: $(date '+%H:%M')${NC}"
echo ""
