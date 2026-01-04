---
name: grafana-jsonnet-refactor
description: Refactors Grafana Jsonnet dashboards to eliminate duplication and align with grafana-code unified libraries while preserving behavior. Use when dashboards contain duplicated code, inconsistent patterns, legacy panel types, or need standardization with mixin conventions. Produces single self-contained files without dashboard-specific libraries.
---

# Grafana Jsonnet Refactor

Eliminate duplication and align existing Jsonnet dashboards with grafana-code unified libraries. Preserve behavior while modernizing legacy panels and standardizing patterns.

**Not suitable for**: Initial JSON to Jsonnet conversion (use `grafana-json-to-jsonnet`), content optimization (use `grafana-dashboard-optimize`), or Python report migration (use `grafana-report-to-dashboard`).

## Workflow with progress tracking

Copy this checklist and track your progress:

```
Refactor Progress:
- [ ] Step 1: Read refactor-checklist.md and align with conventions
- [ ] Step 2: Audit dashboard (panels, variables, datasources, patterns)
- [ ] Step 3: Choose refactor mode (direct/wrapper/hybrid)
- [ ] Step 4: Normalize config and shared selectors
- [ ] Step 5: Replace panels with unified constructors
- [ ] Step 6: Organize file structure (imports → config → variables → panels → dashboard)
- [ ] Step 7: Compile and verify in Grafana
```

**Step 1: Read refactor-checklist.md**

Load `references/refactor-checklist.md` to understand grafana-code conventions and standards.

**Step 2: Audit the dashboard**

List all panels, variables, datasources, and identify repeated patterns. Note which panels use local helpers vs unified libraries.

**Step 3: Choose refactor mode**

Select approach based on dashboard size:
- **Direct migration**: Remove helpers, use unified libs directly (recommended for small dashboards)
- **Wrapper pattern**: Keep helper signatures, call unified libs internally (for large dashboards with many callsites)
- **Hybrid**: Mix approaches where needed

**Step 4: Normalize config and shared selectors**

Extract common configuration (datasource, pluginVersion, timezone) into a `config` object.

**Step 5: Replace panels with unified constructors**

Replace local helpers with `panels.*Panel()` constructors. Apply `standards.*` for units/thresholds and `themes.*` for timeseries styling. Add `id` and `gridPos` via `panels.withIdAndPatches(...)` or `+ { id, gridPos }`. Remove duplicated helper functions.

**Step 6: Organize file structure**

Structure the file: imports → config → constants → helpers → panels → rows → variables → dashboard. Keep all panel definitions as `local` variables in the single file.

**Step 7: Compile and verify**

Run `mixin/build.sh` or `mixin/build.ps1`. Fix any errors. Verify panel count and layout match the original dashboard in Grafana.

## Refactor modes (quick reference)

- **Direct migration**: Remove helpers and use unified libs directly (small dashboards)
- **Wrapper pattern**: Keep helper signatures, but call unified libs internally (large dashboards)
- **Hybrid**: Mix direct + wrappers only where needed

## Guardrails

- Preserve metric semantics and layout intent.
- Avoid broad rewrites; focus on de-duplication and standards alignment.
- Keep a single file; do not create dashboard-specific lib files.
- Only update `mixin/lib/*.libsonnet` for truly reusable components.
- Do not run `jsonnetfmt` / `jsonnet fmt` on generated Jsonnet files.

## Quality checks

- Build succeeds (`mixin/build.sh` or `mixin/build.ps1`).
- Panel count and layout match the original dashboard.
- Units and thresholds use `standards.*`.
- Queries use `prom.*` helpers where applicable.
- No dashboard-specific lib files exist in final output.
- Preserve `__inputs` / `__requires` and manual import lines when present.

## Minimal single-file skeleton

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// Provisioning mode (real UID). For manual import, switch to ${DS_*}.
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

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
