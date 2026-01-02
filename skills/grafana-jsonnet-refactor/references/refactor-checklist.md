# Grafana Jsonnet Refactor Checklist

## Structure

- Entrypoint contains imports, config, variables, and dashboard assembly only.
- Use entrypoint + lib when there are repeated patterns or many panels.
- Keep single-file dashboards if changes would add unnecessary complexity.

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

## Cleanups

- Remove duplicated selectors and helpers.
- Replace raw Grafonnet panels with unified constructors.
- Keep reusable patterns out of dashboard-specific files only if truly generic.

## Validation

- `mixin/build.sh` or `mixin/build.ps1` succeeds.
- Panel behavior matches the original dashboard.
- No raw JSON blobs remain.
