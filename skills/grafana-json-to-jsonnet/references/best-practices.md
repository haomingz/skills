# Grafana Jsonnet Best Practices

> This document summarizes grafana-code code organization and best practices

## Contents
- 1. Import Order (Strictly Follow)
- 2. Naming Conventions
- 3. Panel Construction
- 4. Row Construction
- 5. Units and Thresholds
- 6. Legend Selection
- 7. Theme Selection
- 8. Query Construction
- 9. Comment Standards
- 10. Configuration Object
- 11. Selector Construction
- 12. Variable Definitions
- 13. Dashboard Definition
- 14. Dashboard Metadata
- 15. File Organization
- 16. Common Errors
- 17. Code Indentation
- 18. Formatting Guardrail
- Complete Example

## 1. Import Order (Strictly Follow)

```jsonnet
// ✅ Recommended import order
// 1. Grafonnet main library
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// 2. Unified libraries (alphabetically)
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// 3. Config constants
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

// 4. Config definition
local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  timezone: 'browser',
  timeFrom: 'now-6h',
  pluginVersion: '12.3.0',
};

// 5. Constants (if needed)
local thresholds = { errorRate: { warn: 0.02, crit: 0.05 } };

// 6. Helper functions (if needed)
local buildSelector(labels) = { ... };

// 7. Panel definitions
local qpsStat = panels.statPanel(...);

// 8. Row definitions
local overviewRow = panels.rowPanel('Overview', collapsed=true)
+ g.panel.row.withPanels([qpsStat]);

// 9. Variable definitions
local hostnameVariable = g.dashboard.variable.query.new(...);

// 10. Dashboard construction
g.dashboard.new('Dashboard Name')
+ g.dashboard.withPanels([...])
```

## 2. Naming Conventions

### Use camelCase

```jsonnet
// ✅ Recommended
local qpsStat = panels.statPanel(...);
local errorRatePanel = panels.timeseriesPanel(...);
local serviceVariable = g.dashboard.variable.query.new(...);

// ❌ Avoid underscores
local qps_stat = ...;
local error_rate_panel = ...;

// ❌ Avoid dashes (syntax error)
local error-rate-panel = ...;
```

### Use Meaningful Variable Names

```jsonnet
// ✅ Recommended
local qpsStat = ...;
local errorRatePanel = ...;
local hostnameVariable = ...;

// ❌ Avoid vague names
local panel1 = ...;
local var1 = ...;
local temp = ...;
```

### Panel Variable Naming Standards

```jsonnet
// Stat Panel: ends with Stat
local qpsStat = panels.statPanel(...);
local errorRateStat = panels.statPanel(...);

// Timeseries Panel: ends with Panel
local qpsPanel = panels.timeseriesPanel(...);
local latencyPanel = panels.timeseriesPanel(...);

// Table Panel: ends with Table
local topEndpointsTable = panels.tablePanel(...);

// Row: ends with Row
local overviewRow = panels.rowPanel(...);

// Variable: ends with Variable
local hostnameVariable = g.dashboard.variable.query.new(...);
```

## 3. Panel Construction

### Use Unified Library Constructors

```jsonnet
// ✅ Recommended: use unified library
local qpsStat = panels.statPanel(
  title='QPS',
  targets=[prom.instantTarget('sum(rate(...))', '')],
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral
);

// ❌ Avoid: manual construction
local qpsStat = {
  type: 'stat',
  title: 'QPS',
  targets: [...],
  fieldConfig: { ... },  // Lots of duplicate config
};
```

### GridPos Settings

```jsonnet
// ✅ Recommended: use layouts standard sizes
local qpsStat = panels.statPanel(...)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

// ✅ Or use shortcuts (small panel)
+ g.panel.stat.gridPos.withH(layouts.timeseries.small.height)
+ g.panel.stat.gridPos.withW(layouts.timeseries.small.width)

// ❌ Avoid: hardcoded sizes
+ g.panel.stat.gridPos.withH(3)
+ g.panel.stat.gridPos.withW(4)
```

### Prefer panels.withIdAndPatches for id/gridPos

```jsonnet
local basePanel = panels.statPanel(...);
local statPanel = panels.withIdAndPatches(basePanel, id=1, gridPos={ h: 3, w: 4, x: 0, y: 0 });
```

## 4. Row Construction

### Use panels.rowPanel or g.panel.row.new

```jsonnet
// ✅ Recommended: row panel with attached panels
local overviewRow = panels.rowPanel('Overview', collapsed=true)
+ g.panel.row.gridPos.withH(layouts.row.height)
+ g.panel.row.gridPos.withW(layouts.row.width)
+ g.panel.row.gridPos.withX(0)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([panel1, panel2]);
```

