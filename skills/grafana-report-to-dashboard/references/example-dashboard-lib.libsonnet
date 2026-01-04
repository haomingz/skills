// Example reusable helper for mixin/lib (only if shared across dashboards).
// Do not create dashboard-specific lib files.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local layouts = import './layouts.libsonnet';
local panels = import './panels.libsonnet';
local standards = import './standards.libsonnet';
local themes = import './themes.libsonnet';
local clickhouse = import './clickhouse.libsonnet';

// Example queries only. Replace filters (like environment:prod) or parameterize with variables.

local qpsTarget(config) = {
  refId: 'A',
  datasource: config.datasources.elasticsearch,
  queryType: 'lucene',
  query: 'environment:prod',
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

local errorTarget(config) = {
  refId: 'A',
  datasource: config.datasources.elasticsearch,
  queryType: 'lucene',
  query: 'status:[500 TO 599] AND environment:prod',
  timeField: '@timestamp',
  metrics: [
    { id: '1', type: 'count' },
  ],
  bucketAggs: [],
};

{
  qpsTrend(config)::
    panels.timeseriesPanel(
      title='QPS (ES)',
      targets=[qpsTarget(config)],
      datasource=config.datasources.elasticsearch,
      unit=standards.units.qps,
      legendConfig=standards.legend.standard,
      theme=themes.timeseries.standard,
      pluginVersion=config.pluginVersion
    )
    + g.panel.timeSeries.gridPos.withH(layouts.timeseries.small.height)
    + g.panel.timeSeries.gridPos.withW(layouts.timeseries.small.width)
    + g.panel.timeSeries.gridPos.withX(0)
    + g.panel.timeSeries.gridPos.withY(0),

  errorCount(config)::
    panels.statPanel(
      title='5xx Count (ES)',
      targets=[errorTarget(config)],
      datasource=config.datasources.elasticsearch,
      unit=standards.units.count,
      thresholds=standards.thresholds.neutral,
      pluginVersion=config.pluginVersion
    )
    + g.panel.stat.gridPos.withH(layouts.stat.height)
    + g.panel.stat.gridPos.withW(layouts.stat.width)
    + g.panel.stat.gridPos.withX(8)
    + g.panel.stat.gridPos.withY(0),

  topHosts(config)::
    panels.tablePanel(
      title='Top Hosts (ClickHouse)',
      targets=[
        clickhouse.sqlTarget(
          config.datasources.clickhouse,
          |||
          SELECT host, count() AS requests
          FROM nginx_logs
          WHERE timestamp >= now() - INTERVAL 1 HOUR
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
    + g.panel.table.gridPos.withY(6),

  build(config):: [
    self.qpsTrend(config),
    self.errorCount(config),
    self.topHosts(config),
  ],
}
