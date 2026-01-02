---
name: grafana-report-to-dashboard
description: This skill should be used when converting Python report scripts to Grafana Jsonnet dashboards with multi-datasource support. Trigger phrases include "migrate report to grafana", "convert python report", "elasticsearch to grafana", "report script to dashboard", "clickhouse grafana dashboard". Use when migrating Elasticsearch report scripts to Grafana or when a dashboard must support dual ClickHouse + Elasticsearch (ES7/ES8) datasource backends. CRITICAL: Generate a single self-contained jsonnet file - do NOT create dashboard-specific lib files.
---

# Report Script to Grafana Jsonnet Dashboard

## Inputs
- Python report script (Elasticsearch queries + email output)
- Target mixin system folder (for example `mixin/application`)
- Datasource UIDs for ClickHouse and Elasticsearch (ES7/ES8)

## Outputs
- `<dashboard>.jsonnet` (single self-contained dashboard file)
- Optionally: Updates to `../lib/*.libsonnet` (only if adding truly reusable components to the general library)
- Optional: `references/` files documenting query mappings

## Steps

### Step 1: Understand grafana-code conventions and datasource patterns
Review the following reference documents:
- `references/best-practices.md` - Code organization and naming conventions
- `references/lib-api-reference.md` - Unified library API quick reference
- `references/datasource-mapping.md` - Elasticsearch and ClickHouse query patterns
- `references/style-guide.md` - grafana-code style guide

### Step 2: Analyze the Python report script

**Extract report metrics:**
1. **Elasticsearch queries**: Identify ES query bodies, indexes, and aggregations
   - Which indexes are being queried?
   - What are the key aggregations (terms, date_histogram, sum, avg)?
   - What filters are applied?
   - What time ranges are used?

2. **SQL queries (ClickHouse)**: Identify SQL queries or implicit calculations
   - Which tables are queried?
   - What metrics are calculated (COUNT, SUM, AVG, GROUP BY)?
   - What WHERE conditions are applied?

3. **Report structure**: Understand the output format
   - Summary statistics → Stat panels
   - Time-based trends → Timeseries panels
   - Top-N rankings → Table panels
   - Comparisons → Bar gauge panels

### Step 3: Map report sections to Grafana panels

**Panel type mapping:**

```python
# Python report output → Grafana panel type

# Summary numbers (single values)
print(f"Total requests: {total_requests}")
print(f"Error rate: {error_rate:.2%}")
# → panels.statPanel()

# Time-based trends (line charts in email)
df.plot(x='timestamp', y='requests')
# → panels.timeseriesPanel()

# Top-N tables (rankings)
print(top_10_endpoints)
# → panels.tablePanel()

# Comparisons (bar charts)
df.plot(kind='bar', x='service', y='requests')
# → panels.barGaugePanel() or panels.timeseriesPanel() with bars theme
```

### Step 4: Convert queries to Grafana datasource format

**For Elasticsearch queries:**

```python
# Python Elasticsearch query
{
  "query": {
    "bool": {
      "filter": [
        {"range": {"@timestamp": {"gte": "now-24h"}}},
        {"term": {"status": "error"}}
      ]
    }
  },
  "aggs": {
    "errors_over_time": {
      "date_histogram": {"field": "@timestamp", "interval": "1h"},
      "aggs": {"count": {"value_count": {"field": "_id"}}}
    }
  }
}
```

Convert to Grafana Elasticsearch query using MCP tools or manual construction.

**For ClickHouse queries:**

```python
# Python SQL query
SELECT
  toStartOfHour(timestamp) as hour,
  COUNT(*) as requests
FROM logs
WHERE status = 'error'
  AND timestamp >= now() - INTERVAL 24 HOUR
GROUP BY hour
ORDER BY hour
```

Convert to Grafana ClickHouse query format.

### Step 5: Create a single self-contained Jsonnet file

**CRITICAL REQUIREMENTS:**
1. Generate a **single self-contained jsonnet file** - do NOT create `lib/<dashboard>_panels.libsonnet`
2. All panel definitions should be written directly in the main jsonnet file as `local` variables
3. Support multiple datasources (ClickHouse, Elasticsearch ES7/ES8)
4. Use unified libraries for panel construction
5. Use latest Grafana features

**File Structure:**

