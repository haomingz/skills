# Jsonnet Style and Best Practices (Merged)

Use this reference for code style, layout conventions, and unified library usage when converting Grafana JSON exports to Jsonnet. Load only when you need guidance on formatting, naming, or standard patterns.

## Import order and file structure

1. Grafonnet main library
2. Unified libraries (alphabetical)
3. Config constants
4. Constants
5. Local helpers
6. Panels
7. Rows
8. Variables
9. Dashboard assembly

## Config block

```jsonnet
// Provisioning mode (real UID). For manual import, switch to ${DS_*}.
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  timezone: 'browser',
  timeFrom: 'now-24h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};
```

Default time range is `now-24h ~ now`. For log-heavy dashboards (nginx log / nginx vts), use `now-6h ~ now`.

## Naming conventions

- Locals: lowerCamelCase (`errorRatePanel`, `serviceVariable`)
- Panel locals: suffix by type (`qpsStat`, `latencyPanel`, `topErrorsTable`)
- Row locals: `overviewRow`, `detailsRow`
- Dashboard UID: hyphen-case derived from name (`service-overview`)

## Panel construction

- Use unified constructors: `panels.*Panel()`
- Use `standards.units.*`, `standards.thresholds.*`, `standards.legend.*`
- Apply layout via `layouts.*` or `panels.withIdAndPatches(...)`
- Layer advanced options with Grafonnet `.with*()` as needed
- For dashboards that must use only built-in panel types, stick to `timeseries`, `stat`, `bargauge`, `gauge`, `table`.

## Row construction

- Use `panels.rowPanel(...)` or `g.panel.row.new(...)`
- Attach panels via `g.panel.row.withPanels([...])`
- Keep panel `gridPos.y` aligned with row `gridPos.y`

## Units, thresholds, legend, theme

- Units: `standards.units.*`
- Thresholds: `standards.thresholds.*`
- Legend: `standards.legend.*`
- Timeseries theme: `themes.timeseries.*`

## Query construction

- Use `prom.*` helpers when possible
- Counters use `rate()` or `increase()`
- Prefer percentiles for latency (p50/p90/p99)
- Avoid high-cardinality selectors without aggregation

## Variables

- Use `g.dashboard.variable.*`
- Set datasource explicitly (type + uid)
- Preserve regex filters where needed
- Validate dropdowns return values in Grafana

## Dashboard metadata

- Add `__inputs` / `__requires` when manual import is supported
- Keep `pluginVersion` consistent across panels and `__requires`
- Preserve annotations when present in source JSON

## Formatting guardrail

- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.
