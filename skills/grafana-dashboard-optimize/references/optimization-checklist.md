# Optimization Checklist

## Dashboard Level

- Title clearly states purpose
- Tags and default time range are set
- Refresh interval is sensible

## Panel Level

- Title is specific and includes units
- Title style is consistent across panels (prefixes/units/emoji rules)
- Description explains context and thresholds (every panel has one)
- Units and thresholds use `standards.*`
- Legend is optimized for series count

## Table Panels

- Remove unused or redundant fields (IDs, raw labels, duplicate columns)
- Apply unit/threshold overrides to key columns
- Set column widths and sort order for scanability

## Query Level

- Counters use `rate()`
- Queries are bounded by labels
- Aggregations are intentional

## Observability Coverage

- RED or USE is present where appropriate
- Error rate and latency percentiles are visible
- Saturation metrics exist for resources
