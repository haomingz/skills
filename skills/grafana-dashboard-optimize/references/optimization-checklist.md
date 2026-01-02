# Optimization Checklist

## Dashboard Level

- Title clearly states purpose
- Tags and default time range are set
- Refresh interval is sensible

## Panel Level

- Title is specific and includes units
- Description explains context and thresholds
- Units and thresholds use `standards.*`
- Legend is optimized for series count

## Query Level

- Counters use `rate()`
- Queries are bounded by labels
- Aggregations are intentional

## Observability Coverage

- RED or USE is present where appropriate
- Error rate and latency percentiles are visible
- Saturation metrics exist for resources