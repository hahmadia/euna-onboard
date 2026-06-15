#!/bin/bash
# euna-onboard.sh — Automated developer onboarding for Euna Payments
#
# Usage:
#   ./euna-onboard.sh --team web --name "First Last"
#   ./euna-onboard.sh --team inperson --phase 3
#   ./euna-onboard.sh --verify
#   ./euna-onboard.sh --dry-run --team platform
#   ./euna-onboard.sh --reset

set -o pipefail

# ── Resolve script directory ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ── Immediate banner (first thing the user sees) ────────────────────
show_wave_banner

# ── Help ────────────────────────────────────────────────────────────
show_help() {
  cat <<EOF
${BOLD}euna-onboard${NC} — Automated developer onboarding for Euna Payments

${BOLD}USAGE${NC}
  ./euna-onboard.sh --team <team> [--name "Name"] [OPTIONS]

${BOLD}REQUIRED${NC}
  --team <team>       Your team: web, inperson, or platform

${BOLD}OPTIONS${NC}
  --name "Name"       Your full name (for git config)
  --email "email"     Your @thecitybase.com email
  --phase N           Start from phase N (1-5)
  --dry-run           Preview without making changes
  --verify            Run verification only (Phase 5)
  --reset             Clear saved progress and start fresh
  -h, --help          Show this help

${BOLD}PHASES${NC}
  1  Access Audit      Check platform access, open IT tickets
  2  Environment       Homebrew, asdf, GPG, git, shell config
  3  Repositories      Clone and set up team-specific repos
  4  Bookmarks & AI    Chrome bookmarks, Warp rules, CLAUDE.md
  5  Verification      Smoke test everything, print report card

${BOLD}EXAMPLES${NC}
  # Full onboarding for a Web team developer
  ./euna-onboard.sh --team web --name "Jane Smith"

  # Resume from Phase 3 (repos)
  ./euna-onboard.sh --team web --phase 3

  # Just check what's set up
  ./euna-onboard.sh --team web --verify

  # Preview without making changes
  ./euna-onboard.sh --team web --dry-run
EOF
}

# ── Parse arguments ─────────────────────────────────────────────────
TEAM=""
DEV_NAME=""
DEV_EMAIL=""
START_PHASE=0
VERIFY_ONLY=false
RESET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team)      TEAM="$2"; shift 2 ;;
    --name)      DEV_NAME="$2"; shift 2 ;;
    --email)     DEV_EMAIL="$2"; shift 2 ;;
    --phase)     START_PHASE="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --verify)    VERIFY_ONLY=true; shift ;;
    --reset)     RESET=true; shift ;;
    --help|-h)   show_help; exit 0 ;;
    *)           fail "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# ── Reset ───────────────────────────────────────────────────────────
if $RESET; then
  if confirm "This will clear all saved progress. Continue?"; then
    rm -f "$STATE_FILE"
    success "Progress reset. Run again to start fresh."
  fi
  exit 0
fi

# ── Interactive wizard (when no args passed) ───────────────────────
INTERACTIVE=false
if [[ -z "$TEAM" ]] && [[ -z "$DEV_NAME" ]] && ! $VERIFY_ONLY; then
  INTERACTIVE=true
fi

# ── Collect team ────────────────────────────────────────────────────
if [[ -z "$TEAM" ]]; then
  # Try to recover from state
  TEAM=$(state_get "team" 2>/dev/null)
fi

if [[ -z "$TEAM" ]]; then
  if $INTERACTIVE; then
    progress "Let's get you set up! First, a few quick questions."
  fi
  prompt_select "Which team are you joining?" \
    "web"      "Online Payments — checkout, wallet, recurring, RevM, NFE, Citizen Dashboard" \
    "inperson" "In-Person — cashiering/POS, kiosks, device integrations" \
    "platform" "Platform — core processing, lookups, reporting, EOP, disbursements"
  TEAM="$REPLY"
fi

TEAM=$(echo "$TEAM" | tr '[:upper:]' '[:lower:]')
case "$TEAM" in
  web|inperson|platform) ;;
  *) fail "Invalid team: ${TEAM}. Must be: web, inperson, or platform"; exit 1 ;;
esac

# ── Initialize ──────────────────────────────────────────────────────
echo ""
progress "Initializing..."
state_init

loading "Loading shared config"
load_config "shared.conf"
loaded

