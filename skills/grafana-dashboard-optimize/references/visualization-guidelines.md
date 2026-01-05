# Visualization Guidelines

## Panel Type Selection

- Stat: single current value
- Timeseries: trend over time
- Table: top-N or breakdowns
- Bar gauge: comparisons across categories
- Heatmap: distributions

## Units and Thresholds

Use `standards.units.*` and `standards.thresholds.*`:

```jsonnet
unit=standards.units.qps
thresholds=standards.thresholds.errorRate
```

Avoid raw unit strings unless necessary.

## Legends

- Single series: hide or compact
- Many series: compact or table legend
- Use `standards.legend.*` when possible

## Table Optimization

- Remove unused fields (IDs, raw labels, duplicate columns).
- Add overrides for units, thresholds, and column widths.
- Apply sorting and column order for fast scanning.
- Use color/thresholds on the most important numeric columns.
