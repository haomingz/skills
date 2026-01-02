---
name: grafana-dashboard-optimize
description: This skill optimizes Grafana Jsonnet dashboard content for professional observability and SRE use. Trigger phrases include "optimize dashboard", "improve dashboard quality", "review dashboard observability", "enhance monitoring dashboard", "dashboard content audit". Use when you need to improve an existing dashboard's usability, diagnostic capability, visualization effectiveness, and alignment with observability best practices (RED/USE/Golden Signals). This skill focuses on CONTENT optimization, not code structure refactoring.
---

# Grafana Dashboard Content Optimization (Observability / SRE Perspective)

## Purpose

This skill helps you **optimize the actual content and observability quality** of existing Grafana Jsonnet dashboards.

**What this skill does:**
- Improve dashboard usability for on-call engineers and SRE teams
- Enhance diagnostic capabilities and anomaly detection
- Optimize query efficiency and metric usage
- Apply observability best practices (RED, USE, Golden Signals)
- Improve visual communication and cognitive load reduction

**What this skill does NOT do:**
- Code structure refactoring (use `grafana-jsonnet-refactor` for that)
- Lib abstraction or file organization
- Code style formatting

## Target Users

This skill is designed for dashboards used by:
- On-call engineers during incidents
- SRE teams monitoring service health
- DevOps teams tracking infrastructure
- Development teams observing application performance
- Management viewing high-level health metrics

## Inputs

- Path to existing Grafana Jsonnet dashboard file
- Optional: Dashboard's monitoring purpose and target audience
- Optional: Known pain points or areas of concern

## Outputs

- Comprehensive dashboard quality assessment report
- Specific optimization recommendations by category
- Priority levels for each recommendation (Critical / Recommended / Optional)
- Example Jsonnet code snippets for key improvements
- Updated dashboard file with optimizations applied (if requested)

## Optimization Framework

### Phase 1: Understanding (CRITICAL - Do Not Skip)

Before making any changes, you MUST complete this understanding phase:

**1.1 Dashboard Purpose Analysis**
- What is this dashboard monitoring? (Service, infrastructure, business metrics)
- Who is the primary audience? (On-call, SRE, DevOps, developers, management)
- What questions should this dashboard answer?
- What monitoring strategy does it follow? (RED, USE, Golden Signals, custom)

**1.2 Current State Assessment**
- How many panels exist?
- How are rows organized?
- What datasources are used?
- What time ranges are typically viewed?
- Are there existing variables?

**1.3 Semantic Understanding**
- What does each row represent in the monitoring hierarchy?
- What is each panel trying to show?
- How do panels relate to each other?
- What is the logical flow for troubleshooting?

**Document your understanding before proceeding to optimization.**

### Phase 2: Seven-Dimensional Optimization

#### Dimension 1: Panel Semantics and Structure

**Audit Questions:**
- Does every panel have a clear purpose?
- Are there redundant or overlapping panels?
- Are there missing critical observability views?
- Is information density appropriate (not too sparse, not too crowded)?

**Common Issues:**
- ❌ Generic panel titles like "Panel 1", "Metrics", "Graph"
- ❌ Duplicate information across multiple panels
- ❌ Missing error rate, latency percentiles, or saturation metrics
- ❌ Too many panels that don't contribute to troubleshooting

**Optimization Actions:**
- Merge panels with similar intent
- Split panels that try to show too much
- Remove panels that don't add diagnostic value
- Add missing observability perspectives:
  - Error rates and error types
  - Latency distribution (p50, p90, p99, p999)
  - Traffic/throughput trends
  - Resource saturation indicators
  - Comparison panels (current vs baseline, A/B comparison)
  - Top-N offenders (slowest queries, highest error services)

