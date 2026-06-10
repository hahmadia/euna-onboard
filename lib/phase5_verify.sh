#!/usr/bin/env zsh
# phase5_verify.sh — Verify everything is set up, print report card

run_phase5() {
  header "Phase 5: Verification Report"

  local pass=0
  local fail_count=0
  local pending_count=0
  local report_lines=()

  # ── Tools ─────────────────────────────────────────────────────────
  echo "${BOLD}Tools${NC}"
  check_tool "Homebrew"     "brew --version"
  check_tool "asdf"         "asdf --version"
  check_tool "GPG"          "gpg --version"
  check_tool "kubectl"      "kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null"
  check_tool "k9s"          "k9s version --short 2>/dev/null || command -v k9s"
  check_tool "stern"        "stern --version"
  check_tool "GitHub CLI"   "gh --version"
  check_tool "AWS CLI"      "aws --version"
  check_tool "jq"           "jq --version"
  echo ""

  # ── Git Config ────────────────────────────────────────────────────
  echo "${BOLD}Git Configuration${NC}"
  check_config "user.name"       "$(git config --global user.name 2>/dev/null)"
  check_config "user.email"      "$(git config --global user.email 2>/dev/null)"
  check_config "commit.gpgsign"  "$(git config --global commit.gpgsign 2>/dev/null)"
  check_config "commit.template" "$(git config --global commit.template 2>/dev/null)"

  local gpg_key=$(git config --global user.signingkey 2>/dev/null)
  if [[ -n "$gpg_key" ]]; then
    success "GPG signing key: ${gpg_key}"
  else
    fail "GPG signing key: not configured"
  fi
  echo ""

  # ── asdf Plugins ──────────────────────────────────────────────────
  echo "${BOLD}asdf Plugins${NC}"
  local installed_plugins=$(asdf plugin list 2>/dev/null)
  for plugin in "${ASDF_PLUGINS[@]}"; do
    if echo "$installed_plugins" | grep -q "^${plugin}$"; then
      local ver=$(asdf current "$plugin" 2>/dev/null | awk '{print $2}')
      success "${plugin}: ${ver:-installed}"
    else
      fail "${plugin}: not installed"
    fi
  done
  echo ""

  # ── Shell Profile ─────────────────────────────────────────────────
  echo "${BOLD}Shell Profile${NC}"
  if grep -q "euna-onboard" "${HOME}/.zshrc" 2>/dev/null; then
    success ".zshrc contains euna-onboard block"
  else
    fail ".zshrc missing euna-onboard configuration"
  fi
  echo ""

  # ── Platform Access ───────────────────────────────────────────────
  echo "${BOLD}Platform Access${NC}"
  for platform_entry in "${PLATFORMS[@]}"; do
    local id=$(echo "$platform_entry" | cut -d: -f1)
    local name=$(echo "$platform_entry" | cut -d: -f2)

    local state=$(state_get "access_${id}")
    case "$state" in
      done)
        success "${name}"
        pass=$((pass + 1))
        ;;
      pending)
        warn "${name} — IT ticket pending"
        pending_count=$((pending_count + 1))
        ;;
      *)
        fail "${name} — not verified"
        fail_count=$((fail_count + 1))
        ;;
    esac
  done
  echo ""

  # ── Repositories ──────────────────────────────────────────────────
  echo "${BOLD}Repositories (${TEAM_NAME} team)${NC}"
  for repo_entry in "${REPOS[@]}"; do
    local local_dir=$(echo "$repo_entry" | cut -d: -f2)
    local stack_type=$(echo "$repo_entry" | cut -d: -f3)
    local repo_path="${CODE_DIR}/${local_dir}"

    if [[ ! -d "$repo_path" ]]; then
      fail "${local_dir} — not cloned"
      fail_count=$((fail_count + 1))
    elif [[ "$stack_type" == "static" ]]; then
      success "${local_dir} — cloned"
      pass=$((pass + 1))
    elif is_step_done "repo_deps_${local_dir}"; then
      success "${local_dir} — cloned + deps installed"
      pass=$((pass + 1))
    else
      warn "${local_dir} — cloned but deps not installed"
      pending_count=$((pending_count + 1))
    fi
  done
  echo ""

  # ── Bookmarks & AI ───────────────────────────────────────────────
  echo "${BOLD}Bookmarks & AI${NC}"
  if is_step_done "bookmarks_generated"; then
    success "Chrome bookmarks generated"
  else
    fail "Chrome bookmarks not generated"
  fi

  if [[ -f "${CODE_DIR}/CLAUDE.md" ]]; then
    success "CLAUDE.md installed"
  else
    warn "CLAUDE.md not installed"
  fi
  echo ""

  # ── Summary ───────────────────────────────────────────────────────
  header "Overall Status"
  echo ""
  echo "  ${GREEN}✓ Passed:${NC}  ${pass}"
  echo "  ${YELLOW}⏳ Pending:${NC} ${pending_count}"
  echo "  ${RED}✗ Failed:${NC}  ${fail_count}"
  echo ""

  if [[ $fail_count -eq 0 ]] && [[ $pending_count -eq 0 ]]; then
    echo "  ${GREEN}${BOLD}🎉 You're fully set up! Welcome to Euna Payments!${NC}"
  elif [[ $fail_count -eq 0 ]]; then
    echo "  ${YELLOW}Almost there! ${pending_count} items are pending (likely IT tickets).${NC}"
    echo "  ${DIM}Re-run to check again once IT tickets are resolved.${NC}"
  else
    echo "  ${RED}${fail_count} items need attention.${NC}"
    echo "  ${DIM}Re-run individual phases to fix: ./euna-onboard.sh --phase N${NC}"
  fi

  # ── Next Steps ────────────────────────────────────────────────────
  echo ""
  header "Recommended Next Steps"
  echo "  1. Review the deployment process: ${CONFLUENCE_DEPLOYMENT}"
  echo "  2. Set up your ArgoCD namespace: ${CONFLUENCE_ARGOCD}"
  echo "  3. Review the PR process: ${CONFLUENCE_PR_PROCESS}"
  echo "  4. Explore the architecture via C4 diagrams: ${C4_DIAGRAMS_REPO}"
  echo "  5. Complete your compliance training: ${COMPLIANCE_TRAINING_URL}"
  echo "  6. Write your onboarding feedback: ${CONFLUENCE_ONBOARDING}"
  echo ""
  dim "Tip: Use Claude Code or Warp AI to ask questions about the codebase!"
  dim "Example: 'What repos do I need running to test Revenue Management Dashboard locally?'"
}

# ── Helper functions ────────────────────────────────────────────────
check_tool() {
  local name="$1" cmd="$2"
  if eval "$cmd" &>/dev/null; then
    success "${name}"
  else
    fail "${name} — not found"
  fi
}

check_config() {
  local key="$1" value="$2"
  if [[ -n "$value" ]]; then
    success "${key}: ${value}"
  else
    fail "${key}: not set"
  fi
}
