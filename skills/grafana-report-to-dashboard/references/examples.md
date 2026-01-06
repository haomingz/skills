# Report-to-Dashboard Examples

Use this file for copy-ready examples. Load only when a user asks for examples.

## Example 1: Source report script (Elasticsearch)

```python
# Example report script (Elasticsearch -> email)
from elasticsearch import Elasticsearch

es = Elasticsearch('https://es.example.local:9200')

index = 'nginx-logs-*'

qps_query = {
    "size": 0,
    "query": {
        "bool": {
            "filter": [
                {"range": {"@timestamp": {"gte": "now-1h"}}},
                {"term": {"environment": "prod"}},
            ]
        }
    },
    "aggs": {
        "per_minute": {
            "date_histogram": {"field": "@timestamp", "fixed_interval": "1m"}
        }
    },
}

error_rate_query = {
    "size": 0,
    "query": {"range": {"@timestamp": {"gte": "now-1h"}}},
    "aggs": {
        "errors": {"filter": {"range": {"status": {"gte": 500}}}},
        "total": {"value_count": {"field": "status"}},
    },
}

qps_result = es.search(index=index, body=qps_query)
error_result = es.search(index=index, body=error_rate_query)

# Email rendering omitted
print(qps_result)
print(error_result)
```

## Example 2: Mapping notes

- qps_query -> timeseries panel with ES datasource
- error_rate_query -> stat panel or timeseries panel
- report sections -> rows (Overview -> Details)
- preserve report time window (now-1h)
- keep query semantics identical

## Example 3: Output Jsonnet (single-file dashboard)

```jsonnet
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
```

## Example 4: Optional reusable helper (mixin/lib)

Only create `mixin/lib` helpers when they are reused across dashboards.

```jsonnet
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
```
