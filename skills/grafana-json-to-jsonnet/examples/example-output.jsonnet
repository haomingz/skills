// Example API Dashboard (generated scaffold)

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panelsLib = import './lib/example-api_panels.libsonnet';
local rawVariables = import './lib/example-api_raw_variables.json';

local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: {
    // Example datasource type; replace as needed.
    type: 'prometheus',
    uid: DATASOURCE_UID,
  },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};

// -------------------- Variables --------------------

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
+ g.dashboard.variable.query.withSort(1);

local variables = [
  serviceVariable,
] + rawVariables;

// -------------------- Dashboard --------------------

local baseDashboard = g.dashboard.new('Example API Dashboard')
+ g.dashboard.withUid('example-api')
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withVariables(variables)
+ g.dashboard.withPanels(panelsLib.build(config));

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
