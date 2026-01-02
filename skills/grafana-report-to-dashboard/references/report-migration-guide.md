# Report Migration Guide (Short)

This guide summarizes how to convert Python report scripts into Grafana Jsonnet dashboards. For detailed steps and examples, read `references/full-report-playbook.md`.

## Core requirements

- Preserve metric semantics and calculations from the report.
- Support both ClickHouse and Elasticsearch (ES7/ES8) datasources.
- Keep dashboard structure clear and reviewable.

## Recommended workflow

1. Extract report logic (queries, aggregations, filters, time windows, and grouping).
2. Map report sections to panels:
   - Summary numbers -> `panels.statPanel`
   - Trends -> `panels.timeseriesPanel`
   - Top-N -> `panels.tablePanel`
3. Define dual datasource config:
   - `config.datasources.elasticsearch` and `config.datasources.clickhouse`.
4. Build panels with unified libs and explicit datasource selection.
5. Compile and verify in Grafana.

## Datasource config snippet

```jsonnet
local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
};
```

Manual import mode (datasource selection in UI) uses `__inputs` and `${DS_*}` values:

```jsonnet
// local ES_UID = '${DS_ELASTICSEARCH}';
// local CH_UID = '${DS_CLICKHOUSE}';
```

## Panels pick the right datasource

```jsonnet
local errorTable = panels.tablePanel(
  title='Top Errors',
  targets=[elasticsearch.esQueryTarget(...)],
  datasource=config.datasources.elasticsearch,
  pluginVersion=config.pluginVersion
);
```