```jsonnet
// 1. Grafonnet main library
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// 2. Unified libraries (alphabetically)
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// 3. Datasource configuration (dual-mode support for multiple datasources)
// For provisioning: use actual UIDs
// For manual import: switch to '${DS_CLICKHOUSE}' and '${DS_ELASTICSEARCH}' to allow datasource selection
// NOTE: Adjust datasource types and UIDs based on your actual report datasources
local CLICKHOUSE_UID = 'clickhouse-main';  // Replace with your ClickHouse datasource UID
// local CLICKHOUSE_UID = '${DS_CLICKHOUSE}';  // manual import mode

local ELASTICSEARCH_UID = 'elasticsearch-prod';  // Replace with your Elasticsearch datasource UID
// local ELASTICSEARCH_UID = '${DS_ELASTICSEARCH}';  // manual import mode

local config = {
  datasources: {
    // Adjust datasource types to match your report's data sources
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: CLICKHOUSE_UID },
    elasticsearch: { type: 'elasticsearch', uid: ELASTICSEARCH_UID },
    // Add more datasources if needed (e.g., prometheus, mysql, postgres)
  },
  timezone: 'browser',  // Or 'utc', or specific timezone like 'Asia/Shanghai'
  timeFrom: 'now-24h',  // Adjust to match your report's time window (e.g., 'now-7d', 'now-30d')
  timeTo: 'now',
  pluginVersion: '12.3.0',  // Current Grafana version, update as needed
};

// 4. Helper functions for datasource-specific queries
local esQuery(index, query, timeField='@timestamp') = {
  // Elasticsearch query builder
  datasource: {
    type: config.datasources.elasticsearch.type,
    uid: config.datasources.elasticsearch.uid,
  },
  // ... query implementation ...
};

local clickhouseQuery(sql) = {
  // ClickHouse query builder
  datasource: {
    type: config.datasources.clickhouse.type,
    uid: config.datasources.clickhouse.uid,
  },
  rawSql: sql,
  format: 'time_series',
};

// 5. Variable definitions
local indexVariable = g.dashboard.variable.query.new(
  'index',
  'indices'  // Elasticsearch indices query
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasources.elasticsearch.type,
  uid=config.datasources.elasticsearch.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.refresh.onLoad();

// 6. Panel definitions (ALL panels defined here, not in separate lib file)
// NOTE: Replace panel titles, queries, table names, and aggregations with your actual report metrics

// Example: Summary stat from ClickHouse
local totalRequestsStat = panels.statPanel(
  title='Total Requests (24h)',
  targets=[
    clickhouseQuery(
      'SELECT COUNT(*) FROM logs WHERE timestamp >= now() - INTERVAL 24 HOUR'
    ),
  ],
  datasource=config.datasources.clickhouse,
  unit=standards.units.count,
  thresholds=standards.thresholds.neutral,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

// Example: Error rate from Elasticsearch
local errorRateStat = panels.statPanel(
  title='Error Rate (24h)',
  targets=[
    esQuery(
      index='logs-*',
      query={
        // Elasticsearch aggregation for error rate
        // ... query structure ...
      }
    ),
  ],
  datasource=config.datasources.elasticsearch,
  unit=standards.units.errorRate,
  thresholds=standards.thresholds.errorRate,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(4)
+ g.panel.stat.gridPos.withY(0);

// Example: Timeseries panel from ClickHouse
local requestsTrendPanel = panels.timeseriesPanel(
  title='Requests Over Time',
  targets=[
    clickhouseQuery(|||
      SELECT
        toStartOfHour(timestamp) as time,
        COUNT(*) as requests
      FROM logs
      WHERE timestamp >= $__fromTime AND timestamp <= $__toTime
      GROUP BY time
      ORDER BY time
    |||),
  ],
  datasource=config.datasources.clickhouse,
  unit=standards.units.qps,
  legendConfig=standards.legend.hidden,
  theme=themes.timeseries.standard,
  pluginVersion=config.pluginVersion
)
+ g.panel.timeSeries.gridPos.withH(6)
+ g.panel.timeSeries.gridPos.withW(24)
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withY(4);

// Example: Top-N table from Elasticsearch
local topEndpointsTable = panels.tablePanel(
  title='Top 10 Endpoints',
  targets=[
    esQuery(
      index='logs-*',
      query={
        // Elasticsearch aggregation for top endpoints
        // ... query structure ...
      }
    ),
  ],
  datasource=config.datasources.elasticsearch,
  description='Top 10 endpoints by request count'
)
+ g.panel.table.gridPos.withH(8)
+ g.panel.table.gridPos.withW(24)
+ g.panel.table.gridPos.withX(0)
+ g.panel.table.gridPos.withY(10);

// ... more panels ...

// 7. Annotations configuration
local annotationsObj = {
  list: [
    {
      builtIn: 1,
      datasource: { type: 'grafana', uid: '-- Grafana --' },
      enable: true,
      hide: true,
      iconColor: 'rgba(0, 211, 255, 1)',
      name: 'Annotations & Alerts',
      type: 'dashboard',
    },
  ],
};

// 8. Dashboard construction (using chained method calls)
local baseDashboard = g.dashboard.new('Report Dashboard')  // Replace with your report dashboard title
+ g.dashboard.withUid('report-dashboard')  // Replace with unique dashboard UID (lowercase, hyphens)
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withEditable(true)
+ g.dashboard.withTags(['report', 'migration'])  // Adjust tags to match your report type
+ g.dashboard.withRefresh('5m')  // Adjust refresh interval based on report data freshness (e.g., '1m', '15m', '1h')
+ g.dashboard.withVariables([indexVariable])
+ g.dashboard.withPanels([
  totalRequestsStat,
  errorRateStat,
  requestsTrendPanel,
  topEndpointsTable,
  // ... more panels ...
]);

// 9. Final export with metadata (supports manual import with multi-datasource selection)
// NOTE: This example shows multiple datasources (ClickHouse + Elasticsearch)
// Adjust the datasource types in __inputs and __requires to match your actual datasources
// You may have different combinations: ClickHouse only, Elasticsearch only, or other datasources
baseDashboard {
  annotations: annotationsObj,
  graphTooltip: 0,  // 0 = default, 1 = shared crosshair, 2 = shared tooltip
  schemaVersion: 42,
  version: 1,
  __inputs: [
    {
      name: 'DS_CLICKHOUSE',  // Adjust to your datasource variable name
      label: 'ClickHouse Datasource',  // Update label to match datasource type
      description: 'Select ClickHouse datasource',  // Update description
      type: 'datasource',
      pluginId: 'grafana-clickhouse-datasource',  // Change to actual plugin ID
      pluginName: 'ClickHouse',  // Change to actual plugin name
    },
    {
      name: 'DS_ELASTICSEARCH',  // Adjust to your datasource variable name
      label: 'Elasticsearch Datasource',  // Update label to match datasource type
      description: 'Select Elasticsearch datasource',  // Update description
      type: 'datasource',
      pluginId: 'elasticsearch',  // Change to actual plugin ID (e.g., 'prometheus', 'mysql')
      pluginName: 'Elasticsearch',  // Change to actual plugin name
    },
    // Add more __inputs entries if you have additional datasources
  ],
  __elements: {},
  __requires: [
    {
      type: 'datasource',
      id: 'grafana-clickhouse-datasource',  // Change to actual datasource plugin ID
      name: 'ClickHouse',  // Change to actual datasource name
      version: '1.0.0',
    },
    {
      type: 'datasource',
      id: 'elasticsearch',  // Change to actual datasource plugin ID
      name: 'Elasticsearch',  // Change to actual datasource name
      version: '1.0.0',
    },
    // Add more __requires entries if you have additional datasources
    {
      type: 'grafana',
      id: 'grafana',
      name: 'Grafana',
      version: config.pluginVersion,
    },
    {
      type: 'panel',
      id: 'timeseries',
      name: 'Time series',
      version: '',
    },
    {
      type: 'panel',
      id: 'stat',
      name: 'Stat',
      version: '',
    },
    {
      type: 'panel',
      id: 'table',
      name: 'Table',
      version: '',
    },
    // Add other panel types as needed: bargauge, gauge, etc.
  ],
}
```

