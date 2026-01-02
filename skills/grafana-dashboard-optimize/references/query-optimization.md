# Query Optimization

## PromQL Patterns

- Counter metrics should use `rate()` or `increase()`
- Prefer bounded label filters and sensible aggregation

Examples:

```promql
# Bad: counter without rate
http_requests_total

# Good: rate + aggregation
sum(rate(http_requests_total[5m]))

# Bad: high-cardinality series explosion
rate(http_requests_total[5m])

# Good: aggregate by service only
sum by (service) (rate(http_requests_total[5m]))

# Bad: missing range vector
avg_over_time(cpu_usage)

# Good: bounded range
avg_over_time(cpu_usage[5m])
```

## Checklist

- Use `rate()` for counters, `avg_over_time()` for gauges
- Use `sum by (...)` or `sum without (...)` intentionally
- Avoid regex or unbounded queries without filters
- Use recording rules for expensive queries

## ClickHouse / Elasticsearch

- Always filter by time range
- Limit bucket sizes and top-N results
- Prefer pre-aggregated tables or materialized views for heavy panels