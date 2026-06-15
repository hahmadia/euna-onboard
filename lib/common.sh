#!/bin/bash
# common.sh — Shared utilities for euna-onboard
# Colors, logging, state management, user prompts

# ── Colors ──────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
PURPLE=$'\033[0;35m'
MAGENTA=$'\033[1;35m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m' # No Color

# ── Logging ─────────────────────────────────────────────────────────
info()     { echo "${BLUE}▸${NC} $1"; }
success()  { echo "${GREEN}✓${NC} $1"; }
warn()     { echo "${YELLOW}⚠${NC} $1"; }
fail()     { echo "${RED}✗${NC} $1"; }
header()   { printf '\n%s━━━ %s ━━━%s\n\n' "${BOLD}${PURPLE}" "$1" "${NC}"; }
step()     { echo "${CYAN}→${NC} ${BOLD}$1${NC}"; }
dim()      { echo "${DIM}  $1${NC}"; }
progress() { echo "${PURPLE}◆${NC} ${BOLD}$1${NC}"; }
loading()  { echo -n "${DIM}  ⏳ $1...${NC}"; }
loaded()   { echo " ${GREEN}done${NC}"; }

# ── Banner ─────────────────────────────────────────────────────────
show_wave_banner() {
  echo ""
  echo "${BOLD}${PURPLE}  ███████╗██╗   ██╗███╗   ██╗ █████╗ ${NC}"
  echo "${BOLD}${PURPLE}  ██╔════╝██║   ██║████╗  ██║██╔══██╗${NC}"
  echo "${BOLD}${PURPLE}  █████╗  ██║   ██║██╔██╗ ██║███████║${NC}"
  echo "${BOLD}${PURPLE}  ██╔══╝  ██║   ██║██║╚██╗██║██╔══██║${NC}"
  echo "${BOLD}${PURPLE}  ███████╗╚██████╔╝██║ ╚████║██║  ██║${NC}"
  echo "${BOLD}${PURPLE}  ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝${NC}"
  echo "${BOLD}${PURPLE}  ██████╗  █████╗ ██╗   ██╗███╗   ███╗███████╗███╗   ██╗████████╗███████╗${NC}"
  echo "${BOLD}${PURPLE}  ██╔══██╗██╔══██╗╚██╗ ██╔╝████╗ ████║██╔════╝████╗  ██║╚══██╔══╝██╔════╝${NC}"
  echo "${BOLD}${PURPLE}  ██████╔╝███████║ ╚████╔╝ ██╔████╔██║█████╗  ██╔██╗ ██║   ██║   ███████╗${NC}"
  echo "${BOLD}${PURPLE}  ██╔═══╝ ██╔══██║  ╚██╔╝  ██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   ╚════██║${NC}"
  echo "${BOLD}${PURPLE}  ██║     ██║  ██║   ██║   ██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   ███████║${NC}"
  echo "${BOLD}${PURPLE}  ╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝${NC}"
  echo ""
  echo "${DIM}  Developer Onboarding CLI${NC}"
  echo ""
}

# ── State Management ────────────────────────────────────────────────
STATE_FILE="${HOME}/.euna-onboard-state"

state_init() {
  [[ -f "$STATE_FILE" ]] || echo "{}" > "$STATE_FILE"
}

state_get() {
  local key="$1"
  if command -v jq &>/dev/null; then
    jq -r ".[\"$key\"] // empty" "$STATE_FILE" 2>/dev/null
  else
    grep "\"$key\"" "$STATE_FILE" | sed 's/.*: *"\(.*\)".*/\1/' 2>/dev/null
  fi
}

state_set() {
  local key="$1" value="$2"
  if command -v jq &>/dev/null; then
    local tmp=$(mktemp)
    jq ". + {\"$key\": \"$value\"}" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  else
    # Fallback: simple key-value append (less robust)
    echo "\"$key\": \"$value\"" >> "$STATE_FILE"
  fi
}

is_step_done() {
  [[ "$(state_get "$1")" == "done" ]]
}

mark_step_done() {
  state_set "$1" "done"
  success "Step complete: $1"
}

# ── User Prompts ────────────────────────────────────────────────────
confirm() {
  local prompt="$1"
  local response
  echo -n "${YELLOW}?${NC} ${prompt} [Y/n] "
  read -r response
  [[ -z "$response" || "$response" =~ ^[Yy] ]]
}

