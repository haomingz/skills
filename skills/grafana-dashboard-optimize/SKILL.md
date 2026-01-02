---
name: grafana-dashboard-optimize
description: Optimize Grafana Jsonnet dashboard content for observability/SRE (RED/USE/Golden Signals). Use for content audits and improvements, not code refactoring.
---

# Grafana Dashboard Content Optimization (Observability / SRE)

## Inputs

- Path to an existing Grafana Jsonnet dashboard
- Optional: dashboard purpose and target audience
- Optional: known pain points or problem statements

## Outputs

- Assessment report with prioritized recommendations
- Jsonnet snippets for critical improvements
- Updated dashboard file if requested

## Workflow

1. Understand the dashboard context
   - Identify purpose, audience, and monitoring strategy
   - List datasources, variables, time range, and rows
2. Run a content audit
   - Panel semantics, queries, variables, visualization, layout, titles
3. Produce recommendations
   - Classify as Critical, Recommended, Optional
   - Include rationale and expected impact
4. Apply changes (if requested)
   - Use unified libraries from `mixin/lib/` (`panels`, `standards`, `themes`, `layouts`)
   - Keep structure changes minimal (no refactor)
5. Validate
   - Re-check queries, units, thresholds, legends, and row flow

## Guardrails

- Do not refactor code structure; use `grafana-jsonnet-refactor` for that.
- Avoid broad rewrites; focus on content quality and observability value.
- Keep any added guidance in `references/` instead of bloating this file.

## Quick Checklist

- RED/USE/Golden Signals coverage is complete
- Queries are efficient and bounded
- Units and thresholds use `standards.*`
- Panel titles and descriptions are specific
- Layout follows overview -> symptoms -> root cause

## References (load as needed)

- `references/observability-strategies.md` for RED/USE/Golden Signals
- `references/query-optimization.md` for PromQL/SQL guidance
- `references/visualization-guidelines.md` for panel selection, units, legends
- `references/layout-guidelines.md` for row and grid patterns
- `references/optimization-checklist.md` for detailed audit checklist
- `references/report-template.md` for the assessment report format
- `references/anti-patterns.md` for common pitfalls