## 5. Units and Thresholds

### Use Standard Units

```jsonnet
// ✅ Recommended: use standards
unit=standards.units.qps
unit=standards.units.errorRate
unit=standards.units.seconds
unit=standards.units.bytes

// ❌ Avoid: hardcoding
unit='reqps'
unit='percentunit'
unit='s'
```

### Use Standard Thresholds

```jsonnet
// ✅ Recommended: use standard thresholds
thresholds=standards.thresholds.errorRate     // Error rate
thresholds=standards.thresholds.successRate   // Success rate
thresholds=standards.thresholds.latencySeconds
thresholds=standards.thresholds.neutral       // No alert meaning

// ❌ Avoid: hardcoded thresholds
thresholds={
  mode: 'absolute',
  steps: [
    { color: 'green', value: null },
    { color: 'yellow', value: 0.02 },
    { color: 'red', value: 0.05 },
  ],
}
```

## 6. Legend Selection

### Choose Based on Series Count

```jsonnet
// 1-3 series → use detailed
local panel1 = panels.timeseriesPanel(
  ...,
  legendConfig=standards.legend.detailed  // shows lastNotNull, max, mean, sum
);

// 4-8 series → use standard (default)
local panel2 = panels.timeseriesPanel(
  ...,
  legendConfig=standards.legend.standard  // shows lastNotNull, max, mean
);

// 9+ series → use compact
local panel3 = panels.timeseriesPanel(
  ...,
  legendConfig=standards.legend.compact   // shows lastNotNull only
);

// Single series or reference line → hide legend
local panel4 = panels.timeseriesPanel(
  ...,
  legendConfig=standards.legend.hidden
);
```

## 7. Theme Selection

### Choose Appropriate Timeseries Theme

```jsonnet
// Regular timeseries data → standard (default)
theme=themes.timeseries.standard
// fillOpacity: 18, lineWidth: 2

// Important metrics need emphasis → emphasized
theme=themes.timeseries.emphasized
// fillOpacity: 25, lineWidth: 3

// Reference lines or secondary data → light
theme=themes.timeseries.light
// fillOpacity: 10, lineWidth: 1

// Discrete data or comparison → bars
theme=themes.timeseries.bars
// drawStyle: 'bars', fillOpacity: 70

// Stacked area chart
theme=themes.timeseries.areaStacked
```

## 8. Query Construction

### Use prom.libsonnet Helper Functions

```jsonnet
// ✅ Recommended: use helper functions
local errorRateTarget = prom.errorRate(
  metric='http_requests_total',
  selector='{job="api"}',
  statusLabel='status',
  legendFormat='Error Rate'
);

// ❌ Avoid: manually writing complex queries
local errorRateTarget = prom.target(
  'sum(rate(http_requests_total{job="api",status=~"[45].."}[1m])) / sum(rate(http_requests_total{job="api"}[1m]))',
  'Error Rate'
);
```

### Use Percentiles Rather Than Averages

```jsonnet
// ✅ Recommended: show P50/P90/P99
targets=[
  prom.p50('http_request_duration', '{job="api"}', 'P50'),
  prom.p90('http_request_duration', '{job="api"}', 'P90'),
  prom.p99('http_request_duration', '{job="api"}', 'P99'),
]

// ❌ Not recommended: show only average
targets=[
  prom.target('avg(http_request_duration{job="api"})', 'avg')
]
```

## 9. Comment Standards

### Add Comments Before Complex Logic

```jsonnet
// ✅ Recommended: explain complex logic
// Calculate Apdex Score: (satisfied + tolerable/2) / total
local apdexScore = prom.apdex(
  metric='http_request_duration',
  selector=baseSelector,
  satisfiedThreshold=0.5,
  tolerableThreshold=1.0,
  legendFormat='Apdex'
);

// ✅ Recommended: explain non-obvious configuration choices
// Use emphasized theme to highlight critical error metrics
theme=themes.timeseries.emphasized
```

### Avoid Redundant Comments

```jsonnet
// ❌ Avoid: obvious comments
// Create a Stat Panel
local qpsStat = panels.statPanel(...);  // Function name already says this
```

## 10. Configuration Object

### Use Unified config Object

```jsonnet
// ✅ Recommended: unified configuration
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: {
    type: 'prometheus',
    uid: DATASOURCE_UID,
  },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};

// Reference in panels
local panel = panels.statPanel(
  title='...',
  targets=[...],
  unit=...
);  // panels.libsonnet internally uses datasource
```

## 11. Selector Construction

### Extract Common Selectors

