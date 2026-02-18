#!/bin/bash
# Launch Microsoft Edge on Windows with CDP remote debugging enabled
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log()     { echo -e "  ${BLUE}→${NC} $*"; }
ok()      { echo -e "  ${GREEN}✓${NC} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
die()     { echo -e "  ${RED}✗${NC} $*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}┌─ $* ${NC}${DIM}────────────────────────────────────────${NC}"; }

# ── Config ────────────────────────────────────────────────────────────────────
CDP_PORT=9222
WIN_USER_DATA_DIR="C:\\Users\\virivera\\EdgePlaywright"

EDGE_CANDIDATES=(
    "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
    "/mnt/c/Program Files/Microsoft/Edge/Application/msedge.exe"
)

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
echo -e "  ${DIM}Launching Edge with CDP remote debugging · port ${CDP_PORT}${NC}"
echo ""

# ── Already running? ──────────────────────────────────────────────────────────
section "Checking Edge"
if curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" > /dev/null 2>&1; then
    EDGE_VER=$(curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
    ok "Edge is already running in CDP mode: ${EDGE_VER}"
    ok "CDP endpoint ready at http://127.0.0.1:${CDP_PORT}"
    echo ""
    exit 0
fi
log "Edge not running on port ${CDP_PORT} — will launch now"

# ── Find Edge executable ──────────────────────────────────────────────────────
section "Locating Edge"
EDGE_EXE=""
for candidate in "${EDGE_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
        EDGE_EXE="$candidate"
        break
    fi
done

[ -z "$EDGE_EXE" ] && die "Could not find msedge.exe. Is Edge installed on Windows?"

# Convert WSL path to Windows path for display
WIN_EDGE_PATH=$(wslpath -w "$EDGE_EXE")
ok "Found Edge: ${WIN_EDGE_PATH}"

# ── Launch Edge ───────────────────────────────────────────────────────────────
section "Launching Edge"
log "Starting Edge with remote debugging on port ${CDP_PORT}..."
log "Profile: ${WIN_USER_DATA_DIR}"

powershell.exe -NoProfile -WindowStyle Hidden -Command "
    Start-Process '$WIN_EDGE_PATH' -ArgumentList \`
        '--remote-debugging-port=${CDP_PORT}', \`
        '--user-data-dir=${WIN_USER_DATA_DIR}', \`
        '--no-first-run', \`
        '--no-default-browser-check'
" 2>/dev/null

# ── Wait for CDP to be ready ──────────────────────────────────────────────────
section "Waiting for CDP"
log "Waiting for Edge to be ready..."
ATTEMPTS=30
for i in $(seq 1 $ATTEMPTS); do
    if curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" > /dev/null 2>&1; then
        EDGE_VER=$(curl -sf "http://127.0.0.1:${CDP_PORT}/json/version" | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
        ok "Edge ready: ${EDGE_VER}"
        ok "CDP endpoint: http://127.0.0.1:${CDP_PORT}"
        break
    fi
    echo -ne "  ${DIM}attempt ${i}/${ATTEMPTS}...${NC}\r"
    sleep 0.5
    if [ "$i" -eq "$ATTEMPTS" ]; then
        echo ""
        die "Edge did not become ready in time. Check if Windows firewall is blocking port ${CDP_PORT}."
    fi
done

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║                                                      ║"
echo "  ║           Edge is ready for Playwright!              ║"
echo "  ║                                                      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${DIM}CDP endpoint: http://127.0.0.1:${CDP_PORT}${NC}"
echo -e "  ${DIM}Profile dir:  ${WIN_USER_DATA_DIR}${NC}"
echo ""
