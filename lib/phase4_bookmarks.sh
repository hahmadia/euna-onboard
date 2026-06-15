#!/bin/bash
# phase4_bookmarks.sh — Generate the Chrome bookmarks HTML file

run_phase4() {
  header "Phase 4: Bookmarks"

  generate_bookmarks

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

  # Read top-level object keys as folders.
  # NOTE: iterate with `while read` (bash) — `${(f)var}` is zsh-only and fails
  # under bash with "bad substitution".
  local top_keys=$(jq -r 'to_entries[].key' "$json_file" 2>/dev/null)

  local top_key sub_key entry
  while IFS= read -r top_key; do
    [[ -z "$top_key" ]] && continue
    local sub_keys=$(jq -r ".[\"${top_key}\"] | to_entries[].key" "$json_file" 2>/dev/null)

    while IFS= read -r sub_key; do
      [[ -z "$sub_key" ]] && continue
      echo "    <DT><H3>${sub_key}</H3>" >> "$output_file"
      echo "    <DL><p>" >> "$output_file"

      local entries=$(jq -r ".[\"${top_key}\"][\"${sub_key}\"] | to_entries[] | \"\(.key)|\(.value)\"" "$json_file" 2>/dev/null)

      while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local name=$(echo "$entry" | cut -d'|' -f1)
        local url=$(echo "$entry" | cut -d'|' -f2)
        # Replace {namespace} placeholder
        url=$(echo "$url" | sed "s/{namespace}/${namespace}/g")
        echo "      <DT><A HREF=\"${url}\">${name}</A>" >> "$output_file"
      done <<< "$entries"

      echo "    </DL><p>" >> "$output_file"
    done <<< "$sub_keys"
  done <<< "$top_keys"
}
