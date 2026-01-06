---
name: grafana-dashboard-optimize
description: Optimizes Grafana Jsonnet dashboard content for observability and SRE best practices (RED/USE/Golden Signals). Use when auditing dashboard quality, improving monitoring effectiveness, enhancing diagnostic capabilities, or reviewing observability coverage. Focuses on content-level improvements without code structure refactoring.
---

# Grafana Dashboard Content Optimization (Observability / SRE)

Audit and optimize dashboard content for observability best practices. Apply RED/USE/Golden Signals methodology, improve diagnostic value, and reduce cognitive load for on-call teams.

**Not suitable for**: Code structure refactoring (use `grafana-jsonnet-refactor`), initial JSON conversion (use `grafana-json-to-jsonnet`), or code style formatting.

## Workflow with progress tracking

Copy this checklist and track your progress:

```
Optimization Progress:
- [ ] Step 1: Understand context (purpose, audience, strategy)
- [ ] Step 2: Run seven-dimensional content audit
- [ ] Step 3: Produce prioritized recommendations report
- [ ] Step 4: Apply changes (if requested)
- [ ] Step 5: Validate improvements
```

**Step 1: Understand context**

Before any edits, document:
- Dashboard purpose and target audience (SRE/on-call/management)
- Current monitoring strategy and key questions it should answer
- Datasources, variables, time range settings
- Row structure and panel organization

See `references/full-optimization-playbook.md` for detailed context gathering.

**Step 2: Run seven-dimensional content audit**

Audit across these dimensions:
1. **Panel semantics**: Missing/duplicated views, diagnostic coverage
2. **Query optimization**: rate/increase usage, aggregation, cardinality
3. **Variable design**: Names, defaults, cascading relationships
4. **Visualization**: Panel types, units, thresholds, legends, table field pruning
5. **Layout**: Overview → symptoms → root cause flow
6. **Titles/descriptions**: Unified title style, clarity, context, troubleshooting hints, every panel has a description
7. **Proactive additions**: SLO/SLI, annotations, comparisons, runbooks

For the full audit checklist and visualization/layout guidance, see `references/full-optimization-playbook.md`.
For observability strategies (RED/USE/Golden Signals), see `references/observability-strategies.md`.

**Step 3: Produce prioritized recommendations**

Create structured assessment report with:
- **Critical**: Missing essential metrics, broken queries, misleading visualizations
- **Recommended**: Important improvements with clear ROI
- **Optional**: Nice-to-have enhancements

Include rationale and expected impact for each recommendation. Use template in `references/report-template.md`.

**Step 4: Apply changes (if requested)**

If user approves changes:
- Use unified libraries from `mixin/lib/` (`panels`, `standards`, `themes`)
- Keep code structure changes minimal (content-only optimization)
- Include Jsonnet snippets for high-impact changes
- Match grafana-code mixin structure (imports → config → constants → helpers → panels → rows → variables → dashboard)
- For **table** panels, use the `panels` lib (no raw Grafonnet) and follow the detailed table guidance in `references/full-optimization-playbook.md`.

For query optimization patterns, see `references/query-optimization.md`.

**Step 5: Validate improvements**

Re-check:
- Queries are efficient and bounded
- Units and thresholds use `standards.*`
- Panel titles are consistent in style and descriptions are present
- Layout follows diagnostic flow
- RED/USE/Golden Signals coverage is complete
- Table panels remove unused fields and apply table optimization guidance (overrides/thresholds, colors, widths, cell types)
- Variables return values in Grafana (non-empty dropdowns)
- No duplicate or extra variables after cleanup
- Regex filters preserved or added where needed for variable values
- Row membership is correct (panels align to row `gridPos.y` and rows include panels)

## Quick optimization checklist

- [ ] RED/USE/Golden Signals coverage is complete
- [ ] Queries are efficient and bounded
- [ ] Units and thresholds use `standards.*`
- [ ] Panel titles are consistent and descriptions exist for every panel
- [ ] Layout follows overview → symptoms → root cause
- [ ] Table panels remove unused fields and apply table optimization guidance (overrides/thresholds, colors, widths, cell types)
- [ ] Variables return values and have no duplicates/extras
- [ ] Regex filters preserved or added when needed
- [ ] Row membership is correct

## Assessment report format

Use this structure for recommendations:

```markdown
# Dashboard Optimization Assessment

## Overview
- Purpose: [what this dashboard monitors]
- Audience: [SRE/on-call/management]
- Current state: [summary]

## Critical Issues
1. [Issue with rationale and impact]
2. [Issue with rationale and impact]

## Recommended Improvements
1. [Improvement with expected benefit]
2. [Improvement with expected benefit]

## Optional Enhancements
1. [Enhancement idea]
2. [Enhancement idea]

## Implementation Priority
- Week 1: Critical issues
- Week 2: Recommended improvements
- Week 3+: Optional enhancements
```

## Guardrails

- Do not refactor code structure; use `grafana-jsonnet-refactor` for that.
- Avoid broad rewrites; focus on content quality and observability value.
- Keep deep guidance in `references/` instead of bloating this file.
- Do not run `jsonnetfmt` / `jsonnet fmt` on generated Jsonnet files.

## References (load as needed)

- `references/full-optimization-playbook.md` for the complete framework
- `references/observability-strategies.md` for RED/USE/Golden Signals
- `references/query-optimization.md` for PromQL/SQL guidance
- `references/report-template.md` for the assessment report format
