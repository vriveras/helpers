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

command -v claude &>/dev/null || die "Claude Code CLI not found. Run setup-wsl.sh first."
ok "Claude Code CLI found"

command -v npx &>/dev/null || die "npx not found. Run setup-wsl.sh first."
ok "npx found"

# ── ADO Configuration Input ───────────────────────────────────────────────────
section "Azure DevOps Configuration"

if [ -n "${ADO_ORG:-}" ] && [ -n "${ADO_MCP_AUTH_TOKEN:-}" ]; then
    log "Using ADO_ORG and ADO_MCP_AUTH_TOKEN from environment"
else
    echo ""
    echo -e "  ${BOLD}Azure DevOps Organization${NC}"
    echo -e "  ${DIM}e.g. if your ADO URL is dev.azure.com/contoso → enter: contoso${NC}"
    echo -n "  Organization name: "
    read -r ADO_ORG

    echo ""
    echo -e "  ${BOLD}Azure DevOps Personal Access Token${NC}"
    echo -e "  ${DIM}Needs scopes: Work Items (read/write), Code (read), Build (read)${NC}"
    echo -n "  PAT token: "
    read -rs ADO_MCP_AUTH_TOKEN
    echo ""
fi

[ -z "$ADO_ORG" ]             && die "Organization name cannot be empty"
[ -z "$ADO_MCP_AUTH_TOKEN" ]  && die "PAT token cannot be empty"

ok "ADO org: ${ADO_ORG}"
ok "PAT token: ${ADO_MCP_AUTH_TOKEN:0:4}****${ADO_MCP_AUTH_TOKEN: -4}"

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

log "Removing existing playwright MCP config (if any)..."
claude mcp remove playwright 2>/dev/null || true

log "Adding Playwright MCP server..."
claude mcp add -s user playwright -- npx -y @playwright/mcp@latest --cdp-endpoint "$CDP_ENDPOINT"
ok "Playwright MCP configured → CDP endpoint: ${CDP_ENDPOINT}"

# ── Azure DevOps MCP ──────────────────────────────────────────────────────────
section "Azure DevOps MCP"

log "Removing existing azure-devops MCP config (if any)..."
claude mcp remove azure-devops 2>/dev/null || true

log "Adding Azure DevOps MCP server..."
claude mcp add -s user \
    --env ADO_MCP_AUTH_TOKEN="$ADO_MCP_AUTH_TOKEN" \
    azure-devops -- npx -y @azure-devops/mcp "$ADO_ORG"
ok "Azure DevOps MCP configured → org: ${ADO_ORG}"

# ── Summary ───────────────────────────────────────────────────────────────────
section "Configured MCP Servers"
claude mcp list

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
echo -e "  ${DIM}2.${NC}  Make sure Edge is running with --remote-debugging-port=9222"
echo -e "  ${DIM}3.${NC}  Ask Claude to browse the web or query Azure DevOps"
echo ""
