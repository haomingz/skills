# grafana-code Jsonnet Style Guide (Short)

Use this checklist when generating or refactoring dashboards.

## Import Order

1. Grafonnet main library
2. Unified libraries (alphabetical)
3. Config constants
4. Constants
5. Local helpers
6. Panels
7. Rows
8. Variables
9. Dashboard assembly

## Config Block

Use the same pattern as `grafana-code/mixin`:

```
// Provisioning mode (real UID). For manual import, switch to ${DS_*}.
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};
```

## Panel Construction

- Use `panels.*` constructors from `mixin/lib/panels.libsonnet`.
- Use `standards.units.*`, `standards.thresholds.*`, and `standards.legend.*`.
- Apply layout via `layouts.*` and `panels.withIdAndPatches(...)` or `g.panel.*.gridPos.withH/W/X/Y`.

## Row Construction

- Build rows with `panels.rowPanel(...)` or `g.panel.row.new(...)`.
- Attach panels via `g.panel.row.withPanels([...])`.
- Keep panel `gridPos.y` aligned with row `gridPos.y`.

## Dashboard Metadata

- Add `__inputs` / `__requires` when manual import is supported.
- Keep `pluginVersion` consistent across panels and `__requires`.
- Preserve `annotations` from the source JSON.

## Formatting

- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.

## Naming

- Variables: lowerCamelCase (example: `errorRatePanel`)
- Dashboard UID: hyphen-case (example: `nginx-log-metrics`)

## Libraries

Always import and use the unified libs from `mixin/lib/`:

- `helpers.libsonnet`
- `standards.libsonnet`
- `themes.libsonnet`
- `layouts.libsonnet`
- `prometheus.libsonnet`
- `clickhouse.libsonnet`
- `panels.libsonnet`
