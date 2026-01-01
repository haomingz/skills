---
name: grafana-report-to-dashboard
description: Convert Python Elasticsearch report scripts into Grafana Jsonnet dashboards, and add dual ClickHouse + Elasticsearch (ES7/ES8) datasource support. Use when migrating report scripts to Grafana or when a dashboard must support multiple data backends.
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
- `references/example-report.py`
- `references/example-dashboard.jsonnet`
- `references/example-dashboard-lib.libsonnet`