### Step 6: Handle multi-datasource complexity

**Strategy 1: Separate panels by datasource**

```jsonnet
// Group panels by datasource
local clickhousePanels = [
  totalRequestsStat,
  requestsTrendPanel,
  // ... more ClickHouse panels
];

local elasticsearchPanels = [
  errorRateStat,
  topEndpointsTable,
  // ... more Elasticsearch panels
];

// Combine in dashboard
g.dashboard.withPanels(clickhousePanels + elasticsearchPanels)
```

**Strategy 2: Dual-source comparison panels**

```jsonnet
// Compare metrics from both sources
local requestsComparisonPanel = panels.timeseriesPanel(
  title='Requests: ClickHouse vs Elasticsearch',
  targets=[
    clickhouseQuery('SELECT ...') + { refId: 'A', legendFormat: 'ClickHouse' },
    esQuery('logs-*', {...}) + { refId: 'B', legendFormat: 'Elasticsearch' },
  ],
  // Use first datasource as default, targets override individually
  datasource=config.datasources.clickhouse,
  unit=standards.units.count,
  legendConfig=standards.legend.standard,
  theme=themes.timeseries.standard
);
```

### Step 7: Document query mappings (optional)

If the conversion is complex, create a reference document:

**File**: `references/report-migration-notes.md`