prompt_input() {
  local prompt="$1" default="$2" response
  if [[ -n "$default" ]]; then
    echo -n "${YELLOW}?${NC} ${prompt} [${default}]: " >&2
  else
    echo -n "${YELLOW}?${NC} ${prompt}: " >&2
  fi
  read -r response
  echo "${response:-$default}"
}

prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local num_opts=${#options[@]}
  echo "${YELLOW}?${NC} ${prompt}" >&2
  for (( i=0; i<num_opts; i++ )); do
    echo "  ${BOLD}${PURPLE}$((i+1)))${NC} ${options[$i]}" >&2
  done
  local choice
  echo "" >&2
  echo -n "  ${CYAN}▸${NC} Enter choice (1-${num_opts}): " >&2
  read -r choice
  while [[ -z "$choice" ]] || (( choice < 1 || choice > num_opts )); do
    echo -n "  ${RED}✗${NC} Please enter 1-${num_opts}: " >&2
    read -r choice
  done
  echo "${options[$((choice-1))]}"
}

# Interactive select with descriptions
prompt_select() {
  local prompt="$1"
  shift
  local values=() descs=()
  while [[ $# -gt 0 ]]; do
    values+=("$1")
    descs+=("$2")
    shift 2
  done
  local num=${#values[@]}

  echo "" >&2
  echo "${YELLOW}?${NC} ${BOLD}${prompt}${NC}" >&2
  echo "" >&2
  for (( i=0; i<num; i++ )); do
    echo "  ${PURPLE}${BOLD}$((i+1)))${NC}  ${BOLD}${values[$i]}${NC}" >&2
    echo "      ${DIM}${descs[$i]}${NC}" >&2
  done
  echo "" >&2
  local choice
  echo -n "  ${CYAN}▸${NC} Enter choice (1-${num}): " >&2
  read -r choice
  while [[ -z "$choice" ]] || (( choice < 1 || choice > num )); do
    echo -n "  ${RED}✗${NC} Please enter 1-${num}: " >&2
    read -r choice
  done
  REPLY="${values[$((choice-1))]}"
}

wait_for_user() {
  local msg="${1:-Press Enter to continue...}"
  echo -n "${DIM}${msg}${NC}"
  read -r
}

# ── Utility Functions ───────────────────────────────────────────────
command_exists() {
  command -v "$1" &>/dev/null
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

open_url() {
  local url="$1"
  if is_macos; then
    open "$url" 2>/dev/null
  else
    xdg-open "$url" 2>/dev/null || echo "Open: $url"
  fi
}

ensure_dir() {
  [[ -d "$1" ]] || mkdir -p "$1"
}

# Check if a block is already in a file (for idempotent appends)
block_exists_in_file() {
  local marker="$1" file="$2"
  grep -q "$marker" "$file" 2>/dev/null
}

# Append a block to a file with markers (idempotent)
append_block() {
  local file="$1" marker="$2" content="$3"
  if block_exists_in_file "$marker" "$file"; then
    dim "Block already present in $(basename "$file"), skipping"
    return 0
  fi
  {
    echo ""
    echo "# --- ${marker} START ---"
    echo "$content"
    echo "# --- ${marker} END ---"
  } >> "$file"
  success "Added ${marker} block to $(basename "$file")"
}

# ── Config Loading ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
AI_DIR="${SCRIPT_DIR}/ai"

load_config() {
  local conf_file="$1"
  if [[ -f "${CONFIG_DIR}/${conf_file}" ]]; then
    source "${CONFIG_DIR}/${conf_file}"
  else
    fail "Config file not found: ${conf_file}"
    return 1
  fi
}

# ── Default Config ──────────────────────────────────────────────────
CODE_DIR="${HOME}/code"
GITHUB_ORG="CityBaseInc"
GITHUB_ORG_PAYMENTS="Payments-CityBase"
EUNA_EMAIL_DOMAIN="eunasolutions.com"
IT_TICKET_BASE="https://servicedesk.jira.eunasolutions.com/servicedesk/customer/portal/12/group/17/create/101"

# DRY_RUN mode
DRY_RUN=false

dry_run_guard() {
  if $DRY_RUN; then
    dim "[dry-run] Would execute: $1"
    return 1
  fi
  return 0
}
