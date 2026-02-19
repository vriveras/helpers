#!/bin/bash
# MCP Server Configuration Script
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
echo -e "  ${DIM}MCP Server Configuration · $(date '+%A, %B %d %Y  %H:%M')${NC}"
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────
section "Preflight"
log "Checking dependencies..."

command -v npx &>/dev/null || die "npx not found. Run setup-wsl.sh first."
ok "npx found"

[ -f "$HOME/.claude/settings.json" ] || die "~/.claude/settings.json not found. Launch Claude Code once first to generate it."
ok "~/.claude/settings.json found"

# ── ADO Configuration Input ───────────────────────────────────────────────────
section "Azure DevOps Configuration"
echo ""
echo -e "  ${DIM}Authentication is browser-based (Microsoft account) — no PAT needed.${NC}"
echo -e "  ${DIM}You will be prompted to log in on first use inside Claude Code.${NC}"
echo ""
ok "No credentials required at setup time"

# ── Playwright MCP ────────────────────────────────────────────────────────────
section "Playwright MCP"

log "Checking if Edge CDP endpoint is reachable..."
if curl -sf http://127.0.0.1:9222/json/version > /dev/null 2>&1; then
    EDGE_VERSION=$(curl -sf http://127.0.0.1:9222/json/version | grep -o '"Browser":"[^"]*"' | cut -d'"' -f4)
    ok "Edge is running: ${EDGE_VERSION}"
    CDP_ENDPOINT="http://127.0.0.1:9222"
else
    warn "Edge is not running on port 9222 — Playwright MCP will be configured but"
    warn "you must launch Edge with --remote-debugging-port=9222 before using it."
    warn "Windows PowerShell command:"
    echo ""
    echo -e "  ${DIM}& \"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe\" \\"
    echo -e "      --remote-debugging-port=9222 \\"
    echo -e "      --user-data-dir=\"C:\\Users\\virivera\\EdgePlaywright\"${NC}"
    echo ""
    CDP_ENDPOINT="http://127.0.0.1:9222"
fi

log "Writing MCP config to ~/.claude/settings.json..."
python3 - <<PYEOF
import json

path = '/home/virivera/.claude/settings.json'
cdp  = '${CDP_ENDPOINT}'

with open(path, 'r') as f:
    config = json.load(f)

config.setdefault('mcpServers', {})

config['mcpServers']['playwright'] = {
    'type': 'stdio',
    'command': 'npx',
    'args': ['-y', '@playwright/mcp@latest', '--cdp-endpoint', cdp]
}

# ADO MCP uses browser-based Microsoft account auth — no PAT needed
config['mcpServers']['azure-devops'] = {
    'type': 'stdio',
    'command': 'npx',
    'args': ['-y', '@azure-devops/mcp']
}

with open(path, 'w') as f:
    json.dump(config, f, indent=2)

print('OK')
PYEOF

ok "Playwright MCP configured → CDP endpoint: ${CDP_ENDPOINT}"
ok "Azure DevOps MCP configured → browser auth on first use"

# ── Summary ───────────────────────────────────────────────────────────────────
section "Configured MCP Servers"
python3 - <<PYEOF
import json
with open('/home/virivera/.claude/settings.json', 'r') as f:
    config = json.load(f)
servers = config.get('mcpServers', {})
if servers:
    for name, cfg in servers.items():
        cmd = cfg.get('command', '') + ' ' + ' '.join(cfg.get('args', []))
        print(f"  • {name}: {cmd[:80]}")
else:
    print("  (none)")
PYEOF

echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║                                                      ║"
echo "  ║              MCP Setup Complete!                     ║"
echo "  ║                                                      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  ${DIM}1.${NC}  Restart Claude Code to load the new MCP servers"
echo -e "  ${DIM}2.${NC}  Run 'yoloedge' to launch Edge for Playwright"
echo -e "  ${DIM}3.${NC}  On first ADO tool use, a browser will open for Microsoft login"
echo ""
