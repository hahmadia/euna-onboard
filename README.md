# euna-onboard

Automated developer onboarding CLI for the Euna Payments engineering org.

Replaces the manual Jira epic cloning process (EADM-615 template) and the Confluence onboarding checklist with a single, idempotent, team-aware script that gets a new developer from zero to productive.

## Prerequisites

This script is built to run on a brand-new Mac with nothing installed. The only thing you need up front is **git**, which comes bundled with the Xcode Command Line Tools:

```bash
xcode-select --install
```

Complete the popup it triggers and wait for the install to finish. Everything else — Homebrew, asdf, language runtimes, GPG — is installed for you in Phase 2.

## Quick Start

The repo is public, so clone it over HTTPS — no SSH keys or GitHub login required:

```bash
# Clone into Downloads (or anywhere you like)
git clone https://github.com/hahmadia/euna-onboard.git ~/Downloads/euna-onboard
cd ~/Downloads/euna-onboard

# Easiest: interactive wizard asks for your team and name
./euna-onboard.sh

# Or preview without making any changes, then do a real run
./euna-onboard.sh --dry-run
./euna-onboard.sh --team web --name "Jane Smith"
```

The script finds its own location, so it works from anywhere (`~/Downloads`, `~/code`, etc.) and still clones your team repos into `~/code/`. git preserves the executable bit, so `./euna-onboard.sh` runs as-is; if it doesn't, use `bash euna-onboard.sh ...`.

> **Have SSH keys already?** Contributors can clone via `git@github.com:hahmadia/euna-onboard.git` instead.

## What It Does

The script runs 5 phases in order. Each phase is idempotent — safe to re-run if something fails. Progress is saved to `.euna-onboard-state` in the repo (gitignored) so you can resume where you left off.

### Phase 1: Access Audit
- Guides you through self-service access (SSO via the M365 apps portal, or direct logins) for GitHub, AWS, Coralogix, Airbrake, JIRA, etc., and asks you to confirm each
- For IT-gated access (AWS VPN, GemFury, NPM org, 1Password, Sisense) it assumes you don't have it yet on the first run, opens a pre-filled IT ticket, and copies a console autofill snippet to your clipboard — it only asks whether access came through on later runs
- Once VPN access is confirmed, points you to the AWS VPN Client setup guide

### Phase 2: Environment Setup
- Installs Homebrew packages (gpg, asdf, kubectl, k9s, stern, etc.)
- Sets up asdf with ruby, nodejs, erlang, elixir plugins
- Generates GPG key and configures git commit signing
- Installs CityBase git commit template

### Phase 3: Clone Repositories
- Clones all team-specific repos into `~/code/`
- That's it — it does **not** run `asdf install` or install dependencies. The tools are installed in Phase 2, but setting up each repo (runtime versions + `npm install` / `mix deps.get` / `bundle install`) is left to you, per that repo's README
- Reports which repos cloned and which need attention (e.g. GitHub access)

### Phase 4: Bookmarks
- Generates a Chrome-importable bookmarks HTML file with all environment URLs
- Bookmarks are team-aware (Web gets RevM/NFE links, InPerson gets POS/Kiosk, etc.)

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
  --email "email"     Your @eunasolutions.com email
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

## Contributing

To update the onboarding process:
1. Edit the relevant config file in `config/`
2. Update bookmark URLs in `config/bookmarks/`
3. Test with `--dry-run` before merging

## Acknowledgments

Built for AI Innovation Week 2026.
Inspired by the [Bonfire AI Onboarding Concierge](https://github.com/Procurement-Bonfire/bonfire-ai-onboarding-concierge).
