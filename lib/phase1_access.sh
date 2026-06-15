#!/bin/bash
# phase1_access.sh — Guide self-service platform access and confirm it
#
# Most access is self-service (SSO via the M365 apps portal, or a direct
# login). For each platform we try to auto-confirm via a CLI check; if we
# can't, we print the self-service steps, open the relevant page, and ask you
# to confirm. IT tickets are only a fallback for anything that still can't be
# confirmed. Re-running re-checks anything previously left pending.

# ── Platform check functions ────────────────────────────────────────
# Exit codes: 0 = confirmed, anything else = couldn't confirm automatically.
# (browser_check always defers to manual confirmation.)

gh_org_check() {
  local org="$1"
  command_exists gh || return 1
  gh api "/orgs/${org}/memberships/$(gh api /user -q .login 2>/dev/null)" &>/dev/null
}

aws_check() {
  command_exists aws || return 1
  aws sts get-caller-identity &>/dev/null
}

browser_check() {
  return 1  # always needs manual confirmation
}

# ── IT Ticket URL builder (fallback only) ───────────────────────────
build_ticket_url() {
  local resource="$1"
  local encoded_resource=$(echo "$resource" | sed 's/ /+/g')
  echo "${IT_TICKET_BASE}?description=Grant+access+to+${encoded_resource}&summary=Grant+access+to+${encoded_resource}"
}

# Open a URL once per run (dedupes so the M365 portal isn't opened repeatedly).
OPENED_URLS=()
open_once() {
  local url="$1"
  local u
  for u in "${OPENED_URLS[@]}"; do
    [[ "$u" == "$url" ]] && return
  done
  OPENED_URLS+=("$url")
  if dry_run_guard "open ${url}"; then
    open_url "$url"
  fi
}

# ── Self-service guidance per platform ──────────────────────────────
access_guidance() {
  local id="$1"
  case "$id" in
    github_cb|github_pay)
      note "Self-service via SSO — no IT ticket needed:"
      note "  1. Open the M365 apps portal and sign in with your @${EUNA_EMAIL_DOMAIN} account"
      note "  2. Go to 'Other apps' → '[GH-APP] CityBase Enterprise – CityBaseInc'"
      open_once "$M365_APPS_URL"
      ;;
    aws_iam)
      note "Self-service via SSO — no IT ticket needed:"
      note "  1. Open the M365 apps portal → 'AWS IAM Identity Center'"
      note "  2. Confirm you can see: Payments Production (${AWS_ACCOUNT_ID})"
      note "     account ${AWS_ACCOUNT_EMAIL}, role '${AWS_SSO_ROLE}'"
      open_once "$M365_APPS_URL"
      ;;
    coralogix)
      note "Self-service via SSO — no IT ticket needed:"
      note "  1. Open the M365 apps portal → 'Coralogix-Payments'"
      note "  2. Enter your @${EUNA_EMAIL_DOMAIN} email, click Continue, then choose 'Login with SSO'"
      open_once "$M365_APPS_URL"
      ;;
    airbrake)
      note "No IT ticket needed — sign in with GitHub:"
      note "  1. Go to ${AIRBRAKE_URL} and sign in with your GitHub account"
      note "  2. Confirm you can see the projects and their errors"
      open_once "$AIRBRAKE_URL"
      ;;
    gemfury)
      note "1. Log in at ${GEMFURY_DASHBOARD_URL}"
      note "2. If you can't log in or don't have an account, you'll need an IT ticket (you'll be prompted below)."
      open_once "$GEMFURY_DASHBOARD_URL"
      ;;
    npm_org)
      note "1. Create an account at npmjs.com if you don't have one"
      note "2. Confirm you're a member of the @thecb org: ${NPM_MEMBERS_URL}"
      open_once "$NPM_MEMBERS_URL"
      ;;
    onepassword)
      note "In your 1Password app, confirm the 'Citybase - Technology' vault appears under Euna Solutions"
      ;;
    jira)
      note "Sign in with your @${EUNA_EMAIL_DOMAIN} account:"
      note "  ${JIRA_URL}"
      open_once "$JIRA_URL"
      ;;
    sisense)
      note "1. Log in at ${PERISCOPE_URL} and confirm you can see the dashboards"
      note "2. If you can't log in or don't have an account, you'll need an IT ticket (you'll be prompted below)."
      open_once "$PERISCOPE_URL"
      ;;
    vpn)
      note "VPN access can't be checked automatically and is requested through IT."
      note "If you don't already have it, open a ticket below and re-run Phase 1 once IT grants it."
      ;;
    *)
      note "Confirm you can access this platform."
      ;;
  esac
}

# ── Main access audit ──────────────────────────────────────────────
run_phase1() {
  header "Phase 1: Access Audit"
  info "Most access is self-service via SSO — I'll guide you through each one and confirm it."
  echo ""

  local ok=()
  local needs=()   # "id:name:resource" — couldn't confirm; candidates for an IT ticket
  OPENED_URLS=()

  for platform_entry in "${PLATFORMS[@]}"; do
    local id=$(echo "$platform_entry" | cut -d: -f1)
    local name=$(echo "$platform_entry" | cut -d: -f2)
    local check_cmd=$(echo "$platform_entry" | cut -d: -f3)
    local ticket_resource=$(echo "$platform_entry" | cut -d: -f4)

    # Already confirmed on a previous run
    if is_step_done "access_${id}"; then
      success "${name} — previously verified"
      ok+=("$name")
      continue
    fi

    local check_fn=$(echo "$check_cmd" | awk '{print $1}')
    local check_arg=$(echo "$check_cmd" | awk '{print $2}')

    # Previously opened an IT ticket — re-check it on this run instead of
    # leaving it stuck as "pending" forever.
    if [[ "$(state_get "access_${id}")" == "pending" ]]; then
      local rc=0
      $check_fn $check_arg 2>/dev/null || rc=$?
      if [[ $rc -eq 0 ]]; then
        success "${name} — access now confirmed"
        mark_step_done "access_${id}"
        ok+=("$name")
      elif confirm "${name} — have you received access since the IT ticket?"; then
        mark_step_done "access_${id}"
        ok+=("$name")
      else
        warn "${name} — still pending"
      fi
      continue
    fi

    # First time: try to auto-confirm via the CLI check…
    local rc=0
    $check_fn $check_arg 2>/dev/null || rc=$?
    if [[ $rc -eq 0 ]]; then
      success "${name} — access confirmed"
      mark_step_done "access_${id}"
      ok+=("$name")
      continue
    fi

    # …otherwise guide the user through self-service and ask them to confirm.
    echo ""
    step "${name}"
    access_guidance "$id"
    if confirm "  Can you access ${name}?"; then
      mark_step_done "access_${id}"
      ok+=("$name")
    else
      needs+=("$id:$name:$ticket_resource")
    fi
  done

  # IT ticket fallback — only for what still couldn't be confirmed
  if [[ ${#needs[@]} -gt 0 ]]; then
    echo ""
    header "Still need access"
    info "Couldn't confirm these. If self-service didn't work, an IT ticket is the fallback:"
    echo ""
    local entry
    for entry in "${needs[@]}"; do
      fail "$(echo "$entry" | cut -d: -f2)"
    done

    echo ""
    if confirm "Open pre-filled IT ticket forms for these ${#needs[@]}?"; then
      for entry in "${needs[@]}"; do
        local id=$(echo "$entry" | cut -d: -f1)
        local resource=$(echo "$entry" | cut -d: -f3)
        open_once "$(build_ticket_url "$resource")"
        state_set "access_${id}" "pending"
      done
      success "Opened ${#needs[@]} ticket form(s) — re-run Phase 1 once IT grants access."
    else
      dim "Skipped. Re-run Phase 1 anytime to confirm once you have access."
      dim "Stuck? Ask in the Developer Hotline channel."
    fi
  fi

  # ── Pause for manual steps before moving on ───────────────────────
  echo ""
  header "Before we continue — two manual steps"
  warn "Please do these now. The next phases install tools and may ask for your Mac password, so take your time here first."

  echo ""
  info "1. Make sure you've joined these MS Teams channels:"
  for ch in "${SHARED_TEAMS_CHANNELS[@]}"; do
    echo "  ${DIM}•${NC} $ch"
  done
  for ch in "${TEAM_CHANNELS[@]}"; do
    echo "  ${DIM}•${NC} $ch ${CYAN}(${TEAM_NAME} specific)${NC}"
  done

  echo ""
  info "2. Get added to the GitHub team:"
  dim "Find an existing engineer to create a PR adding your username to teams.tf,"
  dim "similar to the example PR below:"
  dim "  ${GITHUB_MANAGEMENT_REPO}/blob/master/teams.tf"
  dim "  Example PR: https://github.com/CityBaseInc/github-management/pull/336"

  echo ""
  wait_for_user "Press Enter once you've joined the channels and requested the teams.tf PR..."

  # Summary
  echo ""
  header "Access Audit Summary"
  success "${#ok[@]} of ${#PLATFORMS[@]} platforms confirmed"
  [[ ${#needs[@]} -gt 0 ]] && warn "${#needs[@]} still need attention — re-run Phase 1 once you've sorted them out"

  echo ""
  info "Re-run this phase anytime ('--phase 1') to confirm access you've since gained."
}
