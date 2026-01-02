# Full Conversion Playbook (Single-File Jsonnet)

Use this document for end-to-end conversion details, examples, and edge cases.

## Critical requirements

1. Convert all panels, variables, and configurations to Jsonnet using unified libraries.
2. Generate a single self-contained Jsonnet file (no dashboard-specific lib files).
3. Modernize legacy panel types and deprecated options.
4. Only modify `mixin/lib/*.libsonnet` for truly reusable components.

## Conversion philosophy

- Single self-contained file per dashboard.
- No raw JSON fallback files in final output.
- Prefer unified library constructors and helper functions.
- Layer Grafonnet `.with*()` methods for advanced options.

## Step 1: Review conventions

Read:
- `references/style-guide.md`
- `references/best-practices.md`
- `references/lib-api-reference.md`

## Step 2: Analyze the export JSON

Identify:
- Panel types (stat, timeseries, table, etc.)
- Variables and templating configuration
- Datasource types and UIDs
- Legacy configs that should be modernized
- Complex queries that can use `prom.*` helpers

## Step 3: Build a single self-contained Jsonnet file

### 3.1 File structure skeleton

```jsonnet
// 1) Grafonnet main library
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// 2) Unified libraries (alphabetical)
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// 3) Datasource configuration (dual-mode support)
local DATASOURCE_UID = 'prometheus-thanos';  // provisioning mode
// local DATASOURCE_UID = '${DS_PROMETHEUS}'; // manual import mode

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};

// 4) Common selectors (optional)
local baseSelector = '{job="api",env="prod"}';

// 5) Variables
local hostnameVariable = g.dashboard.variable.query.new(
  'hostname',
  'label_values(up, hostname)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.refresh.onLoad();

// 6) Panels (all panels defined here)
local qpsStat = panels.statPanel(
  title='QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
  datasource=config.datasource,
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width);

// 7) Annotations (optional)
local annotationsObj = {
  list: [
    {
      builtIn: 1,
      datasource: { type: 'grafana', uid: '-- Grafana --' },
      enable: true,
      hide: true,
      iconColor: 'rgba(0, 211, 255, 1)',
      name: 'Annotations & Alerts',
      type: 'dashboard',
    },
  ],
};

// 8) Dashboard assembly
local baseDashboard = g.dashboard.new('Dashboard Name')
+ g.dashboard.withUid('dashboard-uid')
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withVariables([hostnameVariable])
+ g.dashboard.withPanels([qpsStat]);

// 9) Final export with metadata (manual import supported)
baseDashboard {
  annotations: annotationsObj,
  schemaVersion: 42,
  version: 1,
  __inputs: [
    {
      name: 'DS_PROMETHEUS',
      label: 'Prometheus Datasource',
      description: 'Select Prometheus datasource',
      type: 'datasource',
      pluginId: 'prometheus',
      pluginName: 'Prometheus',
    },
  ],
  __requires: [
    { type: 'datasource', id: 'prometheus', name: 'Prometheus', version: '1.0.0' },
    { type: 'grafana', id: 'grafana', name: 'Grafana', version: config.pluginVersion },
    { type: 'panel', id: 'timeseries', name: 'Time series', version: '' },
    { type: 'panel', id: 'stat', name: 'Stat', version: '' },
    { type: 'panel', id: 'table', name: 'Table', version: '' },
  ],
}
```

### 3.2 Modernize legacy configurations

- `graph` -> `timeseries`
- `singlestat` -> `stat`
- Prefer `standards.legend.*` and `themes.timeseries.*`
- Use newer tooltip modes and legend options
- Prefer recent Grafonnet patterns and options

### 3.3 Standardize units, thresholds, themes

- Units: `standards.units.*`
- Thresholds: `standards.thresholds.*`
- Themes: `themes.timeseries.*`

### 3.4 Complex configurations

Layer Grafonnet options on top of unified constructors:

```jsonnet
local panel = panels.timeseriesPanel(
  title='Latency',
  targets=[...],
  unit=standards.units.seconds,
  theme=themes.timeseries.standard
)
+ g.panel.timeSeries.options.tooltip.withMode('multi')
+ g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30);
```

If a panel type is unsupported by unified libs, use Grafonnet directly and still apply `standards.units.*` and `standards.thresholds.*`.

### 3.5 Variable configurations

```jsonnet
local environmentVariable = g.dashboard.variable.query.new(
  'environment',
  'label_values(up{hostname=~"$hostname"}, environment)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.selectionOptions.withMulti(false)
+ g.dashboard.variable.query.refresh.onLoad();
```

## Step 4: Integrate and verify

- Place the single `<dashboard>.jsonnet` file under `mixin/<system>/`.
- Build with `mixin/build.sh` or `mixin/build.ps1`.
- Fix errors using `references/common-issues.md`.

Common errors:
- `Field does not exist: percent` -> use `percent01` or `percent100`
- `Field does not exist: rich` -> use `standard/compact/detailed/hidden`
- `max stack frames exceeded` -> use `+` and `super` instead of `self`

## Step 5: Test and optimize

- Import compiled JSON into Grafana and verify panels/variables.
- Use reasonable refresh intervals (30s default).
- Prefer recording rules for expensive queries.

## File organization (single file)

```
mixin/<system>/
- <dashboard>.jsonnet
```

## When to update general libs

Only update `mixin/lib/*.libsonnet` if the pattern is reusable across dashboards:
- New metric calculation used by multiple dashboards -> `prometheus.libsonnet`
- New standard threshold pattern -> `standards.libsonnet`
- New shared panel constructor -> `panels.libsonnet`

Do not add dashboard-specific helpers to global libs.

## Quality standards

- Every panel uses `panels.*Panel()` unless unsupported.
- All units and thresholds use `standards.*`.
- Queries use `prom.*` helpers where possible.
- Variables use `g.dashboard.variable.*` APIs.
- No dashboard-specific lib files or raw JSON panels remain.

## Optional scaffold script

You can run `scripts/convert_grafana_json.py` to generate a scaffold (entrypoint + lib + raw files).
Use it only as a scratchpad: inline all panels and variables into a single file and delete raw JSON files.

## Examples

- `examples/grafana-json-to-jsonnet/input-dashboard.json`
- `examples/grafana-json-to-jsonnet/output-dashboard.jsonnet`
- `examples/grafana-json-to-jsonnet/output-panels.libsonnet` (reference only)
