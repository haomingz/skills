# Grafana Jsonnet Refactoring Checklist

> Use this checklist to ensure refactored code meets grafana-code standards

## 📋 Phase 1: Code Structure Check

### ✅ Import Order
- [ ] Grafonnet main library comes first
- [ ] Unified libraries imported in alphabetical order
- [ ] Config object defined after imports
- [ ] Variable definitions after config
- [ ] Panel definitions after variables
- [ ] Dashboard construction last

**Correct order example:**
```jsonnet
local g = import '...';
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

local config = { ... };
local var1 = ...;
local panel1 = ...;
g.dashboard.new(...) + ...
```

### ✅ Entrypoint vs Lib Separation
- [ ] Entrypoint file only contains: imports, config, variables, Dashboard definition
- [ ] If panels are few (<5), can define directly in entrypoint
- [ ] If panels are many or have duplicate logic, extract to `lib/<dashboard>_panels.libsonnet`
- [ ] Lib files don't contain Dashboard definition, only panel constructors

**Entrypoint example:**
```jsonnet
// dashboard.jsonnet
local g = import '...';
local panels = import '../lib/panels.libsonnet';
local myPanels = import 'lib/dashboard_panels.libsonnet';

local config = { ... };
local var1 = ...;

g.dashboard.new('My Dashboard')
+ g.dashboard.withPanels([
  myPanels.qpsStat,
  myPanels.errorRatePanel,
])
```

**Lib example:**
```jsonnet
// lib/dashboard_panels.libsonnet
local g = import '...';
local panels = import '../../lib/panels.libsonnet';
local prom = import '../../lib/prometheus.libsonnet';
local standards = import '../../lib/standards.libsonnet';

{
  qpsStat:: panels.statPanel(...),
  errorRatePanel:: panels.timeseriesPanel(...),
}
```

## 📋 Phase 2: Panel Construction Check

### ✅ Use Unified Library Constructors
- [ ] All Stat Panels use `panels.statPanel(...)`
- [ ] All Timeseries Panels use `panels.timeseriesPanel(...)`
- [ ] All Table Panels use `panels.tablePanel(...)`
- [ ] All Rows use `panels.rowPanel(...)`
- [ ] No manually constructed `{ type: 'stat', ... }` structures

**Before refactoring:**
```jsonnet
local qpsStat = {
  type: 'stat',
  title: 'QPS',
  targets: [...],
  fieldConfig: {
    defaults: {
      unit: 'reqps',
      // 大量重复配置...
    },
  },
};
```

**After refactoring:**
```jsonnet
local qpsStat = panels.statPanel(
  title='QPS',
  targets=[...],
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral
);
```

### ✅ Target Construction
- [ ] Use `prom.target()` instead of manual construction
- [ ] Stat Panel uses `prom.instantTarget()`
- [ ] Complex queries use helper functions like `prom.errorRate()`, `prom.successRate()`
- [ ] Percentiles use `prom.p50()`, `prom.p90()`, `prom.p99()`

**Before refactoring:**
```jsonnet
targets=[{
  datasource: { type: 'prometheus', uid: 'xxx' },
  expr: 'sum(rate(...))',
  legendFormat: 'QPS',
  refId: 'A',
}]
```

**After refactoring:**
```jsonnet
targets=[prom.target('sum(rate(...))', 'QPS')]
```

## 📋 Phase 3: Standardized Configuration Check

### ✅ Unit Standardization
- [ ] All hardcoded units replaced with `standards.units.*`
- [ ] QPS uses `standards.units.qps`
- [ ] Error rate uses `standards.units.errorRate` or `standards.units.percent01`
- [ ] Time uses `standards.units.seconds` or `standards.units.milliseconds`
- [ ] Bytes use `standards.units.bytes`

