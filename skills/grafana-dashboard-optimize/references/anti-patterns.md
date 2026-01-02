# Common Anti-Patterns

- Metric soup (no narrative or troubleshooting flow)
- Unbounded queries that explode cardinality
- Missing error rate or latency percentiles
- Random panel sizes with no hierarchy
- Vague titles like "Metrics" or "Graph"

## Fixes

- Apply RED/USE systematically
- Aggregate by meaningful labels
- Rebuild layout around overview -> symptoms -> root cause
- Rewrite titles to answer a specific question