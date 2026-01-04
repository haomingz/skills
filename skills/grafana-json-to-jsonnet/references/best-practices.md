# Grafana Jsonnet Best Practices

> This document summarizes grafana-code code organization and best practices

## Contents
- 1. Import Order (Strictly Follow)
- 2. Naming Conventions
- 3. Panel Construction
- 4. Units and Thresholds
- 5. Legend Selection
- 6. Theme Selection
- 7. Query Construction
- 8. Comment Standards
- 9. Configuration Object
- 10. Selector Construction
- 11. Variable Definitions
- 12. Dashboard Definition
- 13. File Organization
- 14. Common Errors
- 15. Code Indentation
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

// 3. Config definition
local config = {
  datasource: { type: 'prometheus', uid: 'prometheus-thanos' },
  timezone: 'browser',
  timeFrom: 'now-6h',
  pluginVersion: '12.3.0',
};

// 4. Helper functions (if needed)
local buildSelector(labels) = { ... };

// 5. Variable definitions
local hostnameVariable = g.dashboard.variable.query.new(...);

// 6. Panel definitions
local qpsStat = panels.statPanel(...);

// 7. Dashboard construction
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

## 4. Units and Thresholds

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

## 5. Legend Selection

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

## 6. Theme Selection

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

## 7. Query Construction

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

## 8. Comment Standards

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

## 9. Configuration Object

### Use Unified config Object

```jsonnet
// ✅ Recommended: unified configuration
local config = {
  datasource: {
    type: 'prometheus',
    uid: 'prometheus-thanos',  // provisioning mode
    // uid: '${DS_PROMETHEUS}',  // manual import mode
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

## 10. Selector Construction

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

## 11. Variable Definitions

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

## 12. Dashboard Definition

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

## 13. File Organization

### Single-file Structure

```
mixin/application/
└── dashboard.jsonnet          # single self-contained file
```

**dashboard.jsonnet includes:**
- Imports
- Config
- Variables
- Panel definitions
- Dashboard definition

Do not create dashboard-specific lib files for this skill.

## 14. Common Errors

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

## 15. Code Indentation

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

## Complete Example

See `references/output-dashboard.jsonnet` for a scaffold-style example. Inline all panels and variables into a single file for final output.
