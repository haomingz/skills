# Common Issues and Solutions

> This document summarizes common issues and solutions when using grafana-code unified libraries

## Contents
- Compilation Errors
- Runtime Issues
- Data Display Issues
- Performance Issues
- Best Practice Recommendations
- Debugging Tips
- Getting Help

## Compilation Errors

### Q1: Field does not exist: percent

**Error Message:**
```
RUNTIME ERROR: Field does not exist: percent
	standards.units.percent
```

**Cause:**
`standards.units` doesn't have a `percent` field.

**Solution:**
Choose the correct unit based on data range:
```jsonnet
// ❌ Wrong
unit=standards.units.percent

// ✅ Correct: 0-100 range percentage
unit=standards.units.percent100

// ✅ Correct: 0-1 range percentage (e.g. error rate)
unit=standards.units.percent01
```

---

### Q2: Field does not exist: rich

**Error Message:**
```
RUNTIME ERROR: Field does not exist: rich
	standards.legend.rich
```

**Cause:**
`standards.legend` doesn't have a `rich` configuration.

**Solution:**
Use standard Legend configurations:
```jsonnet
// ❌ Wrong
legendConfig=standards.legend.rich

// ✅ Correct: choose based on series count
legendConfig=standards.legend.standard   // 4-8 series
legendConfig=standards.legend.compact    // 9+ series
legendConfig=standards.legend.detailed   // 1-3 series
legendConfig=standards.legend.hidden     // Hide Legend
```

---

### Q3: max stack frames exceeded

**Error Message:**
```
RUNTIME ERROR: max stack frames exceeded
```

**Cause:**
Using `self.expr` causes infinite recursion. In Jsonnet:
- `self` references current object (creates circular reference)
- `super` references parent object (correct way to extend)

**Solution:**
```jsonnet
// ❌ Wrong: causes infinite recursion
prom.p50(...) { expr: self.expr + ' * 1000' }

// ✅ Correct: use + operator and super keyword
prom.p50(...) + { expr: super.expr + ' * 1000' }
```

---

### Q4: Field does not exist: bytesPerSecond

**Error Message:**
```
RUNTIME ERROR: Field does not exist: bytesPerSecond
	standards.units.bytesPerSecond
```

**Cause:**
Incorrect unit name.

**Solution:**
```jsonnet
// ❌ Wrong
unit=standards.units.bytesPerSecond

// ✅ Correct
unit=standards.units.Bps   // Bytes per second

// Other bandwidth units:
unit=standards.units.bps   // bits per second
unit=standards.units.Kbps  // Kilobits per second
unit=standards.units.Mbps  // Megabits per second
unit=standards.units.Gbps  // Gigabits per second
```

---

### Q5: Field does not exist: calcs

**Error Message:**
```
RUNTIME ERROR: Field does not exist: calcs
	standards.legend.hidden.calcs
```

**Cause:**
When using `standards.legend.hidden`, you shouldn't manually access the calcs field. `panels.libsonnet` already handles this.

**Solution:**
```jsonnet
// ✅ Correct: use hidden directly
local panel = panels.timeseriesPanel(
  ...,
  legendConfig=standards.legend.hidden
);

// ❌ Wrong: don't manually access calcs
legendConfig=standards.legend.hidden.calcs  // Wrong
```

---

### Q6: undefined variable: config

**Error Message:**
```
RUNTIME ERROR: undefined variable: config
```

**Cause:**
config object not defined, but referenced in code.

**Solution:**
Define config object at the beginning of file:
```jsonnet
local config = {
  datasource: {
    type: 'prometheus',
    uid: 'prometheus-thanos',
  },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};
```

---

## Runtime Issues

### Q7: Panel colors not displaying correctly

**Issue:**
Timeseries panel uses thresholds, but colors aren't working.

**Cause:**
Color mode not set.

**Solution:**
```jsonnet
// panels.libsonnet already handles this
// But if manually constructing panel, need:
+ g.panel.timeSeries.fieldConfig.defaults.color.withMode('palette-classic')
```

---

### Q8: Legend not displaying completely

**Issue:**
Legend shows incomplete values, only showing the last value.

**Cause:**
Using wrong Legend configuration (like compact) with few series.

**Solution:**
Choose appropriate configuration based on series count:
```jsonnet
// 1-3 series → detailed (shows lastNotNull, max, mean, sum)
legendConfig=standards.legend.detailed

// 4-8 series → standard (shows lastNotNull, max, mean)
legendConfig=standards.legend.standard

// 9+ series → compact (shows lastNotNull only)
legendConfig=standards.legend.compact
```

---

### Q9: Variable not showing All option

**Issue:**
Variable configured with `withIncludeAll(true)`, but no All option in UI.

**Cause:**
Missing `allValue` configuration.

**Solution:**
```jsonnet
local variable = g.dashboard.variable.query.new(...)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ {
  allValue: '.*',  // Must set
  current: { selected: true, text: 'All', value: '$__all' },
};
```

---

## Data Display Issues

### Q10: Stat Panel showing "No data"

**Issue:**
Stat panel shows "No data", but Timeseries panel has data.

**Cause:**
Stat panel needs to use `prom.instantTarget()` instead of `prom.target()`.

