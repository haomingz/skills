# Full Optimization Playbook (Observability / SRE)

Use this document for the complete, detailed dashboard optimization workflow. It preserves the full guidance that was removed from the short SKILL.md.

## Contents

- [Purpose](#purpose)
- [Target users](#target-users)
- [Optimization framework](#optimization-framework)
  - [Phase 1: Understanding (required)](#phase-1-understanding-required)
  - [Phase 2: Seven-dimensional optimization](#phase-2-seven-dimensional-optimization)
  - [Phase 3: Delivery format](#phase-3-delivery-format)
- [Quality checklist (full)](#quality-checklist-full)
- [References](#references)

---

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

## Target users

- On-call engineers during incidents
- SRE teams monitoring service health
- DevOps teams tracking infrastructure
- Development teams observing application performance
- Management viewing high-level health metrics

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

Legend guidance:
- Single series: hide legend
- Small series count: standard legend
- Large series count: compact or table legend

#### Dimension 5: Layout and organization

Audit questions:
- Does layout follow a troubleshooting flow?
- Is there a clear visual hierarchy?

Recommended flow:
- Overview -> Symptoms -> Root cause
- Left-to-right importance within rows
- Use collapsed rows for deep-dive sections

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
- `references/visualization-guidelines.md`
- `references/layout-guidelines.md`
- `references/optimization-checklist.md`
- `references/report-template.md`
- `references/anti-patterns.md`
