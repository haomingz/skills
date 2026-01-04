# Grafana-Code Unified Library API Quick Reference

> This document provides a quick API reference for grafana-code unified libraries

## Contents
- panels.libsonnet - Panel Constructors
- standards.libsonnet - Standard Specifications
- prom.libsonnet - Prometheus Query Tools
- themes.libsonnet - Visual Themes
- layouts.libsonnet - Layout Standards
- helpers.libsonnet - Utility Functions
- clickhouse.libsonnet - ClickHouse Query Tools
- Complete Example
- Common Questions

## panels.libsonnet - Panel Constructors

### statPanel - Stat Panel
```jsonnet
panels.statPanel(
  title,              // Panel title
  targets,            // Query targets array
  unit,               // Unit (e.g. standards.units.qps)
  thresholds,         // Threshold config (e.g. standards.thresholds.neutral)
  description=null    // Optional: Panel description
)
```

**Usage example:**
```jsonnet
local qpsStat = panels.statPanel(
  title='Current QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width);
```

### timeseriesPanel - Timeseries Chart
```jsonnet
panels.timeseriesPanel(
  title,                                    // Panel title
  targets,                                  // Query targets array
  unit,                                     // Unit
  legendConfig=standards.legend.standard,   // Legend config
  theme=themes.timeseries.standard,         // Theme
  thresholds=null,                          // Optional: Thresholds
  description=null                          // Optional: Description
)
```

**Usage example:**
```jsonnet
local qpsPanel = panels.timeseriesPanel(
  title='QPS Trend',
  targets=[prom.target('sum(rate(http_requests_total[1m]))', 'QPS')],
  unit=standards.units.qps,
  legendConfig=standards.legend.hidden,
  theme=themes.timeseries.standard
)
+ g.panel.timeSeries.gridPos.withH(6)
+ g.panel.timeSeries.gridPos.withW(24);
```

### tablePanel - Table Panel
```jsonnet
panels.tablePanel(
  title,              // Panel title
  targets,            // Query targets array
  description=null,   // Optional: Description
  overrides=[]        // Optional: Field overrides
)
```

### rowPanel - Row Separator
```jsonnet
panels.rowPanel(
  title,              // Row title
  collapsed=false     // Whether collapsed
)
```

### barGaugePanel - Bar Gauge
```jsonnet
panels.barGaugePanel(
  title,
  targets,
  unit,
  thresholds,
  orientation='horizontal'  // or 'vertical'
)
```

### pieChartPanel - Pie Chart
```jsonnet
panels.pieChartPanel(
  title,
  targets,
  unit,
  legendPlacement='right'  // or 'bottom'
)
```

## standards.libsonnet - Standard Specifications

### Units

**Request-related:**
- `standards.units.qps` - Request rate ('reqps')
- `standards.units.errorRate` - Error rate ('percentunit', 0-1 range)

**Percentage:**
- `standards.units.percent01` - 0-1 range percentage ('percentunit')
- `standards.units.percent100` - 0-100 range percentage ('percent')

**Time:**
- `standards.units.seconds` - Seconds ('s')
- `standards.units.milliseconds` - Milliseconds ('ms')

**Size:**
- `standards.units.bytes` - Bytes ('bytes')
- `standards.units.Bps` - Bytes per second ('Bps')
- `standards.units.Mbps` - Megabits per second ('Mbits')

**General:**
- `standards.units.count` - Count ('short')

### Thresholds

**Error rate threshold (0-1 range):**
```jsonnet
standards.thresholds.errorRate
// < 0.02 green, 0.02-0.05 yellow, >= 0.05 red
```

**Success rate threshold (0-1 range):**
```jsonnet
standards.thresholds.successRate
// < 0.95 red, 0.95-0.99 yellow, >= 0.99 green
```

**Latency threshold (seconds):**
```jsonnet
standards.thresholds.latencySeconds
// < 0.5s green, 0.5-1s yellow, >= 1s red
```

**Latency threshold (milliseconds):**
```jsonnet
standards.thresholds.latencyMilliseconds
// < 500ms green, 500-1000ms yellow, >= 1000ms red
```

**CPU usage (0-1 range):**
```jsonnet
standards.thresholds.cpuUsage
// < 0.7 green, 0.7-0.85 yellow, >= 0.85 red
```

**Memory usage (0-1 range):**
```jsonnet
standards.thresholds.memoryUsage
// < 0.8 green, 0.8-0.9 yellow, >= 0.9 red
```

**Apdex Score (0-1 range):**
```jsonnet
standards.thresholds.apdex
// < 0.5 red, 0.5-0.7 yellow, 0.7-0.85 orange, >= 0.85 green
```

**Neutral threshold (no alert meaning):**
```jsonnet
standards.thresholds.neutral
// Blue
```

### Legend Configuration

