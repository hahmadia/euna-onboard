#!/bin/bash
# phase3_repos.sh — Clone team repositories (cloning only)
#
# This phase clones the team's repos into ~/code/. It deliberately does NOT
# run `asdf install` or install dependencies (npm install / mix deps.get /
# bundle install) — the tools are installed in Phase 2, but actually setting
# up each repo is left to the developer to do per that repo's README.

run_phase3() {
  header "Phase 3: Clone Repositories"
  info "Cloning repos only — set each one up yourself per its README (asdf install, then deps)."
  echo ""

  ensure_dir "$CODE_DIR"

  local total=${#REPOS[@]}
  local cloned=0
  local already=0
  local failed=0

  info "Cloning ${total} repositories for ${TEAM_DISPLAY} into ${CODE_DIR}/..."
  echo ""

  for repo_entry in "${REPOS[@]}"; do
    local org_repo=$(echo "$repo_entry" | cut -d: -f1)
    local local_dir=$(echo "$repo_entry" | cut -d: -f2)
    local repo_path="${CODE_DIR}/${local_dir}"
    local repo_name=$(basename "$org_repo")

    step "${repo_name}"

    if [[ -d "$repo_path" ]]; then
      dim "Already cloned at ${repo_path}"
      already=$((already + 1))
      continue
    fi

    info "Cloning ${org_repo}..."
    if dry_run_guard "git clone git@github.com:${org_repo}.git ${repo_path}"; then
      if git clone "git@github.com:${org_repo}.git" "$repo_path" 2>/dev/null; then
        success "Cloned ${repo_name}"
        cloned=$((cloned + 1))
      else
        fail "Failed to clone ${repo_name} — do you have GitHub access?"
        failed=$((failed + 1))
      fi
    fi
  done

  echo ""
  header "Clone Summary"
  success "${cloned} newly cloned"
  [[ $already -gt 0 ]] && dim "${already} already present"
  [[ $failed -gt 0 ]] && fail "${failed} failed to clone (check GitHub access)"

  echo ""
  info "Next: set up each repo yourself per its README — cd into it, run 'asdf install', then 'npm install' / 'mix deps.get' / 'bundle install'."
}