**Example: Apply RED Method**
```jsonnet
// ❌ Before: Generic "Metrics" panel
local metricsPanel = panels.timeseriesPanel(
  title='Metrics',
  targets=[prom.target('http_requests_total', '')],
  // ...
);

// ✅ After: RED method structure
// R - Rate
local requestRatePanel = panels.timeseriesPanel(
  title='Request Rate (requests/sec)',
  description='Total incoming request rate. Sudden drops may indicate upstream issues or traffic shifts.',
  targets=[
    prom.target(
      'sum(rate(http_requests_total{job="api"}[5m]))',
      'Total RPS'
    ),
  ],
  unit=standards.units.qps,
  // ...
);

// E - Errors
local errorRatePanel = panels.timeseriesPanel(
  title='Error Rate (%)',
  description='Percentage of requests returning 5xx errors. Threshold: <1% normal, 1-5% warning, >5% critical.',
  targets=[
    prom.errorRate('http_requests_total', '{job="api"}', 'status', 'Error Rate'),
  ],
  unit=standards.units.errorRate,
  thresholds=standards.thresholds.errorRate,
  // ...
);

// D - Duration
local latencyPanel = panels.timeseriesPanel(
  title='Request Latency (p50, p90, p99)',
  description='Request latency distribution. Watch for p99 spikes indicating tail latency issues.',
  targets=[
    prom.p50('http_request_duration_seconds', '{job="api"}', 'p50'),
    prom.p90('http_request_duration_seconds', '{job="api"}', 'p90'),
    prom.p99('http_request_duration_seconds', '{job="api"}', 'p99'),
  ],
  unit=standards.units.seconds,
  legendConfig=standards.legend.standard,
  // ...
);
```

#### Dimension 2: Query Optimization and Metric Usage

**Audit Questions:**
- Are queries efficient and correct?
- Are aggregations appropriate for the data?
- Are there high-cardinality label issues?
- Can queries be simplified or improved?

**Common Issues:**
- ❌ Missing `rate()` or `irate()` for counter metrics
- ❌ Inappropriate aggregation functions
- ❌ High-cardinality labels causing performance issues
- ❌ Inefficient query patterns (unnecessary regex, complex joins)
- ❌ Missing recording rules for expensive calculations

**Optimization Actions:**

**PromQL Best Practices:**
```jsonnet
// ❌ Bad: Counter without rate()
'http_requests_total'

// ✅ Good: Proper rate calculation
'sum(rate(http_requests_total[5m]))'

// ❌ Bad: High cardinality with instance label
'rate(http_requests_total[5m])'  // Could return 1000s of series

// ✅ Good: Aggregate by service only
'sum by (service) (rate(http_requests_total[5m]))'

// ❌ Bad: Inefficient error rate calculation
'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'

// ✅ Good: Use helper function
prom.errorRate('http_requests_total', '{job="api"}', 'status', 'Error Rate')

// ❌ Bad: No range vector for aggregation over time
'avg_over_time(cpu_usage[5m])'  // Missing sample data

// ✅ Good: Proper aggregation
'avg_over_time(cpu_usage[5m])'  // With proper scrape interval context
```

**Query Optimization Checklist:**
- [ ] Use `rate()` for counters, not raw counter values
- [ ] Choose appropriate range vectors (`[1m]`, `[5m]`, `[1h]`) based on scrape interval
- [ ] Aggregate appropriately: `sum by (label)` vs `sum without (label)`
- [ ] Use recording rules for complex/expensive queries
- [ ] Avoid unbounded queries (always use label filters)
- [ ] Use `increase()` for showing total counts over time
- [ ] Consider `avg_over_time()`, `max_over_time()`, `min_over_time()` for smoothing

**SQL/ClickHouse/Elasticsearch Optimization:**
```jsonnet
// ClickHouse: Use materialized views for common aggregations
// Elasticsearch: Limit aggregation buckets, use composite aggregations for large datasets
// Both: Add time range filters, use appropriate indices
```

#### Dimension 3: Variables (Template Variables) Design

**Audit Questions:**
- Are variable names clear and self-explanatory?
- Are default values sensible?
- Are cascading relationships correct?
- Are there unnecessary variables?
- Could variables improve dashboard reusability?

**Common Issues:**
- ❌ Variables named `var1`, `temp`, `x`
- ❌ No default value or poor default choice
- ❌ Variables that are never used
- ❌ Hardcoded values that should be variables

**Optimization Actions:**