**Refactoring checklist:**
- [ ] `'reqps'` → `standards.units.qps`
- [ ] `'percentunit'` → `standards.units.percent01`
- [ ] `'percent'` → `standards.units.percent100`
- [ ] `'s'` → `standards.units.seconds`
- [ ] `'ms'` → `standards.units.milliseconds`
- [ ] `'bytes'` → `standards.units.bytes`
- [ ] `'short'` → `standards.units.count`

### ✅ Threshold Standardization
- [ ] All hardcoded thresholds replaced with `standards.thresholds.*`
- [ ] Error rate uses `standards.thresholds.errorRate`
- [ ] Success rate uses `standards.thresholds.successRate`
- [ ] Latency uses `standards.thresholds.latencySeconds` or `latencyMilliseconds`
- [ ] No alert meaning uses `standards.thresholds.neutral`

**Check for deletion:**
- [ ] Remove all hardcoded `steps: [...]` threshold definitions
- [ ] Remove all duplicate threshold configurations

### ✅ Legend Configuration
- [ ] Select appropriate Legend configuration based on series count
- [ ] 1-3 series use `standards.legend.detailed`
- [ ] 4-8 series use `standards.legend.standard`
- [ ] 9+ series use `standards.legend.compact`
- [ ] Single series or reference lines use `standards.legend.hidden`

### ✅ Theme Configuration
- [ ] Timeseries panels use `themes.timeseries.*` themes
- [ ] Regular data uses `themes.timeseries.standard`
- [ ] Important metrics use `themes.timeseries.emphasized`
- [ ] Reference lines use `themes.timeseries.light`
- [ ] Bar charts use `themes.timeseries.bars`

## 📋 Phase 4: Layout and GridPos Check

### ✅ GridPos Standardization
- [ ] All panels use `.gridPos.withH/W/X/Y()` to set position
- [ ] Stat panels prefer `layouts.stat.height` and `layouts.stat.width`
- [ ] Timeseries panels prefer `layouts.timeseries.*`
- [ ] Table panels prefer `layouts.table.*`
- [ ] Avoid hardcoded numbers unless there are special size requirements

**Before refactoring:**
```jsonnet
+ g.panel.stat.gridPos.withH(3)
+ g.panel.stat.gridPos.withW(4)
```

**After refactoring:**
```jsonnet
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
```

## 📋 Phase 5: Naming Convention Check

### ✅ Variable Naming
- [ ] All variables use camelCase naming
- [ ] Panel variable names clearly describe their purpose
- [ ] Stat Panels end with `Stat` (e.g. `qpsStat`)
- [ ] Timeseries Panels end with `Panel` (e.g. `qpsPanel`)
- [ ] Table Panels end with `Table` (e.g. `topEndpointsTable`)
- [ ] Rows end with `Row` (e.g. `overviewRow`)
- [ ] Variables end with `Variable` (e.g. `hostnameVariable`)

**Non-compliant:**
- ❌ `qps_stat`
- ❌ `error_rate_panel`
- ❌ `panel1`, `panel2`

**Compliant:**
- ✅ `qpsStat`
- ✅ `errorRatePanel`
- ✅ `latencyP99Panel`

## 📋 Phase 6: Configuration Object Check

### ✅ Config Object
- [ ] Has unified `config` object definition
- [ ] Config contains `datasource` configuration
- [ ] Config contains `timezone`, `timeFrom`, `timeTo`
- [ ] Config contains `pluginVersion: '12.3.0'`
- [ ] Datasource UID uses constant `DATASOURCE_UID`, facilitating switching between provisioning/manual import modes

**Standard config object:**
```jsonnet
local DATASOURCE_UID = 'prometheus-thanos';  // provisioning mode
// local DATASOURCE_UID = '${DS_PROMETHEUS}';  // manual import mode

local config = {
  datasource: {
    type: 'prometheus',
    uid: DATASOURCE_UID,
  },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};
```

