#!/bin/bash
# WSL Development Environment Setup Script
set -euo pipefail

# ── Log File ──────────────────────────────────────────────────────────────────
LOG_DIR="$HOME/local/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-wsl_$(date '+%Y%m%d_%H%M%S').log"

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
echo "                    ██████╗ ███████╗██╗   ██╗"
echo "                    ██╔══██╗██╔════╝██║   ██║"
echo "                    ██║  ██║█████╗  ██║   ██║"
echo "                  · ██║  ██║██╔══╝  ╚██╗ ██╔╝"
echo "                    ██████╔╝███████╗ ╚████╔╝ "
echo "                    ╚═════╝ ╚══════╝  ╚═══╝  "
echo -e "${NC}"
echo -e "  ${DIM}Setting up Vicente's Development Environment${NC}"
echo -e "  ${DIM}WSL2 · Ubuntu · $(date '+%A, %B %d %Y  %H:%M')${NC}"
echo ""

# ── WSL Interop ───────────────────────────────────────────────────────────────
section "WSL Interop"
log "Configuring Windows interop..."
if ! grep -qs '\[interop\]' /etc/wsl.conf; then
    sudo tee -a /etc/wsl.conf <<'EOF'
[interop]
enabled=true
appendWindowsPath=true
EOF
    ok "WSL interop enabled — run 'wsl --shutdown' from Windows to apply"
else
    warn "Already configured — skipped"
fi

# ── .wslconfig (Windows host) ─────────────────────────────────────────────────
section "Windows WSL Resource Limits & Networking"

# Locate the Windows user profile
WIN_USER=$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r\n')
WSLCONFIG="/mnt/c/Users/${WIN_USER}/.wslconfig"

log "Windows user: ${WIN_USER}"
log "Target file:  ${WSLCONFIG}"
echo ""

# Show current values if file exists
CURRENT_MEM=""
CURRENT_CPU=""
if [ -f "$WSLCONFIG" ]; then
    CURRENT_MEM=$(grep -i '^memory' "$WSLCONFIG" 2>/dev/null | cut -d= -f2 | tr -d ' ' || true)
    CURRENT_CPU=$(grep -i '^processors' "$WSLCONFIG" 2>/dev/null | cut -d= -f2 | tr -d ' ' || true)
fi

# Prompt for memory
if [ -n "$CURRENT_MEM" ]; then
    echo -e "  ${BOLD}Memory limit${NC} ${DIM}(current: ${CURRENT_MEM})${NC}"
else
    echo -e "  ${BOLD}Memory limit${NC} ${DIM}(e.g. 8GB, 16GB, 32GB)${NC}"
fi
echo -n "  Enter value [default: 8GB]: "
read -r INPUT_MEM
WSL_MEMORY="${INPUT_MEM:-8GB}"

# Prompt for CPU cores
if [ -n "$CURRENT_CPU" ]; then
    echo -e "  ${BOLD}CPU cores${NC} ${DIM}(current: ${CURRENT_CPU})${NC}"
else
    echo -e "  ${BOLD}CPU cores${NC} ${DIM}(e.g. 4, 8, 16)${NC}"
fi
echo -n "  Enter value [default: 4]: "
read -r INPUT_CPU
WSL_PROCESSORS="${INPUT_CPU:-4}"

echo ""
log "Writing .wslconfig → memory=${WSL_MEMORY}, processors=${WSL_PROCESSORS}, networkingMode=mirrored"

cat > "$WSLCONFIG" <<EOF
[wsl2]
memory=${WSL_MEMORY}
processors=${WSL_PROCESSORS}

[experimental]
networkingMode=mirrored
EOF

ok "memory=${WSL_MEMORY}  |  processors=${WSL_PROCESSORS}  |  networkingMode=mirrored"
warn "Run 'wsl --shutdown' from Windows PowerShell to apply these changes"

# ── Directories ───────────────────────────────────────────────────────────────
section "Directories"
log "Creating ~/local workspace..."
mkdir -p ~/local/{sources,tools,vault,scratch}
ok "~/local/{sources, tools, vault, scratch}"

# ── System Update & Base Deps ─────────────────────────────────────────────────
section "System Packages"
log "Updating apt..."
sudo apt-get update -y -q
sudo apt-get upgrade -y -q
log "Installing build essentials and dev libraries..."
sudo apt-get install -y -q \
    curl wget git build-essential cmake unzip zip \
    apt-transport-https ca-certificates gnupg lsb-release software-properties-common \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
ok "git $(git --version | awk '{print $3}')  |  cmake $(cmake --version | head -1 | awk '{print $3}')"

# ── GitHub CLI ────────────────────────────────────────────────────────────────
section "GitHub CLI"
log "Adding GitHub CLI apt repository..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -y -q
log "Installing gh..."
sudo apt-get install -y -q gh
ok "$(gh --version | head -1)"

