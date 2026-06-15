#!/bin/bash
# phase4_bookmarks.sh — Generate Chrome bookmarks HTML + install AI/Warp config

run_phase4() {
  header "Phase 4: Bookmarks & AI Tools"

  generate_bookmarks
  setup_warp_config
  setup_claude_config

  echo ""
  success "Phase 4 complete"
}

# ── Chrome Bookmark HTML Generation ─────────────────────────────────
generate_bookmarks() {
  step "Generating Chrome bookmarks..."
  if is_step_done "bookmarks_generated"; then
    dim "Bookmarks already generated"
    return
  fi

  local bookmark_file="${CODE_DIR}/euna-onboard/euna-bookmarks.html"
  local namespace="${DEV_NAMESPACE:-$(echo "$DEV_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')}"

  # Start HTML
  cat > "$bookmark_file" <<'HEADER'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
  <DT><H3>Euna Payments</H3>
  <DL><p>
HEADER

  # Process shared bookmarks
  add_bookmarks_from_json "$bookmark_file" "${CONFIG_DIR}/bookmarks/shared.json" "$namespace"

  # Process team-specific bookmarks
  local team_lower=$(echo "$TEAM_NAME" | tr '[:upper:]' '[:lower:]')
  local team_bookmarks="${CONFIG_DIR}/bookmarks/${team_lower}.json"
  if [[ -f "$team_bookmarks" ]]; then
    add_bookmarks_from_json "$bookmark_file" "$team_bookmarks" "$namespace"
  fi

  # Close HTML
  cat >> "$bookmark_file" <<'FOOTER'
  </DL><p>
</DL><p>
FOOTER

  success "Bookmarks saved to: ${bookmark_file}"
  echo ""
  info "To import into Chrome:"
  dim "1. Open Chrome → Settings → Bookmarks → Import bookmarks"
  dim "2. Select the file: ${bookmark_file}"

  if confirm "Open Chrome bookmarks import page now?"; then
    open_url "chrome://bookmarks/"
    dim "Use 'Import bookmarks' (⋮ menu) and select: ${bookmark_file}"
  fi

  mark_step_done "bookmarks_generated"
}

add_bookmarks_from_json() {
  local output_file="$1" json_file="$2" namespace="$3"

  if ! command_exists jq; then
    warn "jq not found — cannot parse bookmark JSON"
    return 1
  fi

  # Read top-level object keys as folders
  local top_keys=$(jq -r 'to_entries[].key' "$json_file" 2>/dev/null)

  for top_key in ${(f)top_keys}; do
    local sub_keys=$(jq -r ".[\"${top_key}\"] | to_entries[].key" "$json_file" 2>/dev/null)

    for sub_key in ${(f)sub_keys}; do
      echo "    <DT><H3>${sub_key}</H3>" >> "$output_file"
      echo "    <DL><p>" >> "$output_file"

      local entries=$(jq -r ".[\"${top_key}\"][\"${sub_key}\"] | to_entries[] | \"\(.key)|\(.value)\"" "$json_file" 2>/dev/null)

      for entry in ${(f)entries}; do
        local name=$(echo "$entry" | cut -d'|' -f1)
        local url=$(echo "$entry" | cut -d'|' -f2)
        # Replace {namespace} placeholder
        url=$(echo "$url" | sed "s/{namespace}/${namespace}/g")
        echo "      <DT><A HREF=\"${url}\">${name}</A>" >> "$output_file"
      done

      echo "    </DL><p>" >> "$output_file"
    done
  done
}

# ── Warp Configuration ──────────────────────────────────────────────
setup_warp_config() {
  step "Configuring Warp AI tools..."

  if ! command_exists warp 2>/dev/null && [[ ! -d "/Applications/Warp.app" ]]; then
    info "Warp not detected — skipping Warp config"
    dim "Sign up at: ${WARP_SIGNUP_URL}"
    return
  fi

  if is_step_done "warp_config"; then
    dim "Warp already configured"
    return
  fi

  # Copy Warp rules if the rules directory exists
  local warp_rules_dst="${HOME}/.warp/rules"
  if [[ -d "$warp_rules_dst" ]] || [[ -d "${HOME}/Library/Application Support/dev.warp.Warp-Stable" ]]; then
    local rules_src="${AI_DIR}/warp-rules"
    if [[ -d "$rules_src" ]]; then
      ensure_dir "$warp_rules_dst"
      for rule_file in "$rules_src"/*.md; do
        local rule_name=$(basename "$rule_file")
        if [[ ! -f "${warp_rules_dst}/${rule_name}" ]]; then
          cp "$rule_file" "${warp_rules_dst}/${rule_name}"
          success "Installed Warp rule: ${rule_name}"
        else
          dim "Warp rule already exists: ${rule_name}"
        fi
      done
    fi
  else
    dim "Warp rules directory not found — you may need to configure rules manually"
  fi

  mark_step_done "warp_config"
}

# ── Claude Code Configuration ───────────────────────────────────────
setup_claude_config() {
  step "Setting up Claude Code context..."

  if is_step_done "claude_config"; then
    dim "Claude config already set up"
    return
  fi

  local claude_src="${AI_DIR}/CLAUDE.md"
  local claude_dst="${CODE_DIR}/CLAUDE.md"

  if [[ -f "$claude_src" ]]; then
    if [[ ! -f "$claude_dst" ]]; then
      cp "$claude_src" "$claude_dst"
      success "Installed CLAUDE.md to ${claude_dst}"
      dim "This gives Claude Code context about the Euna Payments architecture"
    else
      dim "CLAUDE.md already exists at ${claude_dst}"
    fi
  fi

  mark_step_done "claude_config"
}