```jsonnet
// ❌ Bad: Poor variable design
local var1 = g.dashboard.variable.query.new(
  'var1',
  'label_values(up, job)'
);

// ✅ Good: Clear, useful variable
local environmentVariable = g.dashboard.variable.query.new(
  'environment',
  'label_values(up{service="api"}, environment)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(false)  // Force selection
+ g.dashboard.variable.query.selectionOptions.withMulti(false)
+ g.dashboard.variable.query.withRegex('')  // Optional: filter values
+ g.dashboard.variable.query.refresh.onLoad()  // Refresh on dashboard load
+ { current: { text: 'production', value: 'production' } };  // Sensible default

// ✅ Good: Cascading variables
local serviceVariable = g.dashboard.variable.query.new(
  'service',
  'label_values(up{environment="$environment"}, service)'  // Depends on environment
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.refresh.onTimeRangeChange();  // Refresh when time changes
```

**Variable Best Practices:**
- Use meaningful names: `environment`, `service`, `cluster`, not `var1`
- Set sensible defaults: `production` for environment, not random first value
- Use `includeAll` wisely: good for viewing aggregate, bad when you need to select specific items
- Refresh strategy: `onLoad()` for static, `onTimeRangeChange()` for dynamic
- Order variables logically: general → specific (cluster → namespace → service → pod)

#### Dimension 4: Panel Visualization and Visual Expression

**Audit Questions:**
- Is the panel type appropriate for the data?
- Are colors semantically meaningful?
- Are units and precision correct?
- Are legends helpful or noisy?
- Are thresholds set appropriately?

**Common Issues:**
- ❌ Time series panel for single stat
- ❌ Colors without meaning (random colors)
- ❌ Missing or incorrect units
- ❌ Legends with too many series (100+ lines)
- ❌ No thresholds for alerting thresholds

**Optimization Actions:**

**Panel Type Selection:**
```jsonnet
// Single value → Stat panel
local currentErrorRate = panels.statPanel(
  title='Current Error Rate',
  targets=[...],
  unit=standards.units.errorRate,
  thresholds=standards.thresholds.errorRate,  // Green < 1%, Yellow 1-5%, Red > 5%
);

// Trend over time → Timeseries panel
local errorRateTrend = panels.timeseriesPanel(
  title='Error Rate Over Time',
  targets=[...],
  unit=standards.units.errorRate,
  theme=themes.timeseries.standard,
);

// Top-N ranking → Table panel
local slowestEndpoints = panels.tablePanel(
  title='Top 10 Slowest Endpoints',
  targets=[...],
  description='Ranked by p99 latency in the selected time range',
);

// Distribution → Heatmap panel
local latencyHeatmap = g.panel.heatmap.new('Latency Distribution')
+ g.panel.heatmap.queryOptions.withTargets([...])
+ g.panel.heatmap.options.withCalculate(true);

// Comparison → Bar gauge panel
local serviceComparison = g.panel.barGauge.new('Service Error Rates Comparison')
+ g.panel.barGauge.queryOptions.withTargets([...])
+ g.panel.barGauge.options.withOrientation('horizontal')
+ g.panel.barGauge.standardOptions.withUnit(standards.units.errorRate);
```

**Meaningful Color Usage:**
```jsonnet
// ✅ Good: Semantic colors with thresholds
local diskUsagePanel = panels.statPanel(
  title='Disk Usage',
  targets=[prom.target('disk_used_percent', '')],
  unit=standards.units.percent01,
  thresholds={
    mode: 'absolute',
    steps: [
      { color: 'green', value: null },     // < 70% = healthy
      { color: 'yellow', value: 0.70 },    // 70-85% = warning
      { color: 'orange', value: 0.85 },    // 85-95% = concerning
      { color: 'red', value: 0.95 },       // > 95% = critical
    ],
  },
);

// ✅ Good: Color overrides for specific series
local multiServicePanel = panels.timeseriesPanel(
  title='Service Health',
  targets=[...],
  // ...
)
+ g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
+ g.panel.timeSeries.standardOptions.withOverrides([
  {
    matcher: { id: 'byName', options: 'errors' },
    properties: [
      { id: 'color', value: { mode: 'fixed', fixedColor: 'red' } },
    ],
  },
  {
    matcher: { id: 'byName', options: 'success' },
    properties: [
      { id: 'color', value: { mode: 'fixed', fixedColor: 'green' } },
    ],
  },
]);
```

