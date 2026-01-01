---
name: grafana-jsonnet-refactor
description: Refactor a single, monolithic Grafana Jsonnet dashboard into a split structure (entrypoint + lib) that matches the grafana-code mixin conventions. Use when a dashboard is hard to maintain or needs shared helpers extracted.
---

# Grafana Jsonnet Refactor (Split Entrypoint + Lib)

## Inputs
- Path to an existing Jsonnet dashboard
- Target system folder (for example `mixin/application`)

## Outputs
- `<dashboard>.jsonnet` (clean entrypoint)
- `lib/<dashboard>_panels.libsonnet` (panel builders, helpers)

## Steps
1. Read `references/refactor-checklist.md` to align with grafana-code conventions.
2. Identify reusable blocks:
   - datasource config, selectors, variables, and panel constructors
3. Create `lib/<dashboard>_panels.libsonnet` and move:
   - panel builders (use `panels.*`)
   - shared queries, selectors, and overrides
4. Keep the entrypoint file minimal:
   - imports, config, variables, and `g.dashboard.withPanels(...)`
5. Verify:
   - run `mixin/build.sh` or `mixin/build.ps1`
   - confirm no duplicated configuration remains

## Examples
- `references/example-before.jsonnet`
- `references/example-after-dashboard.jsonnet`
- `references/example-after-lib.libsonnet`