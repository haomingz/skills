// Example report migration dashboard (entrypoint)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panelsLib = import './lib/report_panels.libsonnet';

// Example datasource UIDs (replace in real usage).
local ES_UID = 'es-logs';
local CH_UID = 'ch-logs';
// Manual import mode:
// local ES_UID = '${DS_ELASTICSEARCH}';
// local CH_UID = '${DS_CLICKHOUSE}';

// Example datasource types; replace as needed.
local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
};

local baseDashboard = g.dashboard.new('Nginx Report Migration')
+ g.dashboard.withUid('nginx-report-migration')
+ g.dashboard.withPanels(panelsLib.build(config));

baseDashboard {
  __inputs: [
    {
      name: 'DS_ELASTICSEARCH',
      label: 'Elasticsearch Datasource',
      type: 'datasource',
      pluginId: 'elasticsearch',
      pluginName: 'Elasticsearch',
    },
    {
      name: 'DS_CLICKHOUSE',
      label: 'ClickHouse Datasource',
      type: 'datasource',
      pluginId: 'grafana-clickhouse-datasource',
      pluginName: 'ClickHouse',
    },
  ],
  __requires: [
    { type: 'datasource', id: 'elasticsearch', name: 'Elasticsearch', version: '1.0.0' },
    { type: 'datasource', id: 'grafana-clickhouse-datasource', name: 'ClickHouse', version: '1.0.0' },
    { type: 'grafana', id: 'grafana', name: 'Grafana', version: config.pluginVersion },
  ],
}
