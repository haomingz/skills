---
name: grafana-report-to-dashboard
description: Converts Python report scripts (Elasticsearch queries + email output) into Grafana Jsonnet dashboards with dual-datasource support (ClickHouse + Elasticsearch ES7/ES8). Use when migrating scheduled email reports to real-time monitoring dashboards, building multi-datasource observability views, or converting report calculations to interactive panels.
---

# Report Script to Grafana Jsonnet Dashboard

## When to use this skill

This skill is most effective when:
- Converting Python email reports with Elasticsearch queries to Grafana dashboards
- Migrating scheduled report scripts to real-time monitoring and alerting
- Building dashboards requiring dual-datasource support (ClickHouse + ES7/ES8)
- Preserving report calculations and metrics while transitioning to interactive visualization
- Creating dashboards that support multiple backend datasources with explicit per-panel selection

Not suitable for:
- Standard dashboard creation (use `grafana-json-to-jsonnet` for JSON imports)
- Refactoring existing Jsonnet (use `grafana-jsonnet-refactor`)
- Single-datasource dashboards without report migration context

## Inputs

- Python report script (queries, post-processing, and email output)
- Target mixin system folder
- Datasource UIDs for ClickHouse and Elasticsearch

## Outputs

- `<dashboard>.jsonnet` (single self-contained dashboard file)
- Optionally: updates to `../lib/*.libsonnet` (only if adding truly reusable components to the general library)
- Optional: `references/` files documenting query mappings

## Critical requirements

- Single self-contained file; no dashboard-specific lib files in final output.
- Preserve report calculations and metric semantics.
- Support ClickHouse + Elasticsearch (ES7/ES8) with explicit datasource selection per panel.
- Use unified libraries for panels and standard units/thresholds.

## Report-to-panel mapping (quick)

- Summary numbers -> `panels.statPanel`
- Time trends -> `panels.timeseriesPanel`
- Top-N rankings -> `panels.tablePanel`
- Comparisons -> `panels.barGaugePanel` or timeseries with bars theme

## Workflow

1. Read `references/datasource-mapping.md` for Elasticsearch and ClickHouse target patterns.
2. Extract report metrics and logic (queries, filters, time windows, aggregations, post-processing).
3. Map report sections to panels (stat, timeseries, table).
4. Define dual datasource config (`config.datasources.elasticsearch` and `config.datasources.clickhouse`).
5. Implement panels with unified libs and explicit datasource selection in the single file.
6. Compile and verify against the report outputs.

## Guardrails

- Keep calculations consistent with the original report.
- Keep datasources explicit per panel.
- Avoid adding dashboard-specific code to global libs.

## Quality checks

- Build succeeds (`mixin/build.sh` or `mixin/build.ps1`).
- Panel results match the report for a known time window.
- ES7/ES8 and ClickHouse queries return data in Grafana.

## Manual import support (recommended)

- Use `${DS_ELASTICSEARCH}` and `${DS_CLICKHOUSE}` in manual import mode.
- Add `__inputs` and `__requires` so Grafana can prompt for datasources.

## Dual datasource snippet

```jsonnet
local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
};
```

## Required references

- `references/datasource-mapping.md`
- `references/report-migration-guide.md`

## Optional MCP usage

- Context7: Grafana/Grafonnet APIs when a query target or panel option is unclear.
- Exa: datasource plugin docs for ES7/ES8 or ClickHouse target fields.

## References (load as needed)

- `references/full-report-playbook.md`
- `references/example-report.py`
- `references/example-dashboard.jsonnet`
- `references/example-dashboard-lib.libsonnet`