loading "Loading ${TEAM} team config"
load_config "${TEAM}.conf"
loaded

loading "Loading phase scripts"
source "${SCRIPT_DIR}/lib/phase1_access.sh"
source "${SCRIPT_DIR}/lib/phase2_environment.sh"
source "${SCRIPT_DIR}/lib/phase3_repos.sh"
source "${SCRIPT_DIR}/lib/phase4_bookmarks.sh"
source "${SCRIPT_DIR}/lib/phase5_verify.sh"
loaded
success "Ready!"
echo ""

# ── Collect developer info ──────────────────────────────────────────
if [[ -z "$DEV_NAME" ]]; then
  DEV_NAME=$(state_get "dev_name")
fi
if [[ -z "$DEV_NAME" ]] && ! $VERIFY_ONLY; then
  if $INTERACTIVE; then
    header "About You"
  fi
  DEV_NAME=$(prompt_input "What is your full name?")
  state_set "dev_name" "$DEV_NAME"
  echo ""
fi

if [[ -z "$DEV_EMAIL" ]]; then
  DEV_EMAIL=$(state_get "dev_email")
fi
if [[ -z "$DEV_EMAIL" ]] && ! $VERIFY_ONLY; then
  default_email=$(echo "$DEV_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /./g')
  DEV_EMAIL=$(prompt_input "What is your @${CITYBASE_EMAIL_DOMAIN} email?" "${default_email}@${CITYBASE_EMAIL_DOMAIN}")
  state_set "dev_email" "$DEV_EMAIL"
  echo ""
fi

DEV_NAMESPACE=$(echo "$DEV_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# ── Session Info ────────────────────────────────────────────────────
echo "${PURPLE}╭──────────────────────────────────────────────╮${NC}"
echo "${PURPLE}│${NC}  ${BOLD}Developer${NC}  ${GREEN}${DEV_NAME}${NC}"
echo "${PURPLE}│${NC}  ${BOLD}Team${NC}       ${CYAN}${TEAM_DISPLAY}${NC}"
echo "${PURPLE}│${NC}  ${BOLD}Email${NC}      ${BLUE}${DEV_EMAIL}${NC}"
echo "${PURPLE}│${NC}  ${BOLD}Namespace${NC}  ${DIM}${DEV_NAMESPACE}${NC}"
$DRY_RUN && echo "${PURPLE}│${NC}  ${BOLD}Mode${NC}       ${YELLOW}DRY RUN${NC}"
echo "${PURPLE}╰──────────────────────────────────────────────╯${NC}"
echo ""

state_set "team" "$TEAM"

# ── Run phases ──────────────────────────────────────────────────────
if $VERIFY_ONLY; then
  run_phase5
  exit 0
fi

progress "Starting onboarding — 5 phases to complete"
echo ""

if [[ $START_PHASE -le 1 ]]; then
  echo "${PURPLE}┌─${NC} ${BOLD}Phase 1/5${NC}"
  run_phase1
  echo "${PURPLE}└─${NC} ${GREEN}Phase 1 done${NC}"
  echo ""
fi
if [[ $START_PHASE -le 2 ]]; then
  echo "${PURPLE}┌─${NC} ${BOLD}Phase 2/5${NC}"
  run_phase2
  echo "${PURPLE}└─${NC} ${GREEN}Phase 2 done${NC}"
  echo ""
fi
if [[ $START_PHASE -le 3 ]]; then
  echo "${PURPLE}┌─${NC} ${BOLD}Phase 3/5${NC}"
  run_phase3
  echo "${PURPLE}└─${NC} ${GREEN}Phase 3 done${NC}"
  echo ""
fi
if [[ $START_PHASE -le 4 ]]; then
  echo "${PURPLE}┌─${NC} ${BOLD}Phase 4/5${NC}"
  run_phase4
  echo "${PURPLE}└─${NC} ${GREEN}Phase 4 done${NC}"
  echo ""
fi

echo "${PURPLE}┌─${NC} ${BOLD}Phase 5/5${NC}"
run_phase5
echo "${PURPLE}└─${NC} ${GREEN}Phase 5 done${NC}"

echo ""
echo "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo "${BOLD}${GREEN}║   🎉  Onboarding complete! Welcome!     ║${NC}"
echo "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "${DIM}Run './euna-onboard.sh --team ${TEAM} --verify' anytime to check status.${NC}"
