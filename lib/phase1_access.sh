#!/bin/bash
# phase1_access.sh — Audit platform access and open IT tickets for gaps

# ── Platform-specific check functions ───────────────────────────────

gh_org_check() {
  local org="$1"
  if ! command_exists gh; then return 1; fi
  gh api "/orgs/${org}/memberships/$(gh api /user -q .login 2>/dev/null)" &>/dev/null
}

aws_check() {
  if ! command_exists aws; then return 1; fi
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
  if ! command_exists npm; then return 1; fi
  npm whoami --registry=https://npm.fury.io/citybase/ &>/dev/null 2>&1
}

onepassword_check() {
  if ! command_exists op; then return 1; fi
  op account list 2>/dev/null | grep -qi "citybase\|euna"
}

jira_check() {
  curl -s --connect-timeout 5 "https://eunasolutions.atlassian.net" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "200\|302"
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

    # Run the check
    local check_fn=$(echo "$check_cmd" | awk '{print $1}')
    local check_arg=$(echo "$check_cmd" | awk '{print $2}')

    if [[ "$check_fn" == "browser_check" ]]; then
      manual+=("$id:$name:$ticket_resource")
      continue
    fi

    if $check_fn $check_arg 2>/dev/null; then
      success "${name} — access confirmed"
      mark_step_done "access_${id}"
      ok+=("$name")
    elif [[ $? -eq 2 ]]; then
      manual+=("$id:$name:$ticket_resource")
    else
      fail "${name} — no access detected"
      missing+=("$id:$name:$ticket_resource")
    fi
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

  # Handle missing access
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    header "Missing Access — IT Tickets Needed"
    info "The following platforms need IT tickets. I can open the ticket forms for you."
    echo ""

    for entry in "${missing[@]}"; do
      local id=$(echo "$entry" | cut -d: -f1)
      local name=$(echo "$entry" | cut -d: -f2)
      local resource=$(echo "$entry" | cut -d: -f3)
      local ticket_url=$(build_ticket_url "$resource")

      fail "${name}"
      dim "Ticket URL: ${ticket_url}"

      if confirm "  Open IT ticket for ${name}?"; then
        if dry_run_guard "open ${ticket_url}"; then
          open_url "$ticket_url"
        fi
        state_set "access_${id}" "pending"
        pending+=("$name")
      fi
    done
  fi

  # Team channels reminder
  echo ""
  info "Verify you're in these MS Teams channels:"
  for ch in "${SHARED_TEAMS_CHANNELS[@]}"; do
    echo "  ${DIM}•${NC} $ch"
  done
  for ch in "${TEAM_CHANNELS[@]}"; do
    echo "  ${DIM}•${NC} $ch ${CYAN}(${TEAM_NAME} specific)${NC}"
  done

  # GitHub teams.tf reminder
  echo ""
  info "GitHub team membership:"
  dim "Find an existing engineer to add your username to:"
  dim "  ${GITHUB_MANAGEMENT_REPO}/blob/master/teams.tf"
  dim "  Example PR: https://github.com/CityBaseInc/github-management/pull/336"

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
