// Example after refactor (entrypoint)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panelsLib = import './lib/example_panels.libsonnet';

local DATASOURCE_UID = 'prometheus-thanos';
local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  pluginVersion: '12.3.0',
};

g.dashboard.new('Example')
+ g.dashboard.withUid('example')
+ g.dashboard.withPanels(panelsLib.build(config))