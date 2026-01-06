---
name: grafana-report-to-dashboard
description: Converts Python report scripts (Elasticsearch queries + email output) into Grafana Jsonnet dashboards with dual-datasource support (ClickHouse + Elasticsearch ES7/ES8). Use when migrating scheduled email reports to real-time monitoring dashboards, building multi-datasource observability views, or converting report calculations to interactive panels.
---

# Report Script to Grafana Jsonnet Dashboard

Migrate Python email reports (Elasticsearch queries) to real-time Grafana dashboards with dual-datasource support (ClickHouse + ES7/ES8). Preserve report calculations while enabling interactive visualization.

**Not suitable for**: Standard dashboard creation (use `grafana-json-to-jsonnet` for JSON imports), refactoring existing Jsonnet (use `grafana-jsonnet-refactor`), or single-datasource dashboards.

## Workflow with progress tracking

Copy this checklist and track your progress:

```
Migration Progress:
- [ ] Step 1: Read datasource-mapping.md for ES/ClickHouse patterns
- [ ] Step 2: Extract report metrics and logic
- [ ] Step 3: Map report sections to panel types
- [ ] Step 4: Define dual datasource configuration
- [ ] Step 5: Implement panels with explicit datasource selection
- [ ] Step 6: Compile and verify against report outputs
```

**Step 1: Read datasource-mapping.md**

Load `references/datasource-mapping.md` to understand Elasticsearch and ClickHouse query target patterns.

**Step 2: Extract report metrics and logic**

From the Python script, identify:
- Queries (ES aggregations, filters)
- Time windows and date ranges
- Post-processing calculations
- Grouping and aggregations
- Metric formulas

**Step 3: Map report sections to panel types**

Use this mapping:
- Summary numbers → `panels.statPanel`
- Time trends → `panels.timeseriesPanel`
- Top-N rankings → `panels.tablePanel`
- Comparisons → `panels.barGaugePanel` or timeseries with bars theme

For detailed mapping examples, see `references/examples.md`.

**Step 4: Define dual datasource configuration**

Create config with both datasources:

```jsonnet
local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
};
```

For manual import mode, use `${DS_ELASTICSEARCH}` and `${DS_CLICKHOUSE}` variables.

**Step 5: Implement panels**

Implement each panel using unified libraries. Select datasource explicitly per panel. Preserve report calculations and metric semantics. Use `standards.*` units/thresholds, `themes.*` for timeseries style, and `layouts.*` or `panels.withIdAndPatches(...)` for grid placement.

**Step 6: Compile and verify**

Run `mixin/build.sh` or `mixin/build.ps1`. Verify panel results match the report for a known time window. Test both ES7/ES8 and ClickHouse queries in Grafana.

## Panel type quick reference

- Summary numbers → `panels.statPanel`
- Time trends → `panels.timeseriesPanel`
- Top-N rankings → `panels.tablePanel`
- Comparisons → `panels.barGaugePanel` or timeseries with bars theme

## Quality checks

- Build succeeds (`mixin/build.sh` or `mixin/build.ps1`).
- Panel results match the report for a known time window.
- ES7/ES8 and ClickHouse queries return data in Grafana.
- Jsonnet is kept in a single file with local helpers (no dashboard-specific libs).
- `__inputs` / `__requires` are present when manual import is supported.
- Variables return values in Grafana; no duplicate or extra variables.
- Regex filters preserved or added where needed.
- Row membership is correct (`gridPos.y` aligns to row `gridPos.y`, and rows include panels).

## Manual import support

- Use `${DS_ELASTICSEARCH}` and `${DS_CLICKHOUSE}` in manual import mode.
- Add `__inputs` and `__requires` so Grafana can prompt for datasources.

## Dual datasource example

```jsonnet
local ES_UID = 'elasticsearch-prod';
// local ES_UID = '${DS_ELASTICSEARCH}';

local CH_UID = 'clickhouse-prod';
// local CH_UID = '${DS_CLICKHOUSE}';

local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
};

// Panel using Elasticsearch
local errorCountPanel = panels.statPanel(
  title='Error Count',
  targets=[/* ES query */],
  datasource=config.datasources.elasticsearch,
  unit=standards.units.short,
  pluginVersion=config.pluginVersion
);

// Panel using ClickHouse
local requestsPanel = panels.timeseriesPanel(
  title='Requests',
  targets=[/* ClickHouse query */],
  datasource=config.datasources.clickhouse,
  unit=standards.units.qps,
  pluginVersion=config.pluginVersion
);
```

## Formatting guardrail

- Do not run `jsonnetfmt` / `jsonnet fmt` on generated Jsonnet files. Keep formatting manual and consistent with grafana-code mixin style.

## References (load as needed)

- `references/datasource-mapping.md`
- `references/full-report-playbook.md`
- `references/examples.md`
