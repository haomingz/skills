# Full Refactor Playbook

This playbook provides detailed steps and patterns for refactoring Grafana Jsonnet dashboards.

## Contents

- [Goals and constraints](#goals-and-constraints)
- [Step 1: Audit the current dashboard](#step-1-audit-the-current-dashboard)
- [Step 2: Decide the structure](#step-2-decide-the-structure)
- [Step 3: Normalize config and selectors](#step-3-normalize-config-and-selectors)
- [Step 4: Extract panel builders](#step-4-extract-panel-builders-if-splitting)
- [Step 5: Refactor panels](#step-5-refactor-panels)
- [Step 6: Modernize legacy types](#step-6-modernize-legacy-types)
- [Step 7: Compile and verify](#step-7-compile-and-verify)
- [Quality checks](#quality-checks)

---

## Goals and constraints

- Preserve metrics and layout behavior.
- Reduce duplication and align with unified libraries.
- Keep changes focused; avoid wide rewrites.
- Only update `mixin/lib/*.libsonnet` if a pattern is reusable across dashboards.

## Step 1: Audit the current dashboard

Capture:
- Panel list and types
- Variables and their queries
- Datasource usage (single or multiple)
- Repeated query patterns or panel options
- Layout intent and row structure

## Step 2: Decide the structure

- Single file is acceptable for small dashboards with minimal repetition.
- Split to entrypoint + lib when there are repeated panel patterns, shared selectors, or many panels.

## Step 3: Normalize config and selectors

Create a `config` object for:
- `datasource` or `datasources` (multi-backend)
- `timezone`, `timeFrom`, `timeTo`, `pluginVersion`
- Shared selectors (label filters, time ranges)

Example:

```jsonnet
local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  pluginVersion: '12.3.0',
};

local baseSelector = '{job="api",env="prod"}';
```

## Step 4: Extract panel builders (if splitting)

- Create `lib/<dashboard>_panels.libsonnet`.
- Define `panel_*` builders and a `build(config)` method.
- Replace raw Grafonnet blocks with `panels.*Panel()` constructors.

Example lib structure:

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panels = import '../../lib/panels.libsonnet';
local prom = import '../../lib/prometheus.libsonnet';
local standards = import '../../lib/standards.libsonnet';
local themes = import '../../lib/themes.libsonnet';
local layouts = import '../../lib/layouts.libsonnet';

{
  errorRatePanel(config)::
    panels.timeseriesPanel(
      title='Error Rate',
      targets=[prom.errorRate('http_requests_total', baseSelector, 'status', 'Error Rate')],
      datasource=config.datasource,
      unit=standards.units.errorRate,
      theme=themes.timeseries.standard,
      pluginVersion=config.pluginVersion
    )
    + g.panel.timeSeries.gridPos.withH(6)
    + g.panel.timeSeries.gridPos.withW(12),

  build(config):: [
    self.errorRatePanel(config),
  ],
}
```

## Step 5: Keep the entrypoint minimal

Entrypoint responsibilities:
- Imports and config
- Variables
- Dashboard assembly (`g.dashboard.withPanels(...)`)

Example:

```jsonnet
local panelsLib = import './lib/<dashboard>_panels.libsonnet';

local variables = [hostnameVariable, environmentVariable];

g.dashboard.new('Dashboard')
+ g.dashboard.withVariables(variables)
+ g.dashboard.withPanels(panelsLib.build(config))
```

## Step 6: Replace raw Grafonnet blocks

- For each panel, prefer unified constructors.
- Layer Grafonnet `.with*()` methods for advanced options.
- Normalize units and thresholds with `standards.*`.

## Step 7: Multi-datasource refactor (when needed)

If a dashboard uses multiple backends:

```jsonnet
local config = {
  datasources: {
    prometheus: { type: 'prometheus', uid: PROM_UID },
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
  },
  pluginVersion: '12.3.0',
};
```

Pass the correct datasource into each panel constructor and keep targets consistent.

## Step 8: Verify behavior

- Compile with `mixin/build.sh` or `mixin/build.ps1`.
- Check variable interaction, panel rendering, and layout.
- Compare metrics and calculations with the original dashboard.

## Common pitfalls

- Moving dashboard-specific panels into `mixin/lib/`.
- Changing query semantics while refactoring.
- Leaving duplicated selectors across panels.
- Losing row collapse/expand behavior.
- Changing default time range or refresh unintentionally.
