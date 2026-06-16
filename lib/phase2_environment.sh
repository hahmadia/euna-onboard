#!/bin/bash
# phase2_environment.sh — Install tools, configure git, shell, GPG

run_phase2() {
  header "Phase 2: Environment Setup"

  setup_homebrew
  setup_brew_packages
  setup_asdf
  setup_gpg
  setup_git
  setup_ssh
  setup_shell_profile

  echo ""
  success "Phase 2 complete — environment is configured"
}

# ── Homebrew ────────────────────────────────────────────────────────
# Put brew on PATH for the current session. The installer drops it at
# /opt/homebrew (Apple Silicon) or /usr/local (Intel) but does not add it to
# PATH for the already-running shell — without this, the brew install/asdf
# steps below fail with "brew: command not found".
load_brew_shellenv() {
  command_exists brew && return
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

setup_homebrew() {
  step "Checking Homebrew..."
  if is_step_done "brew_installed"; then
    dim "Homebrew already set up"
    load_brew_shellenv
    return
  fi

  if command_exists brew; then
    success "Homebrew is installed"
  else
    info "Installing Homebrew..."
    if dry_run_guard "Install Homebrew"; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  fi

  load_brew_shellenv
  mark_step_done "brew_installed"
}

setup_brew_packages() {
  step "Installing Homebrew packages..."
  if is_step_done "brew_packages"; then
    dim "Brew packages already installed"
    return
  fi

  local installed=$(brew list --formula 2>/dev/null)
  local to_install=()

  for pkg in "${BREW_PACKAGES[@]}"; do
    if echo "$installed" | grep -q "^${pkg}$"; then
      dim "${pkg} already installed"
    else
      to_install+=("$pkg")
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    info "Installing: ${to_install[*]}"
    if dry_run_guard "brew install ${to_install[*]}"; then
      brew install "${to_install[@]}"
    fi
  else
    success "All brew packages already installed"
  fi
  mark_step_done "brew_packages"
}

# ── asdf ────────────────────────────────────────────────────────────
setup_asdf() {
  step "Setting up asdf plugins..."
  if is_step_done "asdf_plugins"; then
    dim "asdf plugins already configured"
    return
  fi

  if ! command_exists asdf; then
    warn "asdf not found — install it first (brew install asdf)"
    return 1
  fi

  local installed_plugins=$(asdf plugin list 2>/dev/null)

  for plugin in "${ASDF_PLUGINS[@]}"; do
    if echo "$installed_plugins" | grep -q "^${plugin}$"; then
      dim "asdf plugin '${plugin}' already added"
    else
      info "Adding asdf plugin: ${plugin}"
      if dry_run_guard "asdf plugin add ${plugin}"; then
        asdf plugin add "$plugin"
      fi
    fi
  done

  success "asdf plugins configured"
  dim "Language versions will be installed per-repo from .tool-versions files"
  mark_step_done "asdf_plugins"
}

# ── GPG ─────────────────────────────────────────────────────────────
setup_gpg() {
  step "Setting up GPG for commit signing..."
  if is_step_done "gpg_setup"; then
    dim "GPG already configured"
    return
  fi

  if ! command_exists gpg; then
    warn "gpg not found — install it first (brew install gpg)"
    return 1
  fi

  # Check for existing key
  local email="${DEV_EMAIL:-}"
  if [[ -z "$email" ]]; then
    email=$(prompt_input "Enter your @${EUNA_EMAIL_DOMAIN} email")
  fi

  local existing_key=$(gpg --list-secret-keys --keyid-format=long "$email" 2>/dev/null | grep "sec" | head -1)

  if [[ -n "$existing_key" ]]; then
    success "GPG key found for ${email}"
    local key_id=$(echo "$existing_key" | sed 's/.*\/\([A-F0-9]*\) .*/\1/')
  else
    info "No GPG key found for ${email}"
    info "Generating a new GPG key..."
    dim "When prompted: select RSA and RSA, 4096 bits, no expiration"
    dim "Use your full name and ${email} as the email"

    if confirm "Generate GPG key now?"; then
      if dry_run_guard "gpg --full-generate-key"; then
        gpg --full-generate-key
      fi
    else
      warn "Skipping GPG key generation — you'll need to do this manually"
      dim "Guide: ${CONFLUENCE_GPG_SETUP}"
      return
    fi

    key_id=$(gpg --list-secret-keys --keyid-format=long "$email" 2>/dev/null | grep "sec" | head -1 | sed 's/.*\/\([A-F0-9]*\) .*/\1/')
  fi

  if [[ -n "$key_id" ]]; then
    # Configure git to use this key
    if dry_run_guard "Configure git GPG signing"; then
      git config --global user.signingkey "$key_id"
      git config --global commit.gpgsign true
      git config --global gpg.program "$(which gpg)"
    fi

    # Export public key for GitHub
    echo ""
    info "Your GPG public key (add this to GitHub → Settings → SSH and GPG keys):"
    echo ""
    gpg --armor --export "$key_id" 2>/dev/null
    echo ""
    dim "Copy the key above and add it at: https://github.com/settings/keys"
    wait_for_user
  fi

  # Configure pinentry-mac if available
  if command_exists pinentry-mac; then
    local gpg_agent_conf="${HOME}/.gnupg/gpg-agent.conf"
    ensure_dir "${HOME}/.gnupg"
    if ! grep -q "pinentry-mac" "$gpg_agent_conf" 2>/dev/null; then
      echo "pinentry-program $(which pinentry-mac)" >> "$gpg_agent_conf"
      gpgconf --kill gpg-agent 2>/dev/null
      success "Configured pinentry-mac for GPG passphrase caching"
    fi
  fi

  mark_step_done "gpg_setup"
}

# ── Git Config ──────────────────────────────────────────────────────
setup_git() {
  step "Configuring git..."
  if is_step_done "git_config"; then
    dim "Git already configured"
    return
  fi

  # User name
  local current_name=$(git config --global user.name 2>/dev/null)
  if [[ -z "$current_name" ]]; then
    local name="${DEV_NAME:-}"
    if [[ -z "$name" ]]; then
      name=$(prompt_input "Enter your full name for git commits")
    fi
    if dry_run_guard "git config --global user.name"; then
      git config --global user.name "$name"
    fi
    success "Set git user.name to '${name}'"
  else
    dim "git user.name already set to '${current_name}'"
  fi

  # Email
  local current_email=$(git config --global user.email 2>/dev/null)
  if [[ -z "$current_email" ]] || ! echo "$current_email" | grep -q "${EUNA_EMAIL_DOMAIN}"; then
    local email="${DEV_EMAIL:-}"
    if [[ -z "$email" ]]; then
      email=$(prompt_input "Enter your @${EUNA_EMAIL_DOMAIN} email")
    fi
    if dry_run_guard "git config --global user.email"; then
      git config --global user.email "$email"
    fi
    success "Set git user.email to '${email}'"
  else
    dim "git user.email already set to '${current_email}'"
  fi

  # Commit template
  local template_src="${TEMPLATE_DIR}/gitmessage"
  local template_dst="${HOME}/.gitmessage"
  if [[ ! -f "$template_dst" ]]; then
    if dry_run_guard "Install git commit template"; then
      cp "$template_src" "$template_dst"
      git config --global commit.template "$template_dst"
    fi
    success "Installed git commit template"
  else
    dim "Git commit template already exists"
  fi

  mark_step_done "git_config"
}

# ── SSH (GitHub) ────────────────────────────────────────────────────
# Generates an SSH key, configures it, and — importantly — pre-trusts
# github.com so Phase 3 cloning doesn't stall on the interactive
# "authenticity of host 'github.com' can't be established" prompt.
setup_ssh() {
  step "Setting up SSH for GitHub..."
  if is_step_done "ssh_setup"; then
    dim "SSH already configured"
    return
  fi

  local ssh_dir="${HOME}/.ssh"
  ensure_dir "$ssh_dir"
  chmod 700 "$ssh_dir" 2>/dev/null

  # Pre-trust github.com (fixes the host-key prompt that hangs cloning)
  local known_hosts="${ssh_dir}/known_hosts"
  if ssh-keygen -F github.com -f "$known_hosts" &>/dev/null; then
    dim "github.com already trusted in known_hosts"
  elif dry_run_guard "ssh-keyscan github.com >> known_hosts"; then
    ssh-keyscan github.com >> "$known_hosts" 2>/dev/null
    success "Added github.com to known_hosts"
  fi

  # Generate an SSH key if there isn't one
  local key_file="${ssh_dir}/id_ed25519"
  if [[ -f "$key_file" ]]; then
    dim "SSH key already exists at ${key_file}"
  else
    local email="${DEV_EMAIL:-}"
    [[ -z "$email" ]] && email=$(prompt_input "Enter your @${EUNA_EMAIL_DOMAIN} email for the SSH key")
    info "Generating an ed25519 SSH key..."
    if dry_run_guard "ssh-keygen -t ed25519 -C ${email}"; then
      ssh-keygen -t ed25519 -C "$email" -f "$key_file" -N "" &>/dev/null
      success "Generated SSH key at ${key_file}"
    fi
  fi

  # Use the key automatically (macOS keychain)
  local ssh_config="${ssh_dir}/config"
  if ! grep -q "Host github.com" "$ssh_config" 2>/dev/null; then
    if dry_run_guard "Write ~/.ssh/config for github.com"; then
      cat >> "$ssh_config" <<EOF

Host github.com
  HostName github.com
  User git
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ${key_file}
EOF
      chmod 600 "$ssh_config" 2>/dev/null
      success "Configured ~/.ssh/config for github.com"
    fi
  fi

  if dry_run_guard "Add SSH key to ssh-agent"; then
    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add --apple-use-keychain "$key_file" &>/dev/null || ssh-add "$key_file" &>/dev/null
  fi

  # Add the public key to GitHub
  if [[ -f "${key_file}.pub" ]]; then
    echo ""
    info "Add this SSH public key to GitHub (Settings → SSH and GPG keys → New SSH key):"
    echo ""
    cat "${key_file}.pub"
    echo ""
    command_exists pbcopy && pbcopy < "${key_file}.pub" && dim "(Copied to your clipboard)"
    dim "Add it at: https://github.com/settings/ssh/new"
    dim "To verify: after adding, go to GitHub → Settings → SSH and GPG keys and confirm the key is listed."
    if dry_run_guard "open GitHub SSH key settings"; then
      open_url "https://github.com/settings/ssh/new"
    fi
    echo ""
    warn "One more step: click 'Configure SSO' next to your new key and Authorize it for"
    note "  ${GITHUB_ORG} and ${GITHUB_ORG_PAYMENTS} — without this, cloning org repos in Phase 3 will fail."
    wait_for_user "Press Enter once you've added the key AND authorized SSO..."
  fi

  mark_step_done "ssh_setup"
}

# ── Shell Profile ───────────────────────────────────────────────────
setup_shell_profile() {
  step "Configuring shell profile (.zshrc)..."
  if is_step_done "shell_profile"; then
    dim "Shell profile already configured"
    return
  fi

  local zshrc="${HOME}/.zshrc"
  [[ -f "$zshrc" ]] || touch "$zshrc"

  local additions=$(cat "${TEMPLATE_DIR}/zshrc_additions.sh")
  if dry_run_guard "Append to .zshrc"; then
    append_block "$zshrc" "euna-onboard" "$additions"
  fi

  mark_step_done "shell_profile"
}