**Choose based on series count:**
- `standards.legend.detailed` - 1-3 series (shows lastNotNull, max, mean, sum)
- `standards.legend.standard` - 4-8 series (shows lastNotNull, max, mean)
- `standards.legend.compact` - 9+ series (shows lastNotNull only)
- `standards.legend.hidden` - Hide Legend

**Placement options:**
- `standards.legend.bottomList` - Bottom list
- `standards.legend.rightList` - Right list
- `standards.legend.rightTable` - Right table

### Tooltip Configuration
- `standards.tooltip.multi` - Multi-series tooltip
- `standards.tooltip.single` - Single-series tooltip

## prom.libsonnet - Prometheus Query Tools

### Basic Target Constructors

**Timeseries query (for Timeseries Panel):**
```jsonnet
prom.target(
  expr='rate(http_requests_total[1m])',
  legendFormat='{{job}}',
  refId='A'
)
```

**Instant query (for Stat Panel and Table):**
```jsonnet
prom.instantTarget(
  expr='sum(up)',
  legendFormat='',
  refId='A'
)
```

**Table query:**
```jsonnet
prom.tableTarget(
  expr='topk(10, sum by (job) (rate(http_requests_total[1m])))',
  legendFormat='',
  refId='A'
)
```

### Common Query Patterns

**Rate query (auto uses $__rate_interval):**
```jsonnet
prom.rateQuery(
  metric='http_requests_total',
  selector='{job="api"}',
  legendFormat='{{method}}'
)
```

**Sum by aggregation:**
```jsonnet
prom.sumBy(
  expr='rate(http_requests_total[1m])',
  by=['job', 'status'],
  legendFormat='{{job}} - {{status}}'
)
```

**Topk query:**
```jsonnet
prom.topk(
  k=10,
  expr='sum by (endpoint) (rate(http_requests_total[1m]))',
  legendFormat='{{endpoint}}'
)
```

### Percentile Queries

```jsonnet
// P50 (median)
prom.p50(
  metric='http_request_duration',
  selector='{job="api"}',
  legendFormat='P50'
)

// P90
prom.p90(
  metric='http_request_duration',
  selector='{job="api"}',
  legendFormat='P90'
)

// P99
prom.p99(
  metric='http_request_duration',
  selector='{job="api"}',
  legendFormat='P99'
)

// Custom percentile
prom.histogramQuantile(
  metric='http_request_duration',
  selector='{job="api"}',
  quantile=0.95,
  legendFormat='P95'
)
```

### Ratio Queries

**Error rate:**
```jsonnet
prom.errorRate(
  metric='http_requests_total',
  selector='{job="api"}',
  statusLabel='status',  // default 'status'
  legendFormat='Error Rate'
)
// Result: 5xx error rate
```

**Success rate:**
```jsonnet
prom.successRate(
  metric='http_requests_total',
  selector='{job="api"}',
  statusLabel='status',
  legendFormat='Success Rate'
)
// Result: 2xx/3xx success rate
```

**Cache hit rate:**
```jsonnet
prom.cacheHitRate(
  hitMetric='cache_hits_total',
  totalMetric='cache_requests_total',
  selector='{service="cache"}',
  legendFormat='Hit Rate'
)
```

### Apdex Score

```jsonnet
prom.apdex(
  metric='http_request_duration',
  selector='{job="api"}',
  satisfiedThreshold=0.5,   // Satisfied threshold (seconds)
  tolerableThreshold=1.0,   // Tolerable threshold (seconds)
  legendFormat='Apdex'
)
// Formula: (satisfied + tolerable/2) / total
```

## themes.libsonnet - Visual Themes

### Timeseries Themes

**Standard line chart (most common):**
```jsonnet
themes.timeseries.standard
// fillOpacity: 18, lineWidth: 2
```

**Emphasized line chart (important metrics):**
```jsonnet
themes.timeseries.emphasized
// fillOpacity: 25, lineWidth: 3
```

**Light line chart (reference lines):**
```jsonnet
themes.timeseries.light
// fillOpacity: 10, lineWidth: 1
```

**Bar chart:**
```jsonnet
themes.timeseries.bars
// drawStyle: 'bars', fillOpacity: 70
```

**Stacked area chart:**
```jsonnet
themes.timeseries.areaStacked
// stacking: { mode: 'normal' }
```

**Stacked bar chart:**
```jsonnet
themes.timeseries.barsStacked
```

**Percent stacked:**
```jsonnet
themes.timeseries.percentStacked
```

### Color Overrides

```jsonnet
// Fixed color
themes.colorOverrides.fixed('metric_name', helpers.colors.blue)

// Dashed line
themes.colorOverrides.dashed('metric_name')

// Thick line
themes.colorOverrides.thickLine('metric_name', width=3)
```

## layouts.libsonnet - Layout Standards

### Panel Size Standards

**Stat Panel:**
```jsonnet
layouts.stat.height           // 3
layouts.stat.width            // 4 (6 per row)
layouts.stat.large.height     // 4
layouts.stat.large.width      // 6 (4 per row)
layouts.stat.small.height     // 3
layouts.stat.small.width      // 3 (8 per row)
```

