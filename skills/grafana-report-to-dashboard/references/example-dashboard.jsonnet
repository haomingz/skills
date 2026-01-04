// Example report migration dashboard (single-file output)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';
local clickhouse = import '../lib/clickhouse.libsonnet';

// Provisioning mode (real UID). For manual import, switch to ${DS_*}.
local ES_UID = 'es-logs';
local CH_UID = 'ch-logs';
// local ES_UID = '${DS_ELASTICSEARCH}';
// local CH_UID = '${DS_CLICKHOUSE}';

local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
  timezone: 'browser',
  timeFrom: 'now-24h',
  timeTo: 'now',
};

local esCountTarget(query, refId) = {
  refId: refId,
  datasource: config.datasources.elasticsearch,
  queryType: 'lucene',
  query: query,
  timeField: '@timestamp',
  metrics: [
    { id: '1', type: 'count' },
  ],
  bucketAggs: [
    {
      id: '2',
      type: 'date_histogram',
      field: '@timestamp',
      settings: { interval: '1m' },
    },
  ],
};

local qpsTrend = panels.timeseriesPanel(
  title='QPS (ES)',
  targets=[esCountTarget('environment:prod', 'A')],
  datasource=config.datasources.elasticsearch,
  unit=standards.units.qps,
  legendConfig=standards.legend.standard,
  theme=themes.timeseries.standard,
  pluginVersion=config.pluginVersion
)
+ g.panel.timeSeries.gridPos.withH(layouts.timeseries.small.height)
+ g.panel.timeSeries.gridPos.withW(layouts.timeseries.small.width)
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withY(0);

local errorCount = panels.statPanel(
  title='5xx Count (ES)',
  targets=[esCountTarget('status:[500 TO 599] AND environment:prod', 'A')],
  datasource=config.datasources.elasticsearch,
  unit=standards.units.count,
  thresholds=standards.thresholds.neutral,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(8)
+ g.panel.stat.gridPos.withY(0);

local topHosts = panels.tablePanel(
  title='Top Hosts (ClickHouse)',
  targets=[
    clickhouse.sqlTarget(
      config.datasources.clickhouse,
      |||
      SELECT host, count() AS requests
      FROM nginx_logs
      WHERE $__timeFilter(timestamp)
      GROUP BY host
      ORDER BY requests DESC
      LIMIT 10
      |||,
      refId='A'
    )
  ],
  datasource=config.datasources.clickhouse,
  pluginVersion=config.pluginVersion
)
+ g.panel.table.gridPos.withH(layouts.table.small.height)
+ g.panel.table.gridPos.withW(layouts.table.small.width)
+ g.panel.table.gridPos.withX(0)
+ g.panel.table.gridPos.withY(6);

local overviewRow = panels.rowPanel('Overview', collapsed=true)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([qpsTrend, errorCount, topHosts]);

local baseDashboard = g.dashboard.new('Nginx Report Migration')
+ g.dashboard.withUid('nginx-report-migration')
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withPanels([overviewRow]);

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
