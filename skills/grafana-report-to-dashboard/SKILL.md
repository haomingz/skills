---
name: grafana-report-to-dashboard
description: This skill should be used when converting Python report scripts to Grafana Jsonnet dashboards with multi-datasource support. Trigger phrases include "migrate report to grafana", "convert python report", "elasticsearch to grafana", "report script to dashboard", "clickhouse grafana dashboard". Use when migrating Elasticsearch report scripts to Grafana or when a dashboard must support dual ClickHouse + Elasticsearch (ES7/ES8) datasource backends.
---

# Report Script to Grafana Jsonnet Dashboard

## Inputs
- Python report script (Elasticsearch queries + email output)
- Target mixin system folder
- Datasource UIDs for ClickHouse and Elasticsearch (ES7/ES8)

## Outputs
- `<dashboard>.jsonnet` (entrypoint)
- `lib/<dashboard>_panels.libsonnet` (panel builders)
- Optional: `references/` files documenting query mappings

## Steps
1. Read `references/datasource-mapping.md` for Elasticsearch and ClickHouse target patterns.
2. Extract report metrics from the script:
   - identify ES query bodies, indexes, and aggregations
   - identify any SQL queries (ClickHouse) or implicit calculations
3. Map report sections to panels:
   - summary numbers -> `panels.statPanel`
   - time trends -> `panels.timeseriesPanel`
   - top-N tables -> `panels.tablePanel`
4. Define a dual-datasource config:
   - `config.datasources.elasticsearch` and `config.datasources.clickhouse`
   - pass the correct datasource to each panel
5. Build the Jsonnet using unified libraries (`panels`, `standards`, `themes`, `layouts`).
6. Compile with `mixin/build.sh` or `mixin/build.ps1` and verify in Grafana.

## Examples
- `examples/example-report.py`
- `examples/example-dashboard.jsonnet`
- `examples/example-dashboard-lib.libsonnet`