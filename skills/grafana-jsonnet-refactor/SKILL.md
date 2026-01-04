---
name: grafana-jsonnet-refactor
description: Refactors Grafana Jsonnet dashboards to eliminate duplication and align with grafana-code unified libraries while preserving behavior. Use when dashboards contain duplicated code, inconsistent patterns, legacy panel types, or need standardization with mixin conventions. Produces single self-contained files without dashboard-specific libraries.
---

# Grafana Jsonnet Refactor

## When to use this skill

This skill is most effective when:
- Dashboards contain duplicated panel definitions or query patterns
- Code uses local helpers instead of grafana-code unified libraries
- Legacy panel types (graph, singlestat) need modernization to timeseries/stat
- Dashboard maintenance is difficult due to inconsistent patterns
- Existing Jsonnet needs alignment with grafana-code conventions

Not suitable for:
- Initial JSON to Jsonnet conversion (use `grafana-json-to-jsonnet`)
- Content optimization or observability improvements (use `grafana-dashboard-optimize`)
- Python report migration (use `grafana-report-to-dashboard`)

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
- `references/example-before.jsonnet`
- `references/example-after-dashboard.jsonnet`
- `references/example-after-lib.libsonnet`