**Solution:**
```jsonnet
// ❌ Wrong: Stat Panel using target()
targets=[prom.target('sum(rate(...))', '')]

// ✅ Correct: Stat Panel using instantTarget()
targets=[prom.instantTarget('sum(rate(...))', '')]
```

---

### Q11: Percentile query returning empty results

**Issue:**
Using `prom.p50()` etc. to query histogram metrics returns empty results.

**Cause:**
Metric is not histogram type, or bucket label name is incorrect.

**Solution:**
```jsonnet
// Ensure metric is histogram type
// Query example: http_request_duration_bucket

// If bucket label is not "le", need to manually construct:
prom.target(
  'histogram_quantile(0.50, sum(rate(http_request_duration_bucket[1m])) by (le))',
  'P50'
)
```

---

### Q12: Error Rate showing negative numbers

**Issue:**
Error rate displays as negative or abnormally large values.

**Cause:**
Numerator and denominator using different time ranges or selectors.

**Solution:**
```jsonnet
// ✅ Recommended: use prom.errorRate()
targets=[prom.errorRate(
  'http_requests_total',
  '{job="api"}',
  'status',
  'Error Rate'
)]

// ✅ Or manually construct, ensuring numerator and denominator match
prom.target(
  |||
    sum(rate(http_requests_total{job="api",status=~"[45].."}[1m]))
    /
    sum(rate(http_requests_total{job="api"}[1m]))
  |||,
  'Error Rate'
)
```

---

## Performance Issues

### Q13: Dashboard loading slowly

**Issue:**
Dashboard has many panels, loading time exceeds 10 seconds.

**Cause:**
- Queries too complex
- Too many panels
- Time range too large

**Solution:**
1. **Optimize queries:**
```jsonnet
// ❌ Avoid: complex nested queries
'sum(rate(metric1[1m])) / sum(rate(metric2[1m])) * 100'

// ✅ Recommended: use recording rules for pre-calculation
'error_rate_percent'
```

2. **Use collapsed Rows:**
```jsonnet
// Put infrequently used panels in collapsed Row
local detailsRow = panels.rowPanel('Detailed Data', collapsed=true)
+ g.panel.row.withPanels([panel1, panel2, panel3]);
```

3. **Reduce default time range:**
```jsonnet
// ❌ Avoid: excessive time range
timeFrom: 'now-30d'

// ✅ Recommended: reasonable default time range
timeFrom: 'now-6h'
```

---

### Q14: High Grafana CPU usage

**Issue:**
After opening Dashboard, Grafana backend CPU usage is very high.

**Cause:**
- Queries returning too many data points
- Refresh interval too short

**Solution:**
1. **Use appropriate interval:**
```jsonnet
// ✅ Use $__rate_interval (auto-calculated)
prom.rateQuery(
  metric='http_requests_total',
  selector='{job="api"}',
  legendFormat='{{method}}'
)

// Or manually specify minimum interval
+ g.panel.timeSeries.queryOptions.withMinInterval('30s')
```

2. **Increase refresh interval:**
```jsonnet
// ❌ Avoid: too short refresh interval
+ g.dashboard.withRefresh('5s')

// ✅ Recommended: reasonable refresh interval
+ g.dashboard.withRefresh('30s')
```

---

## Best Practice Recommendations

### Recommendation 1: Test queries in Grafana UI first

Before writing Jsonnet, test PromQL queries in Grafana Explore to ensure they're correct.

### Recommendation 2: Use jsonnet fmt to format code

```bash
# Format code
jsonnet fmt -i dashboard.jsonnet

# Or auto-format in build.sh
jsonnet fmt -i mixin/**/*.jsonnet
```

### Recommendation 3: Migrate incrementally, don't refactor all at once

Start migrating simple panels to unified library, verify correctness, then migrate complex panels.

### Recommendation 4: Keep original JSON as backup

When converting JSON to Jsonnet, keep original JSON file as reference:
```bash
# Backup original file
cp dashboard.json dashboard.json.backup
```

### Recommendation 5: Use version control

Commit both Jsonnet source files and generated JSON files to Git for easy change tracking and rollback.

---

## Debugging Tips

### Tip 1: View generated JSON during compilation

```bash
# Compile and view output
jsonnet -J vendor dashboard.jsonnet | jq .

# View only specific fields
jsonnet -J vendor dashboard.jsonnet | jq '.panels[0]'
```

### Tip 2: Use std.trace for debugging

```jsonnet
// Print debug information in Jsonnet
local selector = std.trace('Selector: ' + baseSelector, baseSelector);
```

### Tip 3: Verify step by step

Verify config object first, then variables, finally panels:
```bash
# Only compile config section
jsonnet -J vendor -e '(import "dashboard.jsonnet").config'

# Only compile variables section
jsonnet -J vendor -e '(import "dashboard.jsonnet").variables'
```

---

## Getting Help

If encountering issues not covered in this document:

1. **Check official documentation:**
   - [Grafonnet Documentation](https://grafana.github.io/grafonnet/)
   - [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)

2. **Check grafana-code repository:**
   - `lib/README.md` - Complete library documentation
   - `JSONNET_BEST_PRACTICES.md` - Best practices
   - `lib/MIGRATION_LESSONS.md` - Migration lessons

3. **Check existing examples:**
   - `application/nginx_log_metrics_dashboard.jsonnet` - Complete example
   - `application/ingress_nginx_dashboard.jsonnet` - SLI metrics example
