# grafana-code Jsonnet Style Guide (Short)

Use this checklist when generating or refactoring dashboards.

## Import Order

1. Grafonnet main library
2. Unified libraries (alphabetical)
3. Config constants
4. Local helpers
5. Variables
6. Panels
7. Dashboard assembly

## Config Block

Use the same pattern as `grafana-code/mixin`:

```
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
- Apply layout via `g.panel.*.gridPos.withH/W/X/Y`.

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