**Timeseries Panel:**
```jsonnet
layouts.timeseries.small      // { height: 6, width: 8 }  (3 per row)
layouts.timeseries.medium     // { height: 7, width: 12 } (2 per row)
layouts.timeseries.large      // { height: 8, width: 24 } (full row)
layouts.timeseries.xlarge     // { height: 10, width: 24 }
```

**Table Panel:**
```jsonnet
layouts.table.height          // 8
layouts.table.width           // 24 (full row)
layouts.table.small           // { height: 7, width: 12 } (2 per row)
layouts.table.large           // { height: 10, width: 24 }
```

**Row:**
```jsonnet
layouts.row.height            // 1
layouts.row.width             // 24
```

### GridPos Tools

```jsonnet
// Manually create gridPos
layouts.gridPos(h=6, w=8, x=0, y=0)

// Auto-calculate gridPos (based on index)
layouts.autoGridPos(
  index=0,        // panel index
  panelHeight=6,
  panelWidth=8,
  startY=0
)
```

## helpers.libsonnet - Utility Functions

### Color Constants

```jsonnet
helpers.colors.green    // '#52C41A'
helpers.colors.yellow   // '#FAAD14'
helpers.colors.orange   // '#FFA940'
helpers.colors.red      // '#F5222D'
helpers.colors.blue     // '#1890FF'

// Semantic colors
helpers.colors.success  // = green
helpers.colors.warning  // = yellow
helpers.colors.danger   // = red
helpers.colors.info     // = blue
```

### Utility Functions

**Build Prometheus selector:**
```jsonnet
helpers.buildSelector(
  { hostname: '$hostname', idc: '$idc' },  // label object
  ',status=~"2.."'  // optional: extra label filter
)
// Result: {hostname=~"$hostname",idc=~"$idc",status=~"2.."}
```

**Generate Panel description:**
```jsonnet
helpers.panelDescription(
  title='Overall QPS',
  metricType='raw count',
  metricName='http_requests_total',
  alternative='sum(requests_per_second)'  // optional
)
```

## clickhouse.libsonnet - ClickHouse Query Tools

### Target Constructor

```jsonnet
clickhouse.target(
  rawSql='SELECT * FROM table WHERE $__timeFilter(timestamp)',
  format='time_series',  // or 'table'
  refId='A'
)
```

### Unit Constants

```jsonnet
clickhouse.units.count
clickhouse.units.bytes
clickhouse.units.seconds
```

## Complete Example

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// Import unified libraries (alphabetically)
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// Config
local config = {
  datasource: { type: 'prometheus', uid: 'prometheus-thanos' },
  timezone: 'browser',
  timeFrom: 'now-6h',
  pluginVersion: '12.3.0',
};

// Selector
local baseSelector = '{job="api",env="prod"}';

// Panels
local qpsStat = panels.statPanel(
  title='Current QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total' + baseSelector + '[1m]))', '')],
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

local errorRateStat = panels.statPanel(
  title='Error Rate',
  targets=[prom.errorRate('http_requests_total', baseSelector, 'status', '')],
  unit=standards.units.errorRate,
  thresholds=standards.thresholds.errorRate
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(4)
+ g.panel.stat.gridPos.withY(0)
+ g.panel.stat.standardOptions.withMin(0)
+ g.panel.stat.standardOptions.withMax(1);

local qpsPanel = panels.timeseriesPanel(
  title='QPS Trend',
  targets=[prom.target('sum(rate(http_requests_total' + baseSelector + '[1m]))', 'QPS')],
  unit=standards.units.qps,
  legendConfig=standards.legend.hidden,
  theme=themes.timeseries.standard
)
+ g.panel.timeSeries.gridPos.withH(layouts.timeseries.small.height)
+ g.panel.timeSeries.gridPos.withW(layouts.timeseries.large.width)
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withY(4);

// Dashboard
g.dashboard.new('API Monitoring')
+ g.dashboard.withUid('api-monitor')
+ g.dashboard.withTags(['api', 'monitoring'])
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withPanels([qpsStat, errorRateStat, qpsPanel])
```

## Common Questions

### Q: How to choose appropriate Legend configuration?
**A:** Based on series count:
- 1-3 series → `standards.legend.detailed`
- 4-8 series → `standards.legend.standard`
- 9+ series → `standards.legend.compact`
- Single series/reference line → `standards.legend.hidden`

### Q: What's the difference between errorRate and successRate?
**A:**
- `errorRate` threshold: lower is better (< 2% green)
- `successRate` threshold: higher is better (>= 99% green)

### Q: How to override default library configurations?
**A:** Use `+` operator:
```jsonnet
panels.timeseriesPanel(...)
+ g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30)
```

### Q: Difference between percent01 and percent100?
**A:**
- `percent01` - for 0-1 range (e.g. error rate 0.05 displays as 5%)
- `percent100` - for 0-100 range (e.g. CPU usage 75)