### ✅ Selector Extraction
- [ ] Common selectors extracted as constants (e.g. `baseSelector`)
- [ ] Use `helpers.buildSelector()` to build complex selectors
- [ ] Avoid repeating selectors in every query

## 📋 Phase 7: Code Cleanup Check

### ✅ Remove Duplicate Code
- [ ] Remove all duplicate helper function definitions
- [ ] Remove duplicate color constant definitions
- [ ] Remove duplicate unit definitions
- [ ] Remove duplicate threshold definitions
- [ ] Remove unused variables and functions

### ✅ Comment Standards
- [ ] Complex logic has clear comments
- [ ] Remove redundant obvious comments
- [ ] Remove outdated TODO comments
- [ ] Keep important business logic explanations

### ✅ File Organization
- [ ] Remove unused imports
- [ ] Unified library imports in alphabetical order
- [ ] Remove empty lines and extra spaces
- [ ] Use 2-space indentation

## 📋 Phase 8: Compilation and Testing Check

### ✅ Compilation Verification
- [ ] Run `bash build.sh` without errors
- [ ] Generated JSON file size is reasonable (no abnormal increase or decrease)
- [ ] JSON file can be imported normally in Grafana

### ✅ Functional Testing
- [ ] All panels display data normally
- [ ] Variable interactions work normally
- [ ] Refresh function works normally
- [ ] Time range switching works normally
- [ ] Threshold colors display correctly
- [ ] Legend displays normally

### ✅ Performance Check
- [ ] Dashboard load time < 5 seconds
- [ ] No obvious query performance degradation
- [ ] Refresh interval set reasonably (recommended 30s)

## 📋 Phase 9: Documentation and Commit Check

### ✅ Documentation Updates
- [ ] Update dashboard description
- [ ] Update panel descriptions (if any)
- [ ] Update relevant README if there are significant changes

### ✅ Git Commit
- [ ] Commit message is clear (using Conventional Commits format)
- [ ] Commit both `.jsonnet` and `.json` files
- [ ] Check diff to confirm changes meet expectations
- [ ] No sensitive information committed (e.g. real UIDs)

**Commit message example:**
```
refactor(application): migrate nginx dashboard to unified lib

- Use panels.* constructors for all panels
- Standardize units and thresholds
- Extract common selectors
- Reduce code by ~200 lines
```

## 📋 Final Checklist Summary

Before committing, confirm all of the following:

**Code Quality:**
- [ ] All panels use unified library constructors
- [ ] Import order is correct
- [ ] Naming follows camelCase convention
- [ ] No hardcoded units and thresholds
- [ ] No duplicate code

**Functional Completeness:**
- [ ] Compiles without errors
- [ ] All panels display correctly
- [ ] Variable interactions work normally
- [ ] Performance is acceptable

**Documentation and Commit:**
- [ ] Commit message is clear
- [ ] Documentation updated (if needed)
- [ ] Code review passed (if team requires)

## 💡 Refactoring Tips

### Tip 1: Refactor Incrementally
Don't refactor the entire file at once, recommended approach:
1. First refactor 1-2 simple panels
2. Compile and verify
3. Then refactor other panels

### Tip 2: Keep Original File
```bash
cp dashboard.jsonnet dashboard.jsonnet.backup
```

### Tip 3: Use diff Tool
```bash
diff <(jsonnet dashboard.jsonnet.backup) <(jsonnet dashboard.jsonnet) | less
```

### Tip 4: Commit in Batches
If changes are large, commit multiple times:
1. First commit: Import order and naming conventions
2. Second commit: Use unified library constructors
3. Third commit: Standardize units and thresholds
4. Fourth commit: Code cleanup

## References

- [lib-api-reference.md](../../grafana-json-to-jsonnet/references/lib-api-reference.md) - Unified Library API
- [best-practices.md](../../grafana-json-to-jsonnet/references/best-practices.md) - Best Practices
- [common-issues.md](../../grafana-json-to-jsonnet/references/common-issues.md) - Common Issues