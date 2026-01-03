---
name: grafana-dashboard-optimize
description: Optimizes Grafana Jsonnet dashboard content for observability and SRE best practices (RED/USE/Golden Signals). Use when auditing dashboard quality, improving monitoring effectiveness, enhancing diagnostic capabilities, or reviewing observability coverage. Focuses on content-level improvements without code structure refactoring.
---

# Grafana Dashboard Content Optimization (Observability / SRE)

## When to use this skill

This skill is most effective when:
- Reviewing dashboard content quality and observability coverage
- Improving diagnostic value and reducing cognitive load for on-call teams
- Optimizing queries, metrics usage, and visualization effectiveness
- Applying RED/USE/Golden Signals methodology to existing dashboards
- Auditing panel semantics, layout flow, and troubleshooting effectiveness

Not suitable for:
- Code structure refactoring or lib abstraction (use `grafana-jsonnet-refactor`)
- Initial JSON to Jsonnet conversion (use `grafana-json-to-jsonnet`)
- Code style formatting or file organization

## Purpose

What this skill does:
- Improve usability for on-call and SRE audiences
- Increase diagnostic value and reduce cognitive load
- Optimize queries and metric usage
- Apply RED / USE / Golden Signals best practices

What this skill does not do:
- Code structure refactoring (use `grafana-jsonnet-refactor`)
- Lib abstraction or file organization
- Code style formatting

## Target users

- On-call engineers and SRE teams
- DevOps and infrastructure teams
- Application development teams
- Management dashboards for high-level health

## Inputs

- Path to an existing Grafana Jsonnet dashboard
- Optional: dashboard purpose, audience, and key questions
- Optional: known pain points or reliability goals

## Outputs

- Assessment report with prioritized recommendations (Critical / Recommended / Optional)
- Jsonnet snippets for high-impact changes
- Updated dashboard file if requested

## Workflow

1. Understand context
   - Identify purpose, audience, and monitoring strategy
   - List datasources, variables, time range, and rows
2. Run a content audit
   - Panel semantics, queries, variables, visualization, layout, titles
3. Produce recommendations
   - Classify as Critical / Recommended / Optional
   - Include rationale and expected impact
4. Apply changes (if requested)
   - Use unified libraries from `mixin/lib/` (`panels`, `standards`, `themes`, `layouts`)
   - Keep structure changes minimal (no refactor)
5. Validate
   - Re-check queries, units, thresholds, legends, and row flow

## Guardrails

- Do not refactor code structure; use `grafana-jsonnet-refactor` for that.
- Avoid broad rewrites; focus on content quality and observability value.
- Keep deep guidance in `references/` instead of bloating this file.

## Optimization framework (summary)

- Phase 1: Understanding (required) - document purpose, audience, layout, and data flow before any edits.
- Phase 2: Seven-dimensional audit - semantics, queries, variables, visualization, layout, titles, proactive additions.
- Phase 3: Delivery - produce a structured assessment report with prioritized actions.

## Seven core dimensions (summary)

- Panel semantics and structure (missing/duplicated views, diagnostic coverage)
- Query optimization and metric usage (rate/increase, aggregation, cardinality)
- Variable design (names, defaults, cascading relationships)
- Visualization and visual expression (panel type, units, thresholds, legends)
- Layout and organization (overview -> symptoms -> root cause)
- Titles and descriptions (clarity, context, troubleshooting hints)
- Proactive additions (SLO/SLI, annotations, comparisons, runbooks)

## Output format (recommended)

- Overview: dashboard purpose and audience
- Findings (Critical / Recommended / Optional)
- Suggested changes with snippets
- Expected impact and validation steps

## Quick checklist

- RED/USE/Golden Signals coverage is complete
- Queries are efficient and bounded
- Units and thresholds use `standards.*`
- Panel titles and descriptions are specific
- Layout follows overview -> symptoms -> root cause

## References (load as needed)

- `references/full-optimization-playbook.md` for the complete framework
- `references/observability-strategies.md` for RED/USE/Golden Signals
- `references/query-optimization.md` for PromQL/SQL guidance
- `references/visualization-guidelines.md` for panel selection, units, legends
- `references/layout-guidelines.md` for row and grid patterns
- `references/optimization-checklist.md` for detailed audit checklist
- `references/report-template.md` for the assessment report format
- `references/anti-patterns.md` for common pitfalls
