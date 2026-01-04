// Example after refactor (scaffold entrypoint; inline panels for final output)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panelsLib = import './lib/example_panels.libsonnet';

// Example datasource UID (replace in real usage).
local DATASOURCE_UID = 'prometheus-thanos';
// Manual import mode:
// local DATASOURCE_UID = '${DS_PROMETHEUS}';
// Example datasource type; replace as needed.
local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  pluginVersion: '12.3.0',
};

local baseDashboard = g.dashboard.new('Example')
+ g.dashboard.withUid('example')
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
