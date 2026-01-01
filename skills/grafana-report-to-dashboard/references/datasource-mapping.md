# Datasource Mapping (Elasticsearch + ClickHouse)

This skill assumes the grafana-code unified libraries. Use raw target objects for Elasticsearch and `clickhouse.sqlTarget` for ClickHouse.

## Dual Datasource Config

```
local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: 'es-logs' },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: 'ch-logs' },
  },
  pluginVersion: '12.3.0',
};
```

## Elasticsearch Target Pattern (Grafana JSON)

Grafana expects Elasticsearch targets as raw objects. You can either:

1. Export a panel from Grafana and paste the target JSON into Jsonnet, or
2. Use this minimal pattern and fill in the fields:

```
{
  refId: 'A',
  datasource: config.datasources.elasticsearch,
  queryType: 'lucene',
  query: 'status:200',
  timeField: '@timestamp',
  metrics: [
    { id: '1', type: 'count' },
  ],
  bucketAggs: [
    {
      id: '2',
      type: 'date_histogram',
      field: '@timestamp',
      settings: { interval: 'auto' },
    },
  ],
}
```

## ES7 vs ES8 Notes

- Field names may differ (for example `@timestamp` vs `timestamp`).
- Index patterns may differ (for example `logs-*` vs `logs-v8-*`).
- Prefer explicit `queryType` and `timeField` so the target is portable.

## ClickHouse Target Pattern

```
clickhouse.sqlTarget(
  config.datasources.clickhouse,
  |||
  SELECT
    toStartOfMinute(timestamp) AS time,
    count() AS requests
  FROM nginx_logs
  WHERE timestamp >= now() - INTERVAL 1 HOUR
  GROUP BY time
  ORDER BY time
  |||,
  refId='A'
)
```