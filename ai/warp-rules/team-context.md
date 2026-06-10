# Euna Payments Development Context

The default/main branch for all repositories is `master`, not `main`.

Euna Payments (formerly CityBase) uses:
- **Backend**: Elixir/Phoenix with PostgreSQL and Redis
- **Frontend**: React with Redux
- **Package registry**: GemFury (private Elixir/npm packages via `@thecb` scope)
- **Infrastructure**: Kubernetes on AWS EKS, deployed via ArgoCD
- **Monitoring**: Coralogix (logs), Airbrake (errors), Grafana (metrics)

Environment URL pattern: `https://[app]-[namespace].[env].cityba.se`
- Dev: `.dev.cityba.se`
- UAT: `.uat.cityba.se`
- Internal (VPN required): `.internal.[env].cityba.se`
