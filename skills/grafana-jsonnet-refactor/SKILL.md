---
name: grafana-jsonnet-refactor
description: This skill should be used when refactoring monolithic Grafana Jsonnet dashboards into a clean split structure (entrypoint + lib). Trigger phrases include "refactor grafana jsonnet", "split dashboard", "extract lib helpers", "clean up jsonnet dashboard", "modularize dashboard". Use when a dashboard is hard to maintain, has duplicated code, or needs shared helpers extracted to match grafana-code mixin conventions.
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
- `examples/example-before.jsonnet`
- `examples/example-after-dashboard.jsonnet`
- `examples/example-after-lib.libsonnet`