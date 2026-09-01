# overlays/prod (stub — Phase 2)

Mirrors `overlays/dev` once that exists, with prod differences only:

- `images:` pinned to the digests promoted by the **promotion PR** — merging
  that PR *is* the prod deploy; nothing else in this overlay changes with it
- its own `Gateway` (same name `lab`, `app` namespace — HTTPRoutes in base
  attach unchanged) backed by GKE's Gateway controller or Envoy Gateway
- `ExternalSecret`s pointing at the prod project's Secret Manager
- replicas ≥ 2 for api/mcp-server, plus PodDisruptionBudgets and topology
  spread (they only earn their keep above 1 replica)
- the OTel collector exporting to the prod project

Environment parity rule: same architecture and backing services everywhere;
only sizing and endpoints differ (12-factor — sizing is config).
