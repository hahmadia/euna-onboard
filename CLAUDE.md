# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-purpose CLI that onboards a new Euna Payments developer end-to-end: audits platform access, sets up the local dev environment, clones team repos, generates browser/AI config, and verifies the result. It is meant to replace the manual Jira epic + Confluence checklist process. There is no build step, no package manager, and no test framework — it's a tree of Bash/zsh scripts driven by shell-array config files.

## Running it

The entrypoint resolves its own directory via `${BASH_SOURCE[0]}`, so it can be run from anywhere:

```bash
./euna-onboard.sh --team web --name "Jane Smith"   # full run
./euna-onboard.sh --team web --dry-run             # preview; makes no changes
./euna-onboard.sh --team web --verify              # Phase 5 only (report card)
./euna-onboard.sh --team web --phase 3             # resume from a phase
./euna-onboard.sh --reset                          # clear saved state
./euna-onboard.sh                                  # interactive wizard (no args)
```

Valid teams: `web`, `inperson`, `platform`. There is no single-test command — verify behavior changes with `--dry-run` (the safe path) and inspect the report card from `--verify`.

## Architecture

**Orchestrator → phases → shared lib → config.** `euna-onboard.sh` parses args, resolves team, sources the config files and all phase scripts, then calls `run_phase1` … `run_phase5` in order (gated by `--phase`). Each phase is a function defined in its own `lib/phaseN_*.sh` file:

- `phase1_access.sh` — audits access to platforms in the `PLATFORMS` array; each platform names a check function (e.g. `gh_org_check`, `aws_check`). Checks return 0=ok, 1=missing, 2=manual/unknown. Missing items open pre-filled IT ticket forms via `IT_TICKET_BASE`.
- `phase2_environment.sh` — Homebrew packages, asdf + plugins, GPG key + git signing, git commit template, `.zshrc` additions.
- `phase3_repos.sh` — clones each entry in the team's `REPOS` array into `~/code/` and nothing more. It deliberately does **not** run `asdf install` or install dependencies; runtime/dependency setup is left to the developer per each repo's README. (`stack_type` in `REPOS` is now just metadata.)
- `phase4_bookmarks.sh` — generates Chrome bookmarks HTML, Warp rules, and `CLAUDE.md` from `config/bookmarks/` and `ai/`.
- `phase5_verify.sh` — smoke-tests tools/configs/repos and prints a ✅/⏳/❌ report card.

**`lib/common.sh`** is the shared library every phase relies on: color vars, logging helpers (`info`/`success`/`warn`/`fail`/`step`/`dim`), prompts (`confirm`, `prompt_input`, `prompt_select` → sets `$REPLY`), idempotent file editing (`append_block` with START/END markers), and path vars (`SCRIPT_DIR`, `CONFIG_DIR`, `TEMPLATE_DIR`, `AI_DIR`).

**State & idempotency.** Progress is a JSON file at `~/.euna-onboard-state` (uses `jq` if present, else a grep/sed fallback). Every phase guards work with `is_step_done "<key>"` / `mark_step_done "<key>"`, so re-running is safe and resumes where it left off. `--reset` deletes the state file.

**Dry-run.** Any side-effecting command must be wrapped in `dry_run_guard "<description>"` — it prints the intended action and returns non-zero (skipping execution) when `DRY_RUN=true`. Preserve this pattern when adding new actions.

## Config files (the data layer)

Config lives in `config/` and is plain shell sourced into the environment — there is no parser. `shared.conf` loads first, then `<team>.conf`. Several arrays use **colon-delimited records** parsed with `cut -d:`:

- `PLATFORMS` (shared): `id:display_name:check_command:ticket_resource`
- `REPOS` (per team): `org/repo:local_dir:stack_type`

To change onboarding behavior, edit these arrays rather than the phase logic — e.g. add a repo by appending a `REPOS` line, add an access check by adding a `PLATFORMS` line plus a matching check function in `phase1_access.sh`. Confluence/URL constants also live in `shared.conf`.

## Conventions & gotchas

- **Bash, not zsh.** All scripts and `.conf` files are `#!/bin/bash` and must stay bash-compatible — **arrays are 0-indexed** (`prompt_select`/`prompt_choice` map the 1-based number the user sees to a 0-based index), colors are defined with ANSI-C `$'\033[...'` quoting (so plain `echo` prints the real ESC byte without needing `-e`), and directories resolve via `${BASH_SOURCE[0]}`. Avoid reintroducing zsh idioms like `${0:A:h}`, 1-based array access, or relying on `echo` to interpret `\n`/`\033`.
- Prompts that return a value write the prompt text to **stderr** and the value to stdout (so `$(...)` capture works) — follow that when adding prompts.
- New idempotent edits to dotfiles should go through `append_block` with a unique marker, not raw `>>`.
