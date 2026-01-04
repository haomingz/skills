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