```jsonnet
// ✅ Recommended: extract common selector
local baseSelector = '{job="api",env="prod"}';

local qpsTarget = prom.target(
  'sum(rate(http_requests_total' + baseSelector + '[1m]))',
  'QPS'
);

local errorRateTarget = prom.errorRate(
  'http_requests_total',
  baseSelector,
  'status',
  'Error Rate'
);

// ❌ Avoid: repeating in every query
local qpsTarget = prom.target(
  'sum(rate(http_requests_total{job="api",env="prod"}[1m]))',
  'QPS'
);
local errorRateTarget = prom.errorRate(
  'http_requests_total',
  '{job="api",env="prod"}',
  'status',
  'Error Rate'
);
```

### Use helpers.buildSelector for Complex Selectors

```jsonnet
// ✅ Recommended: use helper function
local baseSelector = helpers.buildSelector(
  { hostname: '$hostname', idc: '$idc' },
  ',status=~"2.."'  // extra filter
);
// Result: {hostname=~"$hostname",idc=~"$idc",status=~"2.."}
```

## 12. Variable Definitions

### Variable Configuration Standards

```jsonnet
local hostnameVariable = g.dashboard.variable.query.new(
  'hostname',  // Variable name
  'label_values(metric_name, label_name)'  // Query
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.generalOptions.withLabel('Hostname')  // Display label
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.selectionOptions.withMulti(true)  // Optional
+ g.dashboard.variable.query.refresh.onLoad()
+ {
  allValue: '.*',  // All option value
  current: { selected: true, text: 'All', value: '$__all' },  // Default value
  sort: 1,  // Sort
};
```

## 13. Dashboard Definition

### Dashboard Basic Configuration

```jsonnet
g.dashboard.new('Dashboard Name')
+ g.dashboard.withUid('dashboard-uid')  // Fixed UID
+ g.dashboard.withTags(['tag1', 'tag2'])  // Tags
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.withRefresh('30s')  // Refresh interval
+ g.dashboard.withVariables([var1, var2, ...])
+ g.dashboard.withPanels([panel1, panel2, ...])
```

## 14. Dashboard Metadata

### Add __inputs / __requires for manual import

```jsonnet
baseDashboard {
  __inputs: [
    {
      name: 'DS_PROMETHEUS',
      label: 'Prometheus Datasource',
      type: 'datasource',
      pluginId: 'prometheus',
      pluginName: 'Prometheus',
    },
  ],
  __requires: [
    { type: 'datasource', id: 'prometheus', name: 'Prometheus', version: '1.0.0' },
    { type: 'grafana', id: 'grafana', name: 'Grafana', version: config.pluginVersion },
  ],
  annotations: {
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
  },
}
```

## 15. File Organization

### Single-file Structure

```
mixin/application/
└── dashboard.jsonnet          # single self-contained file
```

**dashboard.jsonnet includes:**
- Imports
- Config constants and config
- Constants and local helpers (if needed)
- Panel definitions
- Row definitions
- Variables
- Dashboard definition + metadata

Do not create dashboard-specific lib files for this skill. Use local helpers or update `mixin/lib/*.libsonnet` only when a pattern is truly reusable.

## 16. Common Errors

### Error 1: Using Wrong Unit Names

```jsonnet
// ❌ Wrong
unit=standards.units.percent      // doesn't exist
unit=standards.units.bytesPerSecond  // doesn't exist

// ✅ Correct
unit=standards.units.percent01    // 0-1 range
unit=standards.units.percent100   // 0-100 range
unit=standards.units.Bps          // Bytes per second
```

### Error 2: Wrong Legend Configuration

```jsonnet
// ❌ Wrong
legendConfig=standards.legend.rich  // doesn't exist

// ✅ Correct
legendConfig=standards.legend.standard
legendConfig=standards.legend.compact
legendConfig=standards.legend.detailed
```

### Error 3: Object Extension Syntax Error

```jsonnet
// ❌ Wrong: using self causes infinite recursion
prom.p50(...) { expr: self.expr + ' * 1000' }

// ✅ Correct: use + operator and super
prom.p50(...) + { expr: super.expr + ' * 1000' }
```

## 17. Code Indentation

### Use 2-Space Indentation

```jsonnet
// ✅ Recommended: 2 spaces
local config = {
  datasource: {
    type: 'prometheus',
    uid: 'prometheus-thanos',
  },
};

// ❌ Avoid: 4 spaces or tabs
local config = {
    datasource: {
        type: 'prometheus',
        uid: 'prometheus-thanos',
    },
};
```

## 18. Formatting Guardrail

- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.

## Complete Example

See `references/output-dashboard.jsonnet` for a scaffold-style example. Inline all panels and variables into a single file for final output.
