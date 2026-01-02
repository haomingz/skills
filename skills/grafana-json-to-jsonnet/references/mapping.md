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

## Unsupported panels

If a panel type is unknown or not supported by unified libs:

1. Use Grafonnet directly in the same dashboard file.
2. Apply `standards.units.*` and `standards.thresholds.*` where possible.
3. Do not emit raw JSON files or dashboard-specific lib files.
