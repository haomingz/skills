# Json Export Conversion Examples (Assets)

Use this file for copy-ready examples when asked. Keep it out of the default context unless a user requests examples.

## Contents

- Example 1: Minimal dashboard conversion (stat + timeseries)
- Example 2: Row structure and panel placement
- Example 3: Table panel overrides (structure only)
- Example 4: Variable conversion with regex and defaults

## Example 1: Minimal dashboard conversion (stat + timeseries)

Input JSON (excerpt):

```json
{
  "title": "Service Overview",
  "uid": "old-uid",
  "panels": [
    { "type": "stat", "title": "QPS", "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 } },
    { "type": "timeseries", "title": "QPS Trend", "gridPos": { "x": 6, "y": 0, "w": 18, "h": 4 } }
  ]
}
```

Output Jsonnet (excerpt):

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  timezone: 'browser',
  timeFrom: 'now-24h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};

// For log-heavy dashboards (nginx log / nginx vts), prefer now-6h ~ now.

local qpsStat = panels.statPanel(
  title='QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
  datasource=config.datasource,
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(4)
+ g.panel.stat.gridPos.withW(6)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

local qpsTrend = panels.timeseriesPanel(
  title='QPS Trend',
  targets=[prom.target('sum(rate(http_requests_total[1m]))', 'QPS')],
  datasource=config.datasource,
  unit=standards.units.qps,
  legendConfig=standards.legend.standard,
  theme=themes.timeseries.standard,
  pluginVersion=config.pluginVersion
)
+ g.panel.timeSeries.gridPos.withH(4)
+ g.panel.timeSeries.gridPos.withW(18)
+ g.panel.timeSeries.gridPos.withX(6)
+ g.panel.timeSeries.gridPos.withY(0);

local baseDashboard = g.dashboard.new('Service Overview')
+ g.dashboard.withUid('service-overview')  // derived from name, not reused
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withPanels([qpsStat, qpsTrend]);

baseDashboard
```

## Example 2: Row structure and panel placement

Goal: Keep row structure and align panel `gridPos.y` with row `gridPos.y`.

```jsonnet
local overviewRow = panels.rowPanel('Overview', collapsed=false)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([
  qpsStat + g.panel.stat.gridPos.withY(0),
  qpsTrend + g.panel.timeSeries.gridPos.withY(0),
]);
```

## Example 3: Table panel overrides (structure only)

Use table panels with `panels.tablePanel(...)` and add overrides through the panels lib.

```jsonnet
local tableOverrides = [
  // Use panels lib override helpers here; see mixin/lib/panels.libsonnet.
  // Example intent: status -> pill cell type + thresholds + colors
  // Example intent: latency_ms -> unit + thresholds
  // Example intent: endpoint -> fixed width
];

local topErrorsTable = panels.tablePanel(
  title='Top Errors',
  targets=[prom.tableTarget('topk(10, sum(rate(http_requests_total{status=~"5.."}[5m])) by (endpoint))', '')],
  overrides=tableOverrides
)
+ g.panel.table.gridPos.withH(8)
+ g.panel.table.gridPos.withW(24)
+ g.panel.table.gridPos.withX(0)
+ g.panel.table.gridPos.withY(4);
```

Override checklist for tables:
- Apply thresholds + colors to status/health columns.
- Set units for numeric fields (ms, percent, bytes).
- Set column widths for high-signal fields.
- Hide low-signal or noisy columns via overrides or lib defaults.

## Example 4: Variable conversion with regex and defaults

```jsonnet
local serviceVariable = g.dashboard.variable.query.new(
  'service',
  'label_values(http_requests_total, service)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.selectionOptions.withMulti(true)
+ g.dashboard.variable.query.refresh.onLoad()
+ g.dashboard.variable.query.withRegex('/^(api|web|worker)$/')
+ { current: { text: 'api', value: 'api' } };
```
