# Full Report-to-Dashboard Playbook

Use this document to migrate Python report scripts into Grafana Jsonnet dashboards with ClickHouse and Elasticsearch support.

## Contents

- [Reference index (load as needed)](#reference-index-load-as-needed)
- [Quick start (summary)](#quick-start-summary)
- [Goals and constraints](#goals-and-constraints)
- [Step 1: Analyze the report script](#step-1-analyze-the-report-script)
- [Step 2: Define dashboard structure](#step-2-define-dashboard-structure)
- [Step 3: Configure dual datasources](#step-3-configure-dual-datasources)
- [Step 4: Convert queries](#step-4-convert-queries)
- [Step 5: Build panels](#step-5-build-panels)
- [Step 6: Preserve calculations](#step-6-preserve-calculations)
- [Step 7: Compile and verify](#step-7-compile-and-verify)
- [Quality checklist](#quality-checklist)

---

## Reference index (load as needed)

- `references/datasource-mapping.md` - Elasticsearch and ClickHouse target patterns.
- `references/examples.md` - end-to-end examples from report script to dashboard.

## Quick start (summary)

1. Extract report queries, filters, and post-processing logic.
2. Map report sections to panels (stat, timeseries, table).
3. Define dual datasources and manual import support.
4. Build panels with explicit datasource selection.
5. Preserve calculations and verify in Grafana.

## Goals and constraints

- Preserve calculations and metric semantics from the report.
- Support both Elasticsearch (ES7/ES8) and ClickHouse.
- Keep the dashboard structure readable and maintainable.
- Keep a single Jsonnet file with local helpers (no dashboard-specific libs).
- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.

## Step 1: Analyze the report script

Capture:
- Queries (ES DSL and SQL)
- Aggregations, group-by fields, filters, and time windows
- Output sections (tables, summaries, alerts)
- Any post-processing logic done in Python

If the report calculates derived metrics in Python, plan where those calculations will live:
- Prefer moving them into query expressions when possible.
- If not possible, use Grafana transformations or calculations in Jsonnet.

## Step 2: Define dashboard structure

Map report sections to panels:
- Summary counters -> `panels.statPanel`
- Time-series trends -> `panels.timeseriesPanel`
- Top-N lists -> `panels.tablePanel`
- Distributions -> `panels.barGaugePanel` or Grafonnet heatmap

Mapping checklist:
- Each report section has a corresponding panel
- Panel titles match report section names
- Ordering follows the report narrative

See `references/examples.md` for mapping and output examples.

## Step 3: Configure dual datasources

Use a shared config with explicit datasource objects:

```jsonnet
local ES_UID = 'elasticsearch-prod';
local CH_UID = 'clickhouse-prod';

local config = {
  datasources: {
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CH_UID },
  },
  pluginVersion: '12.3.0',
  timezone: 'browser',
  timeFrom: 'now-24h',
  timeTo: 'now',
};
```

Manual import mode (datasource picker):

```jsonnet
// local ES_UID = '${DS_ELASTICSEARCH}';
// local CH_UID = '${DS_CLICKHOUSE}';
```

If you support manual import, add `__inputs` / `__requires` to the final export:

```jsonnet
baseDashboard {
  __inputs: [
    {
      name: 'DS_ELASTICSEARCH',
      label: 'Elasticsearch Datasource',
      type: 'datasource',
      pluginId: 'elasticsearch',
      pluginName: 'Elasticsearch',
    },
    {
      name: 'DS_CLICKHOUSE',
      label: 'ClickHouse Datasource',
      type: 'datasource',
      pluginId: 'grafana-clickhouse-datasource',
      pluginName: 'ClickHouse',
    },
  ],
  __requires: [
    { type: 'datasource', id: 'elasticsearch', name: 'Elasticsearch', version: '1.0.0' },
    { type: 'datasource', id: 'grafana-clickhouse-datasource', name: 'ClickHouse', version: '1.0.0' },
    { type: 'grafana', id: 'grafana', name: 'Grafana', version: config.pluginVersion },
  ],
}
```

## Step 4: Translate queries

### Elasticsearch (ES7/ES8)

- Convert Python ES DSL into Grafana query targets.
- Keep index patterns and time field consistent.
- Preserve aggregation buckets and filters.
- Use `references/datasource-mapping.md` for target patterns.

### ClickHouse

- Convert report SQL to ClickHouse query targets.
- Ensure time filters use Grafana time variables.
- Prefer grouping by time buckets compatible with Grafana.

## Step 5: Build panels with unified libs

Example panel using ClickHouse:

```jsonnet
local errorRatePanel = panels.timeseriesPanel(
  title='Error Rate',
  targets=[clickhouse.sqlTarget(
    config.datasources.clickhouse,
    |||
SELECT
  $__timeGroup(timestamp, '1m') AS time,
  sum(errors) / sum(total) AS error_rate
FROM api_errors
WHERE $__timeFilter(timestamp)
GROUP BY time
ORDER BY time
    |||
  )],
  datasource=config.datasources.clickhouse,
  unit=standards.units.errorRate,
  pluginVersion=config.pluginVersion
)
+ g.panel.timeSeries.gridPos.withH(6)
+ g.panel.timeSeries.gridPos.withW(12);
```

Example panel using Elasticsearch:

```jsonnet
local topErrors = panels.tablePanel(
  title='Top Errors',
  targets=[{
    refId: 'A',
    datasource: config.datasources.elasticsearch,
    queryType: 'lucene',
    query: 'status:500',
    timeField: '@timestamp',
    metrics: [
      { id: '1', type: 'count' },
    ],
    bucketAggs: [
      {
        id: '2',
        type: 'terms',
        field: 'message.keyword',
        settings: { size: 10 },
      },
    ],
  }],
  datasource=config.datasources.elasticsearch,
  pluginVersion=config.pluginVersion
);
```

## Step 6: Assemble dashboard

- Include variables for environment, service, or cluster if the report uses them.
- Preserve time range defaults from the report.
- Keep tags and descriptions aligned with the report purpose.
- Add `__inputs` / `__requires` when manual import is supported.

## Step 7: Validate

- Compile with `mixin/build.sh` or `mixin/build.ps1`.
- Import into Grafana and compare against the original report for a known time window.
- Verify that ES7/ES8 and ClickHouse results match expectations.
- Verify variables return values (no duplicates, regex preserved).
- Verify row membership (panel `gridPos.y` aligns to row `gridPos.y`, and rows include panels).

## Common pitfalls

- Mixing datasources inside a single panel target list.
- Changing aggregation logic while simplifying queries.
- Losing report context (labels, section titles, or ordering).
- Ignoring Python post-processing logic that affects results.
- Creating dashboard-specific lib files instead of local helpers.

## Examples

- `references/examples.md`
