// Example report migration dashboard (entrypoint)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panelsLib = import './lib/report_panels.libsonnet';

local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: 'es-logs' },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: 'ch-logs' },
  },
  pluginVersion: '12.3.0',
};

g.dashboard.new('Nginx Report Migration')
+ g.dashboard.withUid('nginx-report-migration')
+ g.dashboard.withPanels(panelsLib.build(config))