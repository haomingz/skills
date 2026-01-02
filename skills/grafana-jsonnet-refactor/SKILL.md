---
name: grafana-jsonnet-refactor
description: Refactor Grafana Jsonnet dashboards to reduce duplication and align with grafana-code unified libraries while preserving behavior. Trigger phrases include "refactor jsonnet dashboard", "cleanup grafonnet", "deduplicate panels", "standardize grafana jsonnet". CRITICAL: Generate a single self-contained jsonnet file - do NOT create dashboard-specific lib files.
---

# Grafana Jsonnet Refactor

## When to use

- A dashboard is hard to maintain, duplicated, or inconsistent with grafana-code conventions.
- You need to extract repeated patterns and standardize panels/queries.

## Trigger phrases (hints)

- "refactor jsonnet dashboard"
- "cleanup grafonnet"
- "deduplicate panels"
- "standardize grafana jsonnet"

## Inputs

- Path to an existing Jsonnet dashboard
- Target system folder (for example `mixin/application`)

## Outputs

- `<dashboard>.jsonnet` (single self-contained dashboard file, refactored and cleaned)
- Optional updates to `../lib/*.libsonnet` (only if adding truly reusable components)

## Critical requirements

- Preserve metric semantics and layout intent.
- Replace local helpers with unified libraries (`panels.*`, `prom.*`, `standards.*`, `themes.*`).
- Modernize legacy panels (`graph` -> `timeseries`, `singlestat` -> `stat`).
- Keep dashboard-specific code out of global libs.

## Refactor modes (choose one)

- Direct migration: remove helpers and use unified libs directly (small dashboards).
- Wrapper pattern: keep helper signatures, but call unified libs internally (large dashboards).
- Hybrid: mix direct + wrappers only where needed.

## Workflow

1. Read `references/refactor-checklist.md` to align with grafana-code conventions.
2. Audit the dashboard: list panels, variables, datasources, and repeated patterns.
3. Choose a refactor mode (direct / wrapper / hybrid).
4. Normalize `config` and shared selectors.
5. Replace panels with unified constructors and remove duplicated helpers.
6. Keep the file organized: imports -> config -> variables -> panels -> dashboard.
7. Compile and verify in Grafana.

## Guardrails

- Preserve metric semantics and layout intent.
- Avoid broad rewrites; focus on de-duplication and standards alignment.
- Only update `mixin/lib/*.libsonnet` for truly reusable components.

## Quality checks

- Build succeeds (`mixin/build.sh` or `mixin/build.ps1`).
- Panel count and layout match the original dashboard.
- Units and thresholds use `standards.*`.
- Queries use `prom.*` helpers where applicable.
- No dashboard-specific lib files exist in final output.

## Minimal single-file skeleton

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  pluginVersion: '12.3.0',
};

local qpsStat = panels.statPanel(
  title='QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
  datasource=config.datasource,
  unit=standards.units.qps,
  pluginVersion=config.pluginVersion
);

g.dashboard.new('Dashboard')
+ g.dashboard.withPanels([qpsStat])
```

## References (load as needed)

- `references/refactor-guide.md`
- `references/full-refactor-playbook.md`
- `references/refactor-checklist.md`
