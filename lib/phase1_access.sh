#!/bin/bash
# phase1_access.sh — Guide platform access (self-service vs IT ticket)
#
# Each platform has an access_type (see config): self_service platforms print
# steps via access_guidance and ask you to confirm (an IT ticket is the
# fallback); it_ticket platforms assume no access on the first run, open a
# pre-filled ticket, and only ask whether access came through on later runs.
# Re-running re-checks anything previously left pending.

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

# ── IT ticket form autofill (console snippet) ───────────────────────
# Generate a personalized JS snippet that fills the JSM "Access Issue" form
# (category, summary, resource, impact, urgency, description) and copy it to the
# clipboard; the user pastes it into the DevTools console on the ticket page.
js_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

copy_ticket_autofill() {
  local resources=("$@")
  [[ ${#resources[@]} -eq 0 ]] && return 0
  command_exists pbcopy || return 0

  local name_js email_js team_js
  name_js=$(js_escape "${DEV_NAME:-}")
  email_js=$(js_escape "${DEV_EMAIL:-}")
  team_js=$(js_escape "${TEAM_DISPLAY:-}")

  local tickets_js="" r summary desc
  for r in "${resources[@]}"; do
    summary="Grant access to ${r}"
    desc="Please grant ${DEV_NAME} (${DEV_EMAIL}, ${TEAM_DISPLAY}) access to ${r}."
    tickets_js+="    { resource: \"$(js_escape "$r")\", summary: \"$(js_escape "$summary")\", description: \"$(js_escape "$desc")\" },"$'\n'
  done

  local snippet
  snippet=$(cat <<JS
(async () => {
  /* euna-onboard — Access Issue autofill. Paste in the DevTools console on the ticket page. */
  const requester = { name: "${name_js}", email: "${email_js}", team: "${team_js}" };
  const tickets = [
${tickets_js}  ];

  /* Access Issue form (JSM portal 12 / request type 101). Single-select dropdowns: */
  const SELECTS = {
    "#customfield_10199": "User Account",             /* Access Issue Category */
    "#customfield_10200": "Single User",              /* Impact */
    "#customfield_10201": "Work Impacted Negatively", /* Urgency */
  };
  const RESOURCE_INPUT = "#customfield_10068";        /* Resource — CMDB async picker */

  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const setNativeValue = (el, value) => {
    const proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, "value").set.call(el, value);
    el.dispatchEvent(new Event("input", { bubbles: true }));
  };
  const options = () => [...document.querySelectorAll("[id*='-option'], [role='option']")];
  const openMenu = (input) => {
    (input.closest("[class*='-control']") || input.parentElement)
      .dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    input.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "ArrowDown", keyCode: 40 }));
  };
  const pickSelect = async (sel, label) => {
    const input = document.querySelector(sel);
    if (!input) return console.warn("euna-onboard: missing", sel);
    input.focus(); openMenu(input); await sleep(250);
    const opt = options().find(o => o.textContent.trim() === label)
             || options().find(o => o.textContent.trim().toLowerCase().startsWith(label.toLowerCase()));
    if (opt) { opt.click(); await sleep(120); }
    else { console.warn("euna-onboard: option not found:", label, "(pick manually)");
           input.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Escape", keyCode: 27 })); }
  };
  const pickResource = async (sel, terms) => {
    const input = document.querySelector(sel);
    if (!input) return console.warn("euna-onboard: missing", sel);
    for (const term of terms) {
      input.focus(); setNativeValue(input, term); await sleep(900);
      const opt = options().find(o => o.textContent.trim().toLowerCase().includes(term.toLowerCase()));
      if (opt) { opt.click(); await sleep(150); return; }
    }
    console.warn("euna-onboard: no CMDB match for Resource — pick it manually");
  };

  /* Match the ticket to the summary pre-filled via the URL, else use the first. */
  const summaryEl = document.querySelector("#summary");
  const current = (summaryEl || {}).value || "";
  const ticket = tickets.find(t => current && current.includes(t.resource)) || tickets[0];

  /* Summary + description are usually pre-filled by the ticket URL; set if empty. */
  if (summaryEl && !summaryEl.value) setNativeValue(summaryEl, ticket.summary);
  const descEl = document.querySelector("#ak-editor-textarea");
  if (descEl && !descEl.textContent.trim()) { descEl.focus(); document.execCommand("insertText", false, ticket.description); }

  for (const [sel, label] of Object.entries(SELECTS)) await pickSelect(sel, label);
  await pickResource(RESOURCE_INPUT, [ticket.resource, "Other"]);
  console.log("euna-onboard: autofill done for", ticket.resource, "— review the dropdowns, then Send.");
})();
JS
)

  if dry_run_guard "copy IT-ticket autofill snippet to clipboard"; then
    printf '%s' "$snippet" | pbcopy
  fi
}

# ── Open one IT ticket, paced and with autofill help ────────────────
# Explains what's about to happen, copies this ticket's autofill snippet, and
# waits for the developer before opening the pre-filled form — so a browser tab
# never just appears unannounced. Used for every ticket we open.
open_ticket() {
  local name="$1" resource="$2"
  echo ""
  step "IT ticket — ${name}"
  note "A browser window will open with a pre-filled Access Issue form."
  note "I'm copying a JavaScript autofill snippet to your clipboard now."
  note "When the window opens:"
  note "  1. Open the DevTools console (⌥⌘J)."
  note "  2. Paste (⌘V) and run it to autofill the dropdowns."
  note "  3. Review every field, then click Send to submit."
  copy_ticket_autofill "$resource"
  wait_for_user "Press Enter to open the pre-filled ticket for ${name}..."
  open_once "$(build_ticket_url "$resource")"
  wait_for_user "Press Enter once you've pasted the snippet, reviewed, and submitted (or to continue)..."
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
      note "  3. If asked for a team name, enter 'payments'"
      open_once "$M365_APPS_URL"
      ;;
    airbrake)
      note "No IT ticket needed — sign in with GitHub:"
      note "  1. Go to ${AIRBRAKE_URL} and sign in with your GitHub account"
      note "  2. Confirm you can see the projects and their errors"
      open_once "$AIRBRAKE_URL"
      ;;
    gemfury)
      note "Requested through IT — a GemFury account is granted via a ticket."
      ;;
    npm_org)
      note "Requested through IT — @thecb org membership is granted via a ticket."
      ;;
    onepassword)
      note "Requested through IT — the 'Citybase - Technology' vault is granted via a ticket."
      ;;
    jira)
      note "Sign in with your @${EUNA_EMAIL_DOMAIN} account:"
      note "  ${JIRA_URL}"
      open_once "$JIRA_URL"
      ;;
    sisense)
      note "Requested through IT — Sisense/Periscope access is granted via a ticket."
      ;;
    vpn)
      note "VPN access must be requested through IT — open a ticket below if you don't have it."
      note "Once IT confirms your access, set up the AWS VPN client by following this guide:"
      note "  ${CONFLUENCE_VPN_SETUP}"
      ;;
    *)
      note "Confirm you can access this platform."
      ;;
  esac
}

# ── Main access audit ──────────────────────────────────────────────
run_phase1() {
  header "Phase 1: Access Audit"
  info "Self-service access I'll guide you through; anything IT-gated I'll open a ticket for."
  echo ""

  local ok=()
  local needs=()   # "id:name:resource" — self-service the user couldn't confirm
  OPENED_URLS=()

  for platform_entry in "${PLATFORMS[@]}"; do
    local id=$(echo "$platform_entry" | cut -d: -f1)
    local name=$(echo "$platform_entry" | cut -d: -f2)
    local ticket_resource=$(echo "$platform_entry" | cut -d: -f4)
    local access_type=$(echo "$platform_entry" | cut -d: -f5)

    # Already confirmed on a previous run
    if is_step_done "access_${id}"; then
      success "${name} — previously verified"
      ok+=("$name")
      continue
    fi

    # Previously opened an IT ticket — the only place we ask whether access has
    # come through (never on the first run).
    if [[ "$(state_get "access_${id}")" == "pending" ]]; then
      if confirm "${name} — have you received access since the IT ticket?"; then
        mark_step_done "access_${id}"
        ok+=("$name")
      else
        warn "${name} — still pending"
      fi
      continue
    fi

    # First time seeing this platform — behavior depends on access_type.
    echo ""
    step "${name}"
    access_guidance "$id"
    if [[ "$access_type" == "it_ticket" ]]; then
      # Assume no access yet: walk the developer through opening a pre-filled ticket.
      info "Assuming no access yet — let's open a pre-filled IT ticket."
      open_ticket "$name" "$ticket_resource"
      state_set "access_${id}" "pending"
      warn "${name} — ticket opened; re-run Phase 1 once IT grants access."
    elif confirm "  Can you access ${name}?"; then
      mark_step_done "access_${id}"
      ok+=("$name")
    else
      needs+=("$id:$name:$ticket_resource")
    fi
  done

  # IT ticket fallback — for self-service access the user couldn't confirm
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
        local nm=$(echo "$entry" | cut -d: -f2)
        local resource=$(echo "$entry" | cut -d: -f3)
        open_ticket "$nm" "$resource"
        state_set "access_${id}" "pending"
      done
      success "Opened ${#needs[@]} ticket form(s) — re-run Phase 1 once IT grants access."
    else
      dim "Skipped. Re-run Phase 1 anytime to confirm once you have access."
      dim "Stuck? Ask in the Developer Hotline channel."
    fi
  fi

  # VPN client setup guide — fires once VPN access is confirmed.
  setup_vpn_guide

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
  local still=$(( ${#PLATFORMS[@]} - ${#ok[@]} ))
  [[ $still -gt 0 ]] && warn "${still} still need attention — re-run Phase 1 once you've sorted them out"

  echo ""
  info "Re-run this phase anytime ('--phase 1') to confirm access you've since gained."
}

# ── VPN client setup (after IT grants access) ───────────────────────
# Once VPN access is confirmed, point the user to the AWS VPN Client setup
# guide. The guide covers downloading and configuring the client — no install
# happens here.
setup_vpn_guide() {
  is_step_done "access_vpn" || return 0
  is_step_done "vpn_setup" && return 0

  echo ""
  step "AWS VPN Client setup"
  note "VPN access is granted — set up the AWS VPN Client by following this guide:"
  note "  ${CONFLUENCE_VPN_SETUP}"
  if confirm "Open the AWS VPN Client setup guide now?"; then
    open_once "$CONFLUENCE_VPN_SETUP"
  fi
  mark_step_done "vpn_setup"
}
