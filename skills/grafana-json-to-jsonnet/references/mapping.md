# Panel and Target Mapping

Use this mapping to replace raw panels with unified library builders.

## Panel Types

- `timeseries` -> `panels.timeseriesPanel`
- `stat` -> `panels.statPanel`
- `table` -> `panels.tablePanel`
- `bargauge` -> `panels.barGaugePanel`
- `piechart` -> `panels.pieChartPanel`
- `row` -> `panels.rowPanel`

## Target Types

Prometheus:

```
prom.target('<expr>', '<legend>')
prom.instantTarget('<expr>', '<legend>')
prom.tableTarget('<expr>', '<legend>')
```

ClickHouse:

```
clickhouse.sqlTarget(
  config.datasource,
  |||
  SELECT ...
  |||,
  refId='A'
)
```

## Unit Mapping (Common)

- `reqps` -> `standards.units.qps`
- `percentunit` -> `standards.units.percent01`
- `percent` -> `standards.units.percent100`
- `s` -> `standards.units.seconds`
- `ms` -> `standards.units.milliseconds`
- `bytes` -> `standards.units.bytes`
- `short` -> `standards.units.count`

## Thresholds (Examples)

- Error rate -> `standards.thresholds.errorRate`
- Success rate -> `standards.thresholds.successRate`
- Latency (seconds) -> `standards.thresholds.latencySeconds`
- Latency (ms) -> `standards.thresholds.latencyMilliseconds`
- Neutral/blue -> `standards.thresholds.neutral`

## Fallback Strategy

If a panel type is unknown:

1. Keep the raw panel JSON in `<dashboard>_raw_panels.json`.
2. Wrap it in a helper in `<dashboard>_panels.libsonnet`.
3. Convert manually later using the closest `panels.*` constructor.