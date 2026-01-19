# Refactor Examples (Before and After)

Use this file for copy-ready refactor examples. Load only when a user asks for examples.

## Example 1: Before refactor (monolithic Grafonnet)

```jsonnet
// Example before refactor (monolithic)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// Example datasource UID (replace in real usage).
local DATASOURCE_UID = 'prometheus-thanos';
// Manual import mode:
// local DATASOURCE_UID = '${DS_PROMETHEUS}';
// Example datasource type; replace as needed.
local datasource = { type: 'prometheus', uid: DATASOURCE_UID };

local qpsPanel = g.panel.timeSeries.new('QPS')
  + g.panel.timeSeries.queryOptions.withDatasource(
    type=datasource.type,
    uid=datasource.uid
  )
  + g.panel.timeSeries.queryOptions.withTargets([
    { expr: 'sum(rate(http_requests_total[1m]))', legendFormat: 'QPS', refId: 'A' },
  ])
  + g.panel.timeSeries.gridPos.withH(6)
  + g.panel.timeSeries.gridPos.withW(8)
  + g.panel.timeSeries.gridPos.withX(0)
  + g.panel.timeSeries.gridPos.withY(0);

g.dashboard.new('Example')
+ g.dashboard.withUid('example')
+ g.dashboard.withPanels([qpsPanel])
```

## Example 2: After refactor (single-file unified libs)

```jsonnet
// Example after refactor (single-file output)
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
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
};

local qpsStat = panels.withIdAndPatches(
  panels.statPanel(
    title='QPS',
    targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
    datasource=config.datasource,
    unit=standards.units.qps,
    thresholds=standards.thresholds.neutral,
    pluginVersion=config.pluginVersion
  ),
  id=1,
  gridPos={ h: layouts.stat.height, w: layouts.stat.width, x: 0, y: 0 }
);

local overviewRow = panels.rowPanel('Overview', collapsed=true)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([qpsStat]);

local serviceVariable = g.dashboard.variable.query.new(
  'service',
  'label_values(http_requests_total, service)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.refresh.onLoad();

local baseDashboard = g.dashboard.new('Example')
+ g.dashboard.withUid('example')
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withVariables([serviceVariable])
+ g.dashboard.withPanels([overviewRow]);

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
}
```

## Example 3: Optional reusable helper (shared lib)

Only create shared lib helpers when they are reused across dashboards. Otherwise keep helpers local.

```jsonnet
// Example reusable helper for a shared lib (only if shared across dashboards).
// Do not create dashboard-specific lib files.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local layouts = import './layouts.libsonnet';
local panels = import './panels.libsonnet';
local prom = import './prometheus.libsonnet';
local standards = import './standards.libsonnet';
local themes = import './themes.libsonnet';

{
  qpsPanel(config)::
    panels.timeseriesPanel(
      title='QPS',
      targets=[
        prom.target('sum(rate(http_requests_total[1m]))', 'QPS'),
      ],
      datasource=config.datasource,
      unit=standards.units.qps,
      legendConfig=standards.legend.standard,
      theme=themes.timeseries.standard,
      pluginVersion=config.pluginVersion
    )
    + g.panel.timeSeries.gridPos.withH(layouts.timeseries.small.height)
    + g.panel.timeSeries.gridPos.withW(layouts.timeseries.small.width)
    + g.panel.timeSeries.gridPos.withX(0)
    + g.panel.timeSeries.gridPos.withY(0),

  build(config):: [
    self.qpsPanel(config),
  ],
}
```