```markdown
# Report Migration Notes

## Original Report: daily_traffic_report.py

### Metric 1: Total Requests
- **Source**: ClickHouse `logs` table
- **Original SQL**: `SELECT COUNT(*) FROM logs WHERE date = yesterday()`
- **Grafana Panel**: `totalRequestsStat`
- **Query**: Uses `clickhouseQuery()` helper

### Metric 2: Error Rate
- **Source**: Elasticsearch `logs-*` index
- **Original ES Query**: `{"aggs": {"errors": {...}}}`
- **Grafana Panel**: `errorRateStat`
- **Query**: Uses `esQuery()` helper
```

### Step 8: Verify and test

**Compile and verify:**
```bash
# Linux/macOS
cd mixin
bash build.sh

# Windows
cd mixin
.\build.ps1
```

**Quality checks:**
- [ ] Compiles without errors
- [ ] All datasource references are correct
- [ ] Queries return data in Grafana
- [ ] Panel visualizations match report output
- [ ] Variables work correctly
- [ ] Time ranges align with report logic
- [ ] Single self-contained file (no dashboard-specific lib)

**Import and test in Grafana:**
1. Compile to JSON: `bash build.sh`
2. Import the generated JSON in Grafana UI
3. Verify all panels display correctly
4. Compare metrics with original Python report output
5. Check that both datasources work properly

## Important Notes

**Conversion Philosophy:**
1. **Single self-contained file** - Generate ONE `<dashboard>.jsonnet` file
2. **No dashboard-specific libs** - Do NOT create `lib/<dashboard>_panels.libsonnet`
3. **Multi-datasource support** - Use config object to manage multiple datasources
4. **Query helpers** - Create local helper functions for datasource-specific queries
5. **Maintain report logic** - Ensure Grafana metrics match original report calculations

**Multi-Datasource Configuration:**
```jsonnet
// ✅ Correct: Config object with multiple datasources
local config = {
  datasources: {
    // Replace UIDs with your actual datasource UIDs or use template variables for manual import
    clickhouse: { type: 'grafana-clickhouse-datasource', uid: 'clickhouse-main' },  // Example UID
    elasticsearch: { type: 'elasticsearch', uid: 'elasticsearch-prod' },  // Example UID
  },
};

// Use in panels
panels.statPanel(
  title='Metric from ClickHouse',
  targets=[...],
  datasource=config.datasources.clickhouse,  // Specify which datasource
  // ...
)
```

**When to Update General Lib:**
Only modify `../lib/*.libsonnet` when adding truly reusable patterns:
- ✅ New Elasticsearch query pattern used by multiple dashboards → add to new `lib/elasticsearch.libsonnet`
- ✅ New ClickHouse query helper → add to `lib/clickhouse.libsonnet`
- ❌ Report-specific calculations → keep in the dashboard jsonnet file
- ❌ Custom aggregations for this report → keep in the dashboard jsonnet file

**Quality Standards:**
- Every panel must use `panels.*Panel()` constructors
- All units must use `standards.units.*`
- All thresholds must use `standards.thresholds.*`
- Variables constructed using Grafonnet's `g.dashboard.variable.*` methods
- Datasource references must go through config object
- Query helpers should be local functions in the dashboard file (unless truly reusable)

**Reference:**
- See `references/datasource-mapping.md` for Elasticsearch and ClickHouse query patterns
- See `references/best-practices.md` for code organization guidelines
- See `references/lib-api-reference.md` for unified library API reference