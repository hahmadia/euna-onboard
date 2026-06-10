# Euna Payments — Developer Context

## Overview
Euna Payments (formerly CityBase) is an enterprise payment platform serving government agencies and utilities. The platform handles online, in-person, and kiosk-based payments with reconciliation, reporting, and financial back-office operations.

## Team Structure
- **Web (Online Payments)** — Web-based payment UIs (checkout, wallet, recurring), revenue management, and citizen dashboards
- **In-Person** — Cashiering/POS, kiosk hardware integration, device payment services
- **Platform** — Core payment processing, lookups, reporting, EOP, disbursements
- **DevOps** — Infrastructure, CI/CD, monitoring, security

## Key Services & Repo Dependency Graph

### Core Backend
- **Ghenghis** (Elixir/Phoenix) — Central payment processing engine. Almost everything depends on this.
- **GraphQL Service** (Elixir) — GraphQL API layer on top of Ghenghis
- **Payment API** (Elixir) — Payment processing API
- **GQL Interface** (Elixir) — Alternative GraphQL interface for Platform team

### Web Frontend
- **Navigate Frontend** (React) — Citizen-facing payment portal. Depends on: Ghenghis, GraphQL Service
- **Revenue Management Dashboard** (React) — Admin dashboard for payment management. Depends on: Ghenghis, GraphQL Service
- **Citizen Dashboard** (React) — Citizen account management. Depends on: Ghenghis, GraphQL Service
- **cb-components** (React) — Shared component library used by all frontends

### In-Person
- **cb_pos** (Elixir) — Point-of-sale backend. Depends on: Ghenghis
- **pos-frontend** (React) — Cashiering UI. Depends on: cb_pos
- **kiosk_interface** (React) — Kiosk payment UI. Depends on: Ghenghis, GraphQL Service
- **device_drivers** (Elixir) — Hardware device integration
- **device_payment_service** (Elixir) — Payment device management

### Supporting Services
- **File Lookup Service** (Elixir) — File/document lookup
- **Schedule Service** (Elixir) — Payment scheduling
- **Audit Service** (Elixir) — Audit trail
- **Bank Account Service** (Elixir) — Bank account management
- **Invoice Service** (Elixir) — Invoice processing
- **cb_relay** (Elixir) — API relay/proxy with OpenAPI validation
- **Message Service** (Elixir) — Notifications

## "To run X, you need Y" Quick Reference

| I want to work on... | I need running locally... |
|---|---|
| Navigate Frontend | ghenghis, graphql_service |
| Revenue Management Dashboard | ghenghis, graphql_service |
| Citizen Dashboard | ghenghis, graphql_service |
| cb-components | Just the component library (standalone) |
| POS Frontend | cb_pos, ghenghis |
| Kiosk Interface | ghenghis, graphql_service |
| Payment API | ghenghis |
| Any Elixir service | PostgreSQL, Redis |

## Environment URL Patterns
- **Dev**: `https://[app]-[your-namespace].dev.cityba.se`
- **UAT Seeds**: `https://[app]-seeds.uat.cityba.se`
- **UAT Serve**: `https://[app]-serve.uat.cityba.se`
- **Prod**: `https://[app].thecitybase.com` or similar
- **Internal (VPN)**: `https://[service]-[namespace].internal.[env].cityba.se`
- **ArgoCD**: `https://argo[env].cityba.se/applications`

## Tech Stack
- **Backend**: Elixir/Phoenix, PostgreSQL, Redis, NATS
- **Frontend**: React, Redux, Node.js
- **Shared packages**: @thecb/components (npm), GemFury (private packages)
- **Infrastructure**: Kubernetes (EKS), ArgoCD, Helm charts (app-state repo)
- **Monitoring**: Coralogix (logs), Airbrake (errors), Grafana (metrics), Sisense (analytics)
- **Auth**: Okta SSO, JumpCloud
- **CI/CD**: GitHub Actions, ArgoCD

## Common Development Commands

### Elixir/Phoenix repos
```bash
mix deps.get          # Install dependencies
mix ecto.setup        # Create DB + run migrations + seed
mix phx.server        # Start the server
mix test              # Run tests
iex -S mix            # Interactive shell with app loaded
```

### React/Node repos
```bash
npm install           # Install dependencies
npm start             # Start dev server
npm test              # Run tests
npm run build         # Production build
```

### Kubernetes
```bash
kubectl --context=dev get pods -n [namespace]    # List pods
kubectl --context=dev logs [pod] -f              # Tail logs
stern [pod-pattern] --context=dev                # Better log tailing
k9s --context=dev --namespace=[ns]               # Terminal UI for k8s
```

### ArgoCD Namespace
See: https://eunasolutions.atlassian.net/wiki/spaces/DEV/pages/1101633144

## Troubleshooting FAQ

**Q: npm install fails with 401/403 on @thecb packages**
A: You need a GemFury token. Set `GEMFURY_TOKEN` in your `.zshrc`. Get the token from IT.

**Q: mix deps.get fails on private packages**
A: Same as above — GemFury token needed. Set `BUNDLE_GEM__FURY__IO` in `.zshrc`.

**Q: Can't reach internal services**
A: You need to be on the AWS VPN. Connect via the VPN client.

**Q: GPG signing fails on commits**
A: Run `export GPG_TTY=$(tty)` or add it to your `.zshrc`. Also ensure `pinentry-mac` is configured.

**Q: asdf shows wrong version**
A: Check `which [lang]` points to `.asdf/shims/`. If not, ensure asdf is initialized in `.zshrc`.

## Key Confluence Pages
- Team Resources: https://eunasolutions.atlassian.net/wiki/spaces/PROD/pages/1099846596
- Deployment Process: https://eunasolutions.atlassian.net/wiki/spaces/PROD/pages/1101633872
- PR Process: https://eunasolutions.atlassian.net/wiki/spaces/CBDEV/pages/1101628584
- K8s Cheatsheet: https://eunasolutions.atlassian.net/wiki/spaces/INFRASRV/pages/1096089963
- Repos by Team: https://eunasolutions.atlassian.net/wiki/spaces/PROD/pages/1099825270
