# Visual Style & Threshold Guides

Use this when applying project-specific visual conventions for colors, graph styles, and table layouts. Keep it out of default context unless styling guidance is needed.

## Color & threshold semantics

- Prefer semantic tokens over hex when available (e.g., `helpers.colors.*`, `standards.presets.colors.*`).
- Prefer preset thresholds when available (e.g., `standards.thresholds.*`, `standards.presets.thresholds.*`).
- If helpers/standards libs exist, keep imports consistent with the repo conventions.
- Use semantic mapping for series (examples):
  - Rate/throughput: `standards.presets.colors.rate` / `throughput`
  - Errors/error rate: `standards.presets.colors.errors` / `errorRate`
  - Latency: `standards.presets.colors.duration` / `latency`
  - Availability/success: `standards.presets.colors.successRate` / `availability`
  - Saturation: `standards.presets.colors.saturation`

## Stylize helpers (only when thresholds/colors are not explicit)

```jsonnet
local panel = panels.timeseriesPanel(...)
+ panels.timeSeriesStylizeByName.rate('QPS')
+ panels.timeSeriesStylizeByName.errors('5xx')
+ panels.timeSeriesStylizeByName.duration('P99');

local stat = panels.statPanel(...) + panels.statStylize.errors();
local table = panels.tablePanel(...) + panels.tableStylizeByName.rate('QPS');
```

If `thresholds` or color overrides are already set, do not apply stylize (avoid override conflicts).

## Time series override helpers (when available)

- `timeSeriesOverrides.axisRightByName(...)` for secondary axis series.
- `timeSeriesOverrides.quantileColors(...)` for p50/p90/p99.
- `timeSeriesOverrides.statusCodeColors(...)` for HTTP 2xx/3xx/4xx/5xx.
- `timeSeriesOverrides.dashedByName(...)` for reference lines.

## Timeseries themes & graph styles

- Default theme: `themes.timeseries.grafana`
- Emphasized: `themes.timeseries.emphasized`
- Light: `themes.timeseries.light`
- Bars: `themes.timeseries.bars`
- Stacked: `themes.timeseries.areaStacked` / `percentStacked`

Style guidance by metric type (adapt to local conventions):
- Rates/throughput: smooth lines + low fill (15-25)
- Discrete counters: `lineInterpolation=stepAfter`
- Events: bars + high fill (85-90)
- Percent utilization: smooth
- Reference lines: linear + dashed + zero fill
- Latency percentiles: smooth or linear

Common overrides:

```jsonnet
local panel = panels.timeseriesPanel(...)
+ panels.timeSeriesOverrides.dashedByName('CPU Cores', dash=[8, 8], color=helpers.colors.purple)
+ panels.timeSeriesOverrides.axisRightByName('Utilization', unit=standards.units.percent100)
+ panels.timeSeriesOverrides.pointsByName('P99', pointSize=4);

// Threshold area fill
panel + panels.timeSeriesStyles.thresholdArea(18);
```

## Table configuration patterns

- Prefer `prom.tableTarget(...)` for table queries.
- Keep transformations explicit for complex tables.
- Use `panels.tableDefaults.base(...)` for defaults and `panels.tableOverrides.*` for per-column styling.
- If helper maps exist (e.g., common label exclude maps), use them to prune noise.

```jsonnet
local transforms = [
  panels.tableTransforms.labelsToFields,
  panels.tableTransforms.seriesToColumns('instance'),
  panels.tableTransforms.filterInclude('/^Value #|^instance$/'),
];

local overrides = [
  panels.tableOverrides.fixedColorText('Service', helpers.colors.blue, width=180),
  panels.tableOverrides.gaugePercentByName('CPU Utilization', width=120),
  panels.tableOverrides.thresholdBackground('Error Rate', standards.presets.thresholds.errorRatePercent),
];
```

## Guardrails

- Avoid hard-coded hex values.
- Avoid over-smoothing counters or step-like series.
- Keep overrides matcher strings aligned with legend/field names.
