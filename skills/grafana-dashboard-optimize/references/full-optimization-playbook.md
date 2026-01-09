# Full Optimization Playbook (Observability / SRE)

Use this document for the complete, detailed dashboard optimization workflow. It preserves the full guidance that was removed from the short SKILL.md.

## Contents

- [Reference index (load as needed)](#reference-index-load-as-needed)
- [Purpose](#purpose)
- [Target users](#target-users)
- [Common anti-patterns](#common-anti-patterns)
- [Optimization framework](#optimization-framework)
  - [Phase 1: Understanding (required)](#phase-1-understanding-required)
  - [Phase 2: Seven-dimensional optimization](#phase-2-seven-dimensional-optimization)
  - [Phase 3: Delivery format](#phase-3-delivery-format)
- [Quality checklist (full)](#quality-checklist-full)
- [References](#references)

---

## Reference index (load as needed)

- `references/observability-strategies.md` - RED/USE/Golden Signals selection guidance.
- `references/query-optimization.md` - PromQL/SQL patterns and performance tips.
- `references/report-template.md` - assessment report output template.
- `references/visual-style-guides.md` - color/threshold/style/table conventions.

## Purpose

This skill optimizes the content and observability quality of existing Grafana Jsonnet dashboards.

What this skill does:
- Improve usability for on-call and SRE audiences
- Increase diagnostic value and reduce cognitive load
- Improve query efficiency and metric usage
- Apply RED / USE / Golden Signals best practices
- Improve visual clarity and panel selection

What this skill does not do:
- Code structure refactoring (use `grafana-jsonnet-refactor`)
- Lib abstraction or file organization
- Code style formatting
- Automated formatting via `jsonnetfmt`

If applying Jsonnet edits, keep the existing file structure and align with grafana-code mixin style (unified libs, config object, row structure).

## Target users

- On-call engineers during incidents
- SRE teams monitoring service health
- DevOps teams tracking infrastructure
- Development teams observing application performance
- Management viewing high-level health metrics

## Common anti-patterns

- Metric soup (no narrative or troubleshooting flow)
- Unbounded queries that explode cardinality
- Missing error rate or latency percentiles
- Random panel sizes with no hierarchy
- Vague titles like "Metrics" or "Graph"

Fixes:
- Apply RED/USE systematically
- Aggregate by meaningful labels
- Rebuild layout around overview -> symptoms -> root cause
- Rewrite titles to answer a specific question

## Optimization framework

### Phase 1: Understanding (required)

Before making changes, document the following:

1) Dashboard purpose
- What is this dashboard monitoring (service, infra, business metrics)?
- Who is the primary audience?
- What questions should this dashboard answer?
- What monitoring strategy does it follow (RED, USE, Golden Signals, custom)?

2) Current state
- Panel count, row structure, and layout
- Datasources used
- Default time range and refresh interval
- Existing variables and interactions

3) Semantic understanding
- What does each row represent in the troubleshooting flow?
- What is each panel trying to show?
- How do panels relate to each other?

Document your understanding before proceeding to optimization.

### Phase 2: Seven-dimensional optimization

#### Dimension 1: Panel semantics and structure

Audit questions:
- Does every panel have a clear purpose?
- Are there redundant panels?
- Are critical observability views missing?
- Is information density appropriate?

Common issues:
- Generic titles like "Metrics" or "Panel 1"
- Duplicate information across multiple panels
- Missing error rate, latency percentiles, or saturation

Optimization actions:
- Merge panels with similar intent
- Split panels that show too much
- Remove panels that do not add diagnostic value
- Add missing observability perspectives

Example (RED method):

```jsonnet
// R - Rate
local requestRatePanel = panels.timeseriesPanel(
  title='Request Rate (requests/sec)',
  description='Total incoming request rate.',
  targets=[
    prom.target('sum(rate(http_requests_total{job="api"}[5m]))', 'Total RPS'),
  ],
  unit=standards.units.qps,
);

// E - Errors
local errorRatePanel = panels.timeseriesPanel(
  title='Error Rate (%)',
  description='Percentage of requests returning 5xx errors.',
  targets=[
    prom.errorRate('http_requests_total', '{job="api"}', 'status', 'Error Rate'),
  ],
  unit=standards.units.errorRate,
  thresholds=standards.thresholds.errorRate,
);

// D - Duration
local latencyPanel = panels.timeseriesPanel(
  title='Request Latency (p50, p90, p99)',
  description='Latency distribution. Watch for p99 spikes.',
  targets=[
    prom.p50('http_request_duration_seconds', '{job="api"}', 'p50'),
    prom.p90('http_request_duration_seconds', '{job="api"}', 'p90'),
    prom.p99('http_request_duration_seconds', '{job="api"}', 'p99'),
  ],
  unit=standards.units.seconds,
);
```

#### Dimension 2: Query optimization and metric usage

Audit questions:
- Are queries efficient and correct?
- Are aggregations appropriate?
- Are there high-cardinality labels?
- Should any queries use recording rules?

Common issues:
- Missing `rate()` for counters
- High-cardinality labels (instance, pod) without aggregation
- Unbounded queries without label filters

Examples:

```jsonnet
// Bad: raw counter
'http_requests_total'

// Good: rate()
'sum(rate(http_requests_total[5m]))'

// Bad: high-cardinality without aggregation
'rate(http_requests_total[5m])'

// Good: aggregate by service
'sum by (service) (rate(http_requests_total[5m]))'
```

Checklist:
- Use `rate()` or `increase()` for counters
- Use reasonable range vectors based on scrape interval
- Aggregate by meaningful labels only
- Prefer recording rules for expensive calculations

#### Dimension 3: Variables (template variables)

Audit questions:
- Are variable names clear and meaningful?
- Are defaults sensible?
- Are cascading relationships correct?
- Do variable dropdowns return values in Grafana?
- Are there duplicate or unused variables?
- Do variable values need regex filtering to remove noise?

Example:

```jsonnet
local environmentVariable = g.dashboard.variable.query.new(
  'environment',
  'label_values(up{service="api"}, environment)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(false)
+ g.dashboard.variable.query.selectionOptions.withMulti(false)
+ g.dashboard.variable.query.refresh.onLoad()
+ { current: { text: 'production', value: 'production' } };
```

Validation checklist (variables):
- Verify each variable dropdown returns values in Grafana.
- Remove duplicate or unused variables.
- Add or preserve `regex` filters for high-cardinality or noisy labels.

#### Dimension 4: Visualization and visual expression

Audit questions:
- Is panel type appropriate for the data?
- Are units and precision correct?
- Are legends helpful or noisy?

Examples:

```jsonnet
// Stat for single value
local currentErrorRate = panels.statPanel(
  title='Current Error Rate',
  targets=[...],
  unit=standards.units.errorRate,
  thresholds=standards.thresholds.errorRate,
);

// Timeseries for trends
local errorRateTrend = panels.timeseriesPanel(
  title='Error Rate Over Time',
  targets=[...],
  unit=standards.units.errorRate,
  theme=themes.timeseries.standard,
);
```

Panel type selection:
- Stat: single current value
- Timeseries: trend over time
- Table: top-N or breakdowns
- Bar gauge: comparisons across categories
- Heatmap: distributions

Legend guidance:
- Single series: hide legend
- Small series count: standard legend
- Large series count: compact or table legend

Table panels (required):
- Use the `panels` library for table panel creation and field overrides (avoid raw Grafonnet or inline JSON).
- Color + thresholds: configure thresholds for key numeric/status fields and bind colors explicitly (e.g., green/yellow/red) so status and risk stand out.
- Column widths: set widths or min widths for high-signal columns; allow low-signal columns to auto-size or be hidden.
- Cell types by data type:
  - Timestamp/time: time cell type and appropriate time format.
  - Duration/latency: numeric with time unit (`ms`, `s`) and thresholds.
  - Percent/ratio: percent cell type with thresholds.
  - Counts/metrics: numeric with unit and thresholds when meaningful.
  - Boolean: boolean or pill cell type.
  - Enum/status strings: pill or colored text cell type with thresholds.
  - Free text: plain string; avoid coloring unless it encodes status.
- Default hidden fields: rely on the panels lib defaults and verify they are applied; override in the lib only when required.
- Extra improvements: consider default sort on the most critical column, reduce row limit for readability, and remove fields that are never used in troubleshooting.

#### Dimension 5: Layout and organization

Audit questions:
- Does layout follow a troubleshooting flow?
- Is there a clear visual hierarchy?

Recommended flow:
- Overview -> Symptoms -> Root cause
- Left-to-right importance within rows
- Use collapsed rows for deep-dive sections

Row usage:
- Use `panels.rowPanel` and collapse detailed sections.
- Keep overview row visible by default.

Grid tips:
- Use consistent widths (6, 8, 12, 24).
- Put critical metrics top-left.

Row membership checks:
- Panels align to their row `gridPos.y`.
- Row panels include the expected child panels.

#### Dimension 6: Titles and descriptions

Audit questions:
- Do titles answer a specific question?
- Are descriptions useful and actionable?

Example:

```jsonnet
local apiErrorRatePanel = panels.timeseriesPanel(
  title='API Error Rate (5xx %)',
  description=|||
Percentage of API requests returning 5xx errors.
Normal: <0.1%, Warning: 0.1-1%, Critical: >1%.
|||,
  targets=[...],
);
```

#### Dimension 7: Proactive additions

Consider:
- SLO/SLI tracking panels
- Runbook links in descriptions
- Annotations for deployments or incidents
- Time-shifted comparisons (current vs last week)

## Delivery format

Use this report structure:

```markdown
# Dashboard Optimization Assessment: <Dashboard Name>

## Executive Summary
- Purpose
- Audience
- Overall quality score
- Critical recommendations

## Understanding Analysis
- Purpose, audience, and monitoring strategy

## Findings by Dimension
1. Panel semantics and structure
2. Query optimization
3. Variables
4. Visualization
5. Layout
6. Titles and descriptions
7. Additional optimizations

## Priority Matrix
- Critical
- Recommended
- Optional

## Code Examples
- Snippets for key changes

## Next Steps
- Ordered implementation plan
```

## Quality checklist (full)

Dashboard level:
- Clear title and tags
- Appropriate default time range and refresh
- Variables for key dimensions
- Annotations for deployments/incidents

Row level:
- Logical grouping and ordering
- Meaningful row titles
- Collapsed rows for details

Panel level:
- Specific, question-oriented titles
- Helpful descriptions
- Correct panel type and units
- Meaningful thresholds
- Legend tuned for series count
- Table panels remove unused fields and apply overrides (thresholds, colors, widths, cell types)

Query level:
- Efficient queries and aggregations
- Correct rate/increase usage
- No unbounded cardinality

Observability level:
- Follows RED/USE/Golden Signals
- Enables a troubleshooting flow

## References

Use these for deeper guidance:
- `references/observability-strategies.md`
- `references/query-optimization.md`
- `references/report-template.md`
