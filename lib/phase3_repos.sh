#!/usr/bin/env zsh
# phase3_repos.sh — Clone and set up team-specific repositories

run_phase3() {
  header "Phase 3: Repository Setup"

  ensure_dir "$CODE_DIR"

  local total=${#REPOS[@]}
  local cloned=0
  local setup_ok=0
  local setup_fail=0
  local skipped=0

  info "Setting up ${total} repositories for ${TEAM_DISPLAY}..."
  echo ""

  for repo_entry in "${REPOS[@]}"; do
    local org_repo=$(echo "$repo_entry" | cut -d: -f1)
    local local_dir=$(echo "$repo_entry" | cut -d: -f2)
    local stack_type=$(echo "$repo_entry" | cut -d: -f3)
    local repo_path="${CODE_DIR}/${local_dir}"
    local repo_name=$(basename "$org_repo")

    step "${repo_name} (${stack_type})"

    # Clone if needed
    if [[ -d "$repo_path" ]]; then
      dim "Already cloned at ${repo_path}"
    else
      info "Cloning ${org_repo}..."
      if dry_run_guard "git clone git@github.com:${org_repo}.git ${repo_path}"; then
        if git clone "git@github.com:${org_repo}.git" "$repo_path" 2>/dev/null; then
          success "Cloned ${repo_name}"
          cloned=$((cloned + 1))
        else
          fail "Failed to clone ${repo_name} — do you have GitHub access?"
          setup_fail=$((setup_fail + 1))
          continue
        fi
      fi
    fi

    # Skip dependency install for static repos
    if [[ "$stack_type" == "static" ]]; then
      dim "Static repo — no deps to install"
      skipped=$((skipped + 1))
      continue
    fi

    # Install asdf versions if .tool-versions exists
    if [[ -f "${repo_path}/.tool-versions" ]]; then
      if is_step_done "repo_asdf_${local_dir}"; then
        dim "asdf versions already installed"
      else
        info "Installing asdf versions for ${repo_name}..."
        if dry_run_guard "asdf install in ${repo_path}"; then
          (cd "$repo_path" && asdf install 2>/dev/null)
          if [[ $? -eq 0 ]]; then
            mark_step_done "repo_asdf_${local_dir}"
          else
            warn "asdf install had issues — you may need to install versions manually"
          fi
        fi
      fi
    fi

    # Install dependencies based on stack type
    if is_step_done "repo_deps_${local_dir}"; then
      dim "Dependencies already installed"
      setup_ok=$((setup_ok + 1))
      continue
    fi

    setup_repo_deps "$repo_path" "$stack_type" "$repo_name" "$local_dir"
    if [[ $? -eq 0 ]]; then
      setup_ok=$((setup_ok + 1))
    else
      setup_fail=$((setup_fail + 1))
    fi
  done

  echo ""
  header "Repo Setup Summary"
  success "${cloned} newly cloned"
  success "${setup_ok} with deps installed"
  [[ $setup_fail -gt 0 ]] && fail "${setup_fail} had issues (may need manual attention)"
  [[ $skipped -gt 0 ]] && dim "${skipped} static repos (no deps needed)"
}

# ── Dependency installation per stack type ──────────────────────────
setup_repo_deps() {
  local repo_path="$1" stack_type="$2" repo_name="$3" local_dir="$4"

  case "$stack_type" in
    elixir)
      setup_elixir_deps "$repo_path" "$repo_name" "$local_dir"
      ;;
    node)
      setup_node_deps "$repo_path" "$repo_name" "$local_dir"
      ;;
    ruby)
      setup_ruby_deps "$repo_path" "$repo_name" "$local_dir"
      ;;
    *)
      dim "Unknown stack type '${stack_type}' — skipping deps"
      return 0
      ;;
  esac
}

setup_elixir_deps() {
  local repo_path="$1" repo_name="$2" local_dir="$3"

  if ! command_exists mix; then
    warn "mix not found — install Elixir via asdf first"
    return 1
  fi

  info "Installing Elixir deps for ${repo_name}..."
  if dry_run_guard "mix deps.get in ${repo_path}"; then
    (cd "$repo_path" && mix local.hex --force 2>/dev/null && mix local.rebar --force 2>/dev/null && mix deps.get 2>&1)
    if [[ $? -eq 0 ]]; then
      success "Elixir deps installed for ${repo_name}"
      mark_step_done "repo_deps_${local_dir}"
      return 0
    else
      warn "mix deps.get failed for ${repo_name} — check error output above"
      dim "You may need GemFury token or other credentials"
      return 1
    fi
  fi
}

setup_node_deps() {
  local repo_path="$1" repo_name="$2" local_dir="$3"

  if ! command_exists npm; then
    warn "npm not found — install Node.js via asdf first"
    return 1
  fi

  info "Installing Node deps for ${repo_name}..."

  # Check for .npmrc or registry config needs
  if [[ -f "${repo_path}/.npmrc" ]] && grep -q "fury" "${repo_path}/.npmrc" 2>/dev/null; then
    if [[ -z "$GEMFURY_TOKEN" ]] && [[ -z "$BUNDLE_GEM__FURY__IO" ]]; then
      warn "${repo_name} requires GemFury token for npm install"
      dim "Set GEMFURY_TOKEN in your shell profile after receiving it from IT"
      return 1
    fi
  fi

  if dry_run_guard "npm install in ${repo_path}"; then
    (cd "$repo_path" && npm install 2>&1)
    if [[ $? -eq 0 ]]; then
      success "Node deps installed for ${repo_name}"
      mark_step_done "repo_deps_${local_dir}"
      return 0
    else
      warn "npm install failed for ${repo_name}"
      dim "Check if you need NPM org access or GemFury token"
      return 1
    fi
  fi
}

setup_ruby_deps() {
  local repo_path="$1" repo_name="$2" local_dir="$3"

  if ! command_exists bundle; then
    warn "bundle not found — install Ruby via asdf first"
    return 1
  fi

  info "Installing Ruby deps for ${repo_name}..."
  if dry_run_guard "bundle install in ${repo_path}"; then
    (cd "$repo_path" && bundle install 2>&1)
    if [[ $? -eq 0 ]]; then
      success "Ruby deps installed for ${repo_name}"
      mark_step_done "repo_deps_${local_dir}"
      return 0
    else
      warn "bundle install failed for ${repo_name}"
      return 1
    fi
  fi
}