**Unit and Precision:**
```jsonnet
// ✅ Good: Appropriate units
unit: standards.units.bytes       // For memory, disk
unit: standards.units.qps         // For requests per second
unit: standards.units.seconds     // For latency
unit: standards.units.errorRate   // For error percentage (percentunit)
unit: standards.units.percent01   // For 0-1 percentages
unit: 'reqps'                     // For request rate

// ✅ Good: Control decimals
+ g.panel.stat.standardOptions.withDecimals(2)  // Show 2 decimal places
```

**Legend Optimization:**
```jsonnet
// ❌ Bad: 100+ series with full legend
legendConfig: standards.legend.standard  // Shows all series names

// ✅ Good: Hide legend for single series or use compact mode
legendConfig: standards.legend.hidden    // No legend

// ✅ Good: Compact legend for multiple series
legendConfig: standards.legend.compact   // Minimal legend

// ✅ Good: Table legend for detailed info
legendConfig: {
  displayMode: 'table',
  placement: 'right',
  calcs: ['mean', 'max', 'last'],  // Show aggregated values
  sortBy: 'Max',
  sortDesc: true,
}
```

#### Dimension 5: Layout and Organization

**Audit Questions:**
- Does the layout follow a logical troubleshooting flow?
- Are panel sizes appropriate for their importance?
- Is there visual noise or information overload?
- Do rows represent logical groupings?

**Common Issues:**
- ❌ Random panel arrangement
- ❌ All panels the same size regardless of importance
- ❌ No clear visual hierarchy
- ❌ Too many panels visible at once (cognitive overload)

**Optimization Actions:**

**Dashboard Layout Strategy:**

```
┌─────────────────────────────────────────────────────────────┐
│ Row 1: Overview / Summary (HIGH-LEVEL HEALTH)               │
│ ┌──────────┬──────────┬──────────┬──────────┐              │
│ │ QPS Stat │ Error %  │ p99 Lat  │ Sat. %   │  ← Key metrics
│ └──────────┴──────────┴──────────┴──────────┘              │
├─────────────────────────────────────────────────────────────┤
│ Row 2: Traffic / Request Patterns                           │
│ ┌───────────────────────────────────────────────────┐       │
│ │ Request Rate Over Time (full width)               │       │
│ └───────────────────────────────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│ Row 3: Errors (DIAGNOSTIC)                                  │
│ ┌─────────────────────────┬─────────────────────────┐       │
│ │ Error Rate Trend        │ Top Error Types (table) │       │
│ └─────────────────────────┴─────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│ Row 4: Latency (DIAGNOSTIC)                                 │
│ ┌─────────────────────────┬─────────────────────────┐       │
│ │ Latency Percentiles     │ Slowest Endpoints       │       │
│ └─────────────────────────┴─────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│ Row 5: Resources / Saturation (ROOT CAUSE)                  │
│ ┌──────────┬──────────┬──────────┬──────────┐              │
│ │ CPU %    │ Memory % │ Disk I/O │ Network  │              │
│ └──────────┴──────────┴──────────┴──────────┘              │
└─────────────────────────────────────────────────────────────┘
```

**Layout Principles:**
1. **Top-down hierarchy:** Overview → Symptoms → Root Cause
2. **Left-to-right importance:** Most important on the left
3. **Size = Importance:** Critical metrics get more space
4. **Row collapsing:** Use collapsed rows for details, keep overview rows open by default
5. **Consistent grid:** Use standard widths (6, 8, 12, 24) for alignment

**Example Implementation:**
```jsonnet
// Row 1: Overview (always visible)
local overviewRow = g.dashboard.row.new('Overview');

// Small stat panels at top (4 columns x 6 width = 24 total)
local qpsStat = panels.statPanel(...)
+ g.panel.stat.gridPos.withH(4)
+ g.panel.stat.gridPos.withW(6)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

local errorStat = panels.statPanel(...)
+ g.panel.stat.gridPos.withH(4)
+ g.panel.stat.gridPos.withW(6)
+ g.panel.stat.gridPos.withX(6)
+ g.panel.stat.gridPos.withY(0);

// Row 2: Detailed metrics (collapsible)
local detailsRow = g.dashboard.row.new('Detailed Metrics')
+ g.dashboard.row.withCollapsed(true);  // Collapsed by default

// Full-width trend panel
local trendPanel = panels.timeseriesPanel(...)
+ g.panel.timeSeries.gridPos.withH(8)
+ g.panel.timeSeries.gridPos.withW(24)  // Full width
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withY(4);
```

