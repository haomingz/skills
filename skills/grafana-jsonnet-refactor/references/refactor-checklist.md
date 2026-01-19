# Grafana Jsonnet Refactor Checklist

## Structure

- Keep a single self-contained file with local helpers.
- Follow the existing file order; a common, readable order is: imports → config → constants → variables → selectors/helpers → panel wrappers → panels → rows → annotations → dashboard.
- Avoid dashboard-specific lib files; only update shared lib files when a pattern is truly reusable.

## Unified libraries

- Prefer unified panel constructors when available (`panels.*`).
- Prefer `prom.*` helpers where applicable.
- Use `standards.*` units/thresholds when available.
- Use `themes.*` for time series styling when available.
- Use layout helpers if they exist in the repo.
- If a panel helper exposes `withIdAndPatches`, use it to apply `id/gridPos` plus `fieldConfig` and `options` patches consistently.
- Prefer helper queries for rate/increase, histogram quantiles, and error/success rates when provided.

## Datasource

- Centralize datasource config in `config`.
- Preserve datasource selection patterns (UID vs variable) and any manual-import `__inputs` blocks if present.
- Pass `config.datasource` (or `config.datasources.*`) into all panel constructors.

## Layout and rows

- Preserve row order and collapsed state.
- Preserve gridPos (`H/W/X/Y`) and adjust only when needed.
- Use `panels.rowPanel(...)` or `g.panel.row.new(...)` with `g.panel.row.withPanels([...])`.
- Keep panel `gridPos.y` aligned with row `gridPos.y` for each row group.
- Preserve repeat panels and their repeat variables; keep `maxPerRow` consistent when used.
- Use layout/grid helpers if present to keep widths/heights consistent.

## Variables

- Preserve variable names, labels, defaults, refresh mode, and `includeAll`/`multi` flags.
- Keep variable query semantics; do not change regex filters unless required.
- Preserve `allValue` and any special values used by selectors.
- Avoid duplicates; remove unused variables only if behavior is confirmed unchanged.

## Table panels and transforms

- Preserve transformations order and intent (organize, rename, series-to-columns/rows).
- Keep field overrides (units, thresholds, widths, value mappings) consistent.
- Remove unused fields only when output is verified unchanged.
- If helper defaults/overrides exist (e.g., `tableDefaults`, `tableOverrides`, `tableTransforms`), prefer them for consistency.
- Use helper maps for excluding common label fields when provided.

## Cleanups

- Remove duplicated selectors and helpers.
- Replace raw Grafonnet panels with unified constructors when available.
- Preserve wrapper signatures when they protect many callsites.
- Move patterns into shared libs only when they are truly generic.

## Validation

- Repo build/compile script succeeds (if available).
- Panel behavior matches the original dashboard.
- No raw JSON blobs remain.
- `__inputs` / `__requires` are present when manual import is supported.
- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.
- Variables return values in Grafana; no duplicate or extra variables.
- Regex filters preserved or added where needed.
- Row membership is correct (`gridPos.y` aligns to row `gridPos.y`, and rows include panels).
- Annotations and dashboard metadata (`schemaVersion`, `graphTooltip`, `version`) remain intact when present.
