# euna-onboard

Automated developer onboarding CLI for the Euna Payments engineering org.

Replaces the manual Jira epic cloning process (EADM-615 template) and the Confluence onboarding checklist with a single, idempotent, team-aware script that gets a new developer from zero to productive.

## Quick Start

```bash
# Clone this repo
git clone git@github.com:CityBaseInc/euna-onboard.git ~/code/euna-onboard

# Make it executable
chmod +x ~/code/euna-onboard/euna-onboard.sh

# Run it
~/code/euna-onboard/euna-onboard.sh --team web --name "Jane Smith"
```

## What It Does

The script runs 5 phases in order. Each phase is idempotent — safe to re-run if something fails. Progress is saved to `~/.euna-onboard-state` so you can resume where you left off.

### Phase 1: Access Audit
- Checks your access to 12+ platforms (GitHub, AWS, GemFury, NPM, etc.)
- Opens pre-filled IT ticket forms for any missing access
- Tracks pending IT tickets so you can move on and re-check later

### Phase 2: Environment Setup
- Installs Homebrew packages (gpg, asdf, kubectl, k9s, stern, etc.)
- Sets up asdf with ruby, nodejs, erlang, elixir plugins
- Generates GPG key and configures git commit signing
- Installs CityBase git commit template
- Adds k8s aliases and tool config to `.zshrc`

### Phase 3: Repository Setup
- Clones all team-specific repos into `~/code/`
- Installs asdf versions from each repo's `.tool-versions`
- Runs `mix deps.get`, `npm install`, or `bundle install` per repo
- Reports which repos succeeded and which need manual attention

### Phase 4: Bookmarks & AI
- Generates a Chrome-importable bookmarks HTML file with all environment URLs
- Bookmarks are team-aware (Web gets RevM/NFE links, InPerson gets POS/Kiosk, etc.)
- Installs Warp rules for repo abbreviations and team context
- Sets up `CLAUDE.md` with architecture context for Claude Code

### Phase 5: Verification
- Smoke-tests all tools, configs, access, and repos
- Prints a color-coded report card (✅/⏳/❌)
- Shows recommended next steps (deployment process, ArgoCD setup, etc.)

## Usage

```
./euna-onboard.sh --team <team> [OPTIONS]

REQUIRED:
  --team <team>       web, inperson, or platform

OPTIONS:
  --name "Name"       Your full name (for git config)
  --email "email"     Your @thecitybase.com email
  --phase N           Start from phase N (1-5)
  --dry-run           Preview without making changes
  --verify            Run verification only (Phase 5)
  --reset             Clear saved progress and start fresh
```

## Team Configs

Each team has its own config file in `config/` that defines:
- Which repos to clone
- Team-specific MS Teams channels
- JIRA boards and meetings
- Bookmark URLs for team-specific environments

| Team | Config | Repos |
|------|--------|-------|
| Web | `config/web.conf` | NFE, RevM, Citizen Dash, cb-components, PAPI, Ghenghis, GQL, etc. |
| InPerson | `config/inperson.conf` | cb_pos, pos-frontend, kiosk_interface, device_drivers, etc. |
| Platform | `config/platform.conf` | Ghenghis, GQL Interface, FLS, CATO, cb_relay, etc. |

## AI Tools

The script installs:
- **`CLAUDE.md`** — Architecture context, repo dependency graph, common commands, and troubleshooting FAQ for Claude Code
- **Warp rules** — Repo abbreviations and team context so Warp AI understands your codebase

## Contributing

To update the onboarding process:
1. Edit the relevant config file in `config/`
2. Update bookmark URLs in `config/bookmarks/`
3. Update the AI context in `ai/CLAUDE.md`
4. Test with `--dry-run` before merging

## Acknowledgments

Built for AI Innovation Week 2026.
Inspired by the [Bonfire AI Onboarding Concierge](https://github.com/Procurement-Bonfire/bonfire-ai-onboarding-concierge).