# ── Rustup ────────────────────────────────────────────────────────────────────
section "Rust"
if ! command -v rustup &>/dev/null; then
    log "Installing Rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
else
    log "Rustup already installed — skipping"
fi
source "$HOME/.cargo/env"
ok "$(rustc --version)  |  cargo $(cargo --version | awk '{print $2}')"

# ── NVM ───────────────────────────────────────────────────────────────────────
section "NVM + Node.js LTS"
NVM_VERSION="v0.40.1"
if [ ! -d "$HOME/.nvm" ]; then
    log "Installing NVM ${NVM_VERSION}..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
else
    log "NVM already installed — skipping"
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
ok "NVM $(nvm --version)"

log "Installing Node.js LTS..."
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'
ok "Node $(node --version)  |  npm $(npm --version)"

# ── Bun ───────────────────────────────────────────────────────────────────────
section "Bun"
if ! command -v bun &>/dev/null; then
    log "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
else
    log "Bun already installed — skipping"
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
ok "Bun $(bun --version)"

# ── .NET SDK (LTS) ────────────────────────────────────────────────────────────
section ".NET SDK + Runtime"
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"
if ! command -v dotnet &>/dev/null; then
    log "Downloading dotnet-install.sh..."
    curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    chmod +x /tmp/dotnet-install.sh
    log "Installing .NET SDK (LTS)..."
    /tmp/dotnet-install.sh --channel LTS
    log "Installing .NET Runtime (LTS)..."
    /tmp/dotnet-install.sh --channel LTS --runtime dotnet
else
    log ".NET already installed — skipping"
fi
ok ".NET SDK $(dotnet --version)"

# ── pyenv ─────────────────────────────────────────────────────────────────────
section "pyenv"
if [ ! -d "$HOME/.pyenv" ]; then
    log "Installing pyenv..."
    curl https://pyenv.run | bash
else
    log "pyenv already installed — skipping"
fi
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
ok "$(pyenv --version)"

# ── npm globals ───────────────────────────────────────────────────────────────
section "Global npm Packages"
if command -v vite &>/dev/null; then
    warn "Vite already installed — skipping"
else
    log "Installing Vite..."
    npm install -g vite -q
fi
ok "Vite $(vite --version)"

if command -v claude &>/dev/null; then
    warn "Claude Code already installed — skipping"
else
    log "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code -q
fi
ok "Claude Code $(claude --version 2>&1 | head -1)"

# ── Git Configuration ─────────────────────────────────────────────────────────
section "Git"
log "Setting up git tree alias..."
git config --global alias.tree "log --graph --pretty=format:'%C(yellow)%h%Creset%C(auto)%d%Creset %s %Cblue[%an]%Creset %Cgreen(%ar)%Creset' --abbrev-commit --all"
ok "Alias ready — use: git tree"

# ── GitHub Copilot extension ──────────────────────────────────────────────────
section "GitHub Copilot CLI"
log "Installing gh copilot extension..."
gh extension install github/gh-copilot 2>/dev/null \
    && ok "gh copilot extension installed" \
    || warn "Skipped — run 'gh auth login' first, then 'gh extension install github/gh-copilot'"

# ── Shell Configuration (.bashrc) ─────────────────────────────────────────────
section "Shell Configuration"
log "Writing environment config to ~/.bashrc..."
MARKER="# >>> wsl-setup >>>"
if ! grep -qF "$MARKER" "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'SHELL_CONFIG'

# >>> wsl-setup >>>
# Rust
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# .NET
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

# Local tools
export PATH="$HOME/local/tools:$PATH"

# Aliases
alias gohome='cd ~/'
alias yolo='claude --dangerously-skip-permissions'
alias yoloresume='claude --resume --dangerously-skip-permissions'
alias yoloedge='bash ~/local/helpers/scripts/launch-edge.sh'
# <<< wsl-setup <<<
SHELL_CONFIG
    ok "~/.bashrc updated"
else
    warn "Config block already present — skipped"
fi

# ── Reload Shell ──────────────────────────────────────────────────────────────
section "Shell Reload"
log "Sourcing ~/.bashrc..."
source "$HOME/.bashrc"
ok "Shell environment reloaded"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║                                                      ║"
echo "  ║              Environment Ready!                      ║"
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
echo -e "  ${DIM}2.${NC}  gh auth login"
echo -e "  ${DIM}3.${NC}  wsl --shutdown    ${DIM}(from Windows, to apply .wslconfig + interop)${NC}"
echo ""
echo -e "  ${DIM}Log file: ${LOG_FILE}${NC}"
echo -e "  ${DIM}Finished: $(date '+%H:%M')${NC}"
echo ""