#### Dimension 6: Titles and Descriptions

**Audit Questions:**
- Do panel titles clearly state what question they answer?
- Are descriptions helpful for understanding metrics?
- Are abbreviations and acronyms explained?
- Is naming consistent across the dashboard?

**Common Issues:**
- ❌ Vague titles: "Metrics", "Graph 1", "Panel"
- ❌ No descriptions
- ❌ Technical jargon without explanation
- ❌ Inconsistent naming conventions

**Optimization Actions:**

```jsonnet
// ❌ Bad: Vague title, no description
local panel1 = panels.timeseriesPanel(
  title='API Metrics',
  targets=[...],
);

// ✅ Good: Specific title, helpful description
local apiErrorRatePanel = panels.timeseriesPanel(
  title='API Error Rate (5xx Errors %)',
  description=|||
    Percentage of API requests returning 5xx server errors.

    **Normal:** < 0.1%
    **Warning:** 0.1% - 1%
    **Critical:** > 1%

    **Troubleshooting:**
    - Check service logs for error details
    - Verify database connectivity
    - Check upstream service dependencies

    **Calculation:** sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
  |||,
  targets=[...],
);

// ✅ Good: Self-documenting variable usage in titles
local dynamicTitlePanel = panels.timeseriesPanel(
  title='[$environment] Service Response Time - $service',  // Variables in title
  description='Response time for selected service in the $environment environment.',
  targets=[...],
);
```

**Title Best Practices:**
- **Be specific:** "API Error Rate (5xx)" not "Errors"
- **Include units:** "Response Time (ms)" not "Response Time"
- **Use variables:** "[$env] $service Errors" for dynamic context
- **Ask questions:** "Are requests failing?" not just "Error Rate"
- **Consistency:** Use same naming pattern across similar panels

**Description Best Practices:**
- **What:** Explain what the metric represents
- **Why:** Why is this metric important
- **Thresholds:** What values are normal/warning/critical
- **How:** How is it calculated (optional: show query)
- **Troubleshooting:** What to check when anomalies occur

#### Dimension 7: Proactive Additional Optimizations

**Beyond the explicit dimensions, consider:**

**7.1 Alert Integration**
```jsonnet
// Add panel descriptions that link to runbooks
description: |||
  Service error rate monitoring.

  **Alert:** This metric triggers PagerDuty alert "HighErrorRate"
  **Runbook:** https://wiki.company.com/runbooks/api-high-error-rate
  **SLO:** 99.9% availability (< 0.1% error rate)
|||
```

**7.2 SLO / SLI Visualization**
```jsonnet
// Add SLO tracking panels
local sloPanel = panels.statPanel(
  title='API Availability SLO (30d)',
  description='Target: 99.9% | Error Budget: 43.2 minutes/month',
  targets=[
    prom.target(|||
      1 - (
        sum(increase(http_requests_total{status=~"5.."}[30d]))
        /
        sum(increase(http_requests_total[30d]))
      )
    |||, 'Current Availability'),
  ],
  unit: standards.units.percent01,
  thresholds: {
    mode: 'absolute',
    steps: [
      { color: 'red', value: null },
      { color: 'yellow', value: 0.998 },  // 99.8%
      { color: 'green', value: 0.999 },   // 99.9% (SLO met)
    ],
  },
);
```

**7.3 Comparison and Context Panels**
```jsonnet
// Add time-shifted comparison
local comparisonPanel = panels.timeseriesPanel(
  title='Request Rate: Current vs 1 Week Ago',
  targets=[
    prom.target('sum(rate(http_requests_total[5m]))', 'Current'),
    prom.target('sum(rate(http_requests_total[5m] offset 7d))', '1 Week Ago'),
  ],
  legendConfig: standards.legend.standard,
);

// Add multi-environment comparison
local multiEnvPanel = panels.timeseriesPanel(
  title='Error Rate: All Environments',
  targets=[
    prom.target('sum by (environment) (rate(http_requests_total{status=~"5.."}[5m]))', '{{environment}}'),
  ],
  description: 'Compare error rates across prod, staging, and dev environments',
);
```

