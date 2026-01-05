# Grafana Jsonnet Refactor Checklist

## Structure

- Keep a single self-contained file with local helpers.
- Structure the file: imports → config → constants → helpers → panels → rows → variables → dashboard.
- Avoid dashboard-specific lib files; only update `mixin/lib/*.libsonnet` for reusable patterns.

## Unified libraries

- Panels use `panels.*Panel()` constructors.
- Prometheus targets use `prom.*` helpers where applicable.
- Units and thresholds use `standards.units.*` and `standards.thresholds.*`.
- Timeseries styling uses `themes.timeseries.*`.
- Grid sizing uses `layouts.*` when possible.

## Datasource

- Centralize datasource config in `config`.
- Pass `config.datasource` (or `config.datasources.*`) into all panel constructors.

## Layout and rows

- Preserve row order and collapsed state.
- Preserve gridPos (`H/W/X/Y`) and adjust only when needed.
- Use `panels.rowPanel(...)` or `g.panel.row.new(...)` with `g.panel.row.withPanels([...])`.

## Cleanups

- Remove duplicated selectors and helpers.
- Replace raw Grafonnet panels with unified constructors.
- Keep reusable patterns out of dashboard-specific files only if truly generic.

## Validation

- `mixin/build.sh` or `mixin/build.ps1` succeeds.
- Panel behavior matches the original dashboard.
- No raw JSON blobs remain.
- `__inputs` / `__requires` are present when manual import is supported.
- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.
- Variables return values in Grafana; no duplicate or extra variables.
- Regex filters preserved or added where needed.
- Row membership is correct (`gridPos.y` aligns to row `gridPos.y`, and rows include panels).
