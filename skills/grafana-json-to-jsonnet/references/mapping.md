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

Use `standards.units.*` and `standards.thresholds.*` from `references/lib-api-reference.md`.

## Unsupported panels

If a panel type is unknown or not supported by unified libs:

1. Use Grafonnet directly in the same dashboard file.
2. Apply `standards.units.*` and `standards.thresholds.*` where possible.
3. Do not emit raw JSON files or dashboard-specific lib files.