**7.4 Annotation Support**
```jsonnet
// Add deployment annotations
local annotationsConfig = {
  list: [
    {
      datasource: { type: 'grafana', uid: '-- Grafana --' },
      enable: true,
      iconColor: 'rgba(0, 211, 255, 1)',
      name: 'Annotations & Alerts',
      type: 'dashboard',
    },
    {
      datasource: config.datasource,
      enable: true,
      expr: 'deployment_event{service="$service"}',
      iconColor: 'rgba(255, 96, 96, 1)',
      name: 'Deployments',
      tagKeys: 'version,environment',
      textFormat: 'Deployed {{version}}',
      titleFormat: 'Deployment',
    },
  ],
};
```

**7.5 Performance Optimization**
```jsonnet
// Use appropriate refresh intervals
+ g.dashboard.withRefresh('30s')  // For active monitoring
+ g.dashboard.withRefresh('1m')   // For general dashboards
+ g.dashboard.withRefresh('5m')   // For historical analysis

// Limit time range for expensive queries
+ g.dashboard.time.withFrom('now-6h')  // Reasonable default
+ g.dashboard.time.withTo('now')
```

### Phase 3: Delivery Format

**Assessment Report Structure:**

```markdown
# Dashboard Optimization Assessment: [Dashboard Name]

## Executive Summary
- Dashboard Purpose: [What it monitors]
- Target Audience: [Who uses it]
- Current Maturity Level: [Low / Medium / High - based on Grafana best practices]
- Overall Quality Score: [X/10]
- Priority Recommendations: [Count of Critical/Recommended/Optional]

## Understanding Analysis
[Document your understanding of the dashboard's purpose, audience, and monitoring strategy]

## Findings by Dimension

### 1. Panel Semantics and Structure [Score: X/10]
**Issues Found:**
- [CRITICAL] Missing error rate monitoring
- [RECOMMENDED] Redundant panels showing same metric
- [OPTIONAL] Could add comparison with baseline

**Recommendations:**
- Add RED method panels (Rate, Errors, Duration)
- Remove duplicate "Request Count" panels
- Consider adding Top-N slowest endpoints table

### 2. Query Optimization [Score: X/10]
**Issues Found:**
- [CRITICAL] Counter metric without rate() function
- [RECOMMENDED] High-cardinality query on instance label
- [OPTIONAL] Could use recording rule for complex calculation

**Recommendations:**
- Fix counter query: change `http_requests_total` to `rate(http_requests_total[5m])`
- Aggregate by service instead of instance: `sum by (service) (...)`
- Create recording rule: `api:http_request_rate:5m`

### 3. Variables Design [Score: X/10]
[Similar structure for each dimension...]

### 4. Visualization Quality [Score: X/10]
### 5. Layout and Organization [Score: X/10]
### 6. Titles and Descriptions [Score: X/10]
### 7. Additional Optimizations [Score: X/10]

## Priority Matrix

### Critical (Must Fix)
1. Add error rate monitoring (missing core RED metric)
2. Fix counter queries without rate()
3. Set meaningful thresholds for alerting

### Recommended (Should Fix)
1. Improve panel titles and descriptions
2. Reorganize layout for troubleshooting flow
3. Add variables for environment/service selection

### Optional (Nice to Have)
1. Add SLO tracking panel
2. Add deployment annotations
3. Create comparison with historical baseline

## Code Examples

### Example 1: Fix Counter Query
[Jsonnet code snippet]

### Example 2: Add RED Method Panels
[Jsonnet code snippet]

## Next Steps
1. [Prioritized list of actions]
2. [Estimated impact of each change]
3. [Suggested implementation order]
```

## Best Practices Reference

### Observability Strategies

**RED Method (for Services):**
- **R**ate: Requests per second
- **E**rrors: Number of failed requests
- **D**uration: Latency distribution (p50, p90, p99)

**USE Method (for Resources):**
- **U**tilization: % busy (CPU, memory, disk)
- **S**aturation: Queue length, load
- **E**rrors: Error events

**Golden Signals (Google SRE):**
- **L**atency: Time to serve requests
- **T**raffic: Demand on system
- **E**rrors: Rate of failed requests
- **S**aturation: How "full" the system is

### PromQL Query Patterns

**Rate Calculations:**
```promql
# Request rate
sum(rate(http_requests_total[5m]))

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Increase (total count over time)
increase(http_requests_total[1h])
```

**Aggregations:**
```promql
# By label
sum by (service) (rate(http_requests_total[5m]))

# Without label (remove specific labels)
sum without (instance) (rate(http_requests_total[5m]))

# Top N
topk(10, sum by (endpoint) (rate(http_requests_total[5m])))
```

**Percentiles:**
```promql
# Histogram percentiles
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Summary percentiles (pre-calculated)
http_request_duration_seconds{quantile="0.99"}
```

### Visual Design Principles

**Color Semantics:**
- 🟢 Green: Healthy, normal, success
- 🟡 Yellow: Warning, attention needed
- 🟠 Orange: Degraded, concerning
- 🔴 Red: Critical, error, failure
- 🔵 Blue: Informational, neutral
- 🟣 Purple: Special events, deployments

**Panel Type Selection:**
- **Stat:** Single current value with threshold
- **Timeseries:** Trends over time
- **Table:** Rankings, Top-N, detailed breakdowns
- **Heatmap:** Latency distributions, density plots
- **Bar Gauge:** Comparisons across categories
- **Gauge:** Current value in context of min/max

**Information Hierarchy:**
- **Top:** Most critical, summary metrics
- **Middle:** Diagnostic details, trends
- **Bottom:** Root cause analysis, deep dives
- **Left:** Most important in each row
- **Right:** Supporting details

## Quality Checklist

Use this checklist when optimizing dashboards:

**Dashboard Level:**
- [ ] Clear title indicating purpose
- [ ] Tags for categorization and discovery
- [ ] Appropriate default time range
- [ ] Sensible refresh interval
- [ ] Variables for key dimensions
- [ ] Annotations for deployments/incidents

**Row Level:**
- [ ] Logical grouping and ordering
- [ ] Meaningful row titles
- [ ] Collapsed state for details, open for overview

**Panel Level:**
- [ ] Specific, question-answering title
- [ ] Helpful description with context
- [ ] Correct panel type for data
- [ ] Appropriate units and precision
- [ ] Semantic color usage
- [ ] Meaningful thresholds
- [ ] Legend optimization (hide/compact/table)
- [ ] Proper grid positioning and sizing

**Query Level:**
- [ ] Efficient PromQL/SQL queries
- [ ] Appropriate aggregations
- [ ] Correct rate/increase usage
- [ ] No unbounded cardinality
- [ ] Using recording rules where appropriate
- [ ] Meaningful legend format

**Observability Level:**
- [ ] Follows monitoring strategy (RED/USE/Golden Signals)
- [ ] Complete coverage (no blind spots)
- [ ] Enables troubleshooting workflow
- [ ] Links to runbooks/alerts
- [ ] SLO tracking (if applicable)

## Common Anti-Patterns to Avoid

❌ **"Dashboard Sprawl"**
- Too many one-off dashboards
- No reuse or consolidation
- Fix: Use variables, consolidate similar dashboards

❌ **"Metric Soup"**
- Random metrics with no story
- No clear troubleshooting path
- Fix: Apply observability framework (RED/USE)

❌ **"Query Inefficiency"**
- High-cardinality queries
- Missing rate() on counters
- Fix: Optimize queries, use recording rules

❌ **"Visual Noise"**
- Too many colors without meaning
- Cluttered legends
- Fix: Semantic colors, hide/compact legends

❌ **"Missing Context"**
- No descriptions
- Unclear titles
- Fix: Add helpful descriptions, specific titles

❌ **"Broken Hierarchy"**
- Random panel arrangement
- No logical flow
- Fix: Organize overview → symptoms → root cause

❌ **"Alert Disconnect"**
- Dashboards not linked to alerts
- No runbook references
- Fix: Link panels to alerts and runbooks

## References

- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [The RED Method](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services)
- [The USE Method](http://www.brendangregg.com/usemethod.html)
- [Google SRE Book: Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [PromQL Best Practices](https://prometheus.io/docs/practices/)
