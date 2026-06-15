#!/bin/bash
# phase1_access.sh — Audit platform access and open IT tickets for gaps

# ── Platform-specific check functions ───────────────────────────────

gh_org_check() {
  local org="$1"
  if ! command_exists gh; then return 3; fi
  gh api "/orgs/${org}/memberships/$(gh api /user -q .login 2>/dev/null)" &>/dev/null
}

aws_check() {
  if ! command_exists aws; then return 3; fi
  aws sts get-caller-identity &>/dev/null
}

vpn_check() {
  # Try to reach an internal endpoint (only works on VPN)
  curl -s --connect-timeout 3 "https://argodev.cityba.se" &>/dev/null
}

jumpcloud_check() {
  # No reliable CLI check — prompt user
  return 2  # "unknown" status
}

gemfury_check() {
  [[ -n "$GEMFURY_TOKEN" ]] || [[ -n "$BUNDLE_GEM__FURY__IO" ]] || grep -q "fury" ~/.bundle/config 2>/dev/null
}

npm_check() {
  if ! command_exists npm; then return 3; fi
  npm whoami --registry=https://npm.fury.io/citybase/ &>/dev/null 2>&1
}

onepassword_check() {
  if ! command_exists op; then return 3; fi
  op account list 2>/dev/null | grep -qi "citybase\|euna"
}

browser_check() {
  return 2  # Always needs manual verification
}

# ── IT Ticket URL builder ───────────────────────────────────────────
build_ticket_url() {
  local resource="$1"
  local encoded_resource=$(echo "$resource" | sed 's/ /+/g')
  echo "${IT_TICKET_BASE}?description=Grant+access+to+${encoded_resource}&summary=Grant+access+to+${encoded_resource}"
}

# ── Main access audit ──────────────────────────────────────────────
run_phase1() {
  header "Phase 1: Access Audit"
  info "Checking your access to required platforms..."
  echo ""

  local missing=()
  local pending=()
  local ok=()
  local manual=()
  local deferred=()

  for platform_entry in "${PLATFORMS[@]}"; do
    local id=$(echo "$platform_entry" | cut -d: -f1)
    local name=$(echo "$platform_entry" | cut -d: -f2)
    local check_cmd=$(echo "$platform_entry" | cut -d: -f3)
    local ticket_resource=$(echo "$platform_entry" | cut -d: -f4)

    # Check if already marked as done in state
    if is_step_done "access_${id}"; then
      success "${name} — previously verified"
      ok+=("$name")
      continue
    fi

    # Check if marked as pending (IT ticket opened)
    local pending_state=$(state_get "access_${id}")
    if [[ "$pending_state" == "pending" ]]; then
      warn "${name} — IT ticket pending"
      pending+=("$name")
      continue
    fi

    # Run the check. Exit codes: 0=ok, 2=manual/browser,
    # 3=can't verify yet (the CLI it needs is installed in Phase 2),
    # anything else=no access.
    local check_fn=$(echo "$check_cmd" | awk '{print $1}')
    local check_arg=$(echo "$check_cmd" | awk '{print $2}')

    local rc=0
    $check_fn $check_arg 2>/dev/null || rc=$?
    case $rc in
      0)
        success "${name} — access confirmed"
        mark_step_done "access_${id}"
        ok+=("$name")
        ;;
      2)
        manual+=("$id:$name:$ticket_resource")
        ;;
      3)
        dim "${name} — will verify after tools are installed"
        deferred+=("$name")
        ;;
      *)
        fail "${name} — no access detected"
        missing+=("$id:$name:$ticket_resource")
        ;;
    esac
  done

  # Handle items needing manual verification
  if [[ ${#manual[@]} -gt 0 ]]; then
    echo ""
    info "The following require manual verification (browser-based):"
    for entry in "${manual[@]}"; do
      local id=$(echo "$entry" | cut -d: -f1)
      local name=$(echo "$entry" | cut -d: -f2)
      echo "  ${YELLOW}?${NC} ${name}"
    done

    if confirm "Would you like to verify these now?"; then
      for entry in "${manual[@]}"; do
        local id=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        local resource=$(echo "$entry" | cut -d: -f3)

        if confirm "  Do you have access to ${name}?"; then
          mark_step_done "access_${id}"
          ok+=("$name")
        else
          missing+=("$entry")
        fi
      done
    fi
  fi

  # Handle missing access — list everything, then ask once
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    header "Missing Access — IT Tickets Needed"
    info "These platforms need IT tickets:"
    echo ""
    for entry in "${missing[@]}"; do
      local name=$(echo "$entry" | cut -d: -f2)
      local resource=$(echo "$entry" | cut -d: -f3)
      fail "${name}"
      dim "Ticket: $(build_ticket_url "$resource")"
    done

    echo ""
    if confirm "Open pre-filled IT ticket forms for all ${#missing[@]} of these?"; then
      for entry in "${missing[@]}"; do
        local id=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        local resource=$(echo "$entry" | cut -d: -f3)
        if dry_run_guard "open $(build_ticket_url "$resource")"; then
          open_url "$(build_ticket_url "$resource")"
        fi
        state_set "access_${id}" "pending"
        pending+=("$name")
      done
      success "Opened ${#missing[@]} ticket form(s) — marked as pending."
    else
      dim "Skipped. The pre-filled ticket URLs above are there whenever you need them."
    fi
  fi

  # Note any checks we couldn't run yet (their CLIs get installed in Phase 2)
  if [[ ${#deferred[@]} -gt 0 ]]; then
    echo ""
    info "${#deferred[@]} access check(s) deferred until tools are installed — verified in the final report (Phase 5)."
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
  success "${#ok[@]} platforms confirmed"
  [[ ${#pending[@]} -gt 0 ]] && warn "${#pending[@]} IT tickets pending"
  [[ ${#missing[@]} -gt 0 ]] && fail "${#missing[@]} still need attention"

  echo ""
  info "You can re-run this phase anytime to re-check pending items."
  info "Tip: Some access (like GemFury token) may take a day — move on to Phase 2."
}
