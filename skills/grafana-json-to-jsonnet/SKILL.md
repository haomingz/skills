---
name: grafana-json-to-jsonnet
description: This skill should be used when converting Grafana dashboard JSON exports to Jsonnet that matches the grafana-code mixin style. Trigger phrases include "convert grafana json", "grafana export to jsonnet", "import grafana dashboard", "grafana-code integration", "json to jsonnet". Use when the user provides a Grafana export JSON file and asks to integrate it into grafana-code. CRITICAL REQUIREMENTS: (1) Always fully convert to Jsonnet using unified lib libraries - never use raw JSON fallback files. (2) Generate a single self-contained jsonnet file - do NOT create dashboard-specific lib files. (3) Use latest Grafana features and plugins, modernize legacy configurations. (4) Only update general lib libraries (../lib/) if adding truly reusable components.
---

# Grafana JSON Export to Jsonnet

## Inputs
- Grafana export JSON file (from Grafana UI: Share -> Export)
- Target mixin system folder (for example `mixin/application`)
- Datasource type and UID (for example `prometheus` + `prometheus-thanos`)

## Outputs
- `<output>/<dashboard>.jsonnet` (single self-contained dashboard file)
- Optionally: Updates to `../lib/*.libsonnet` (only if adding truly reusable components to the general library)

## Steps

### Step 1: Understand grafana-code conventions
Review the following reference documents to understand the code conventions:
- `references/best-practices.md` - Code organization and naming conventions
- `references/lib-api-reference.md` - Unified library API quick reference
- `references/style-guide.md` - grafana-code style guide

### Step 2: Analyze the JSON export and plan conversion

**CRITICAL REQUIREMENTS:**
1. All panels, variables, and configurations MUST be converted to Jsonnet using unified library constructors
2. Generate a **single self-contained jsonnet file** - do NOT create `lib/<dashboard>_panels.libsonnet` or similar dashboard-specific lib files
3. All panel definitions should be written directly in the main jsonnet file as `local` variables
4. Use latest Grafana features and modernize legacy configurations

**Modernization Guidelines:**
- Replace deprecated panel types with modern equivalents (e.g., old `graph` panels → `timeseries`)
- Use latest visualization options (e.g., newer tooltip modes, legend placements)
- Upgrade to latest Grafonnet patterns and methods
- Leverage new Grafana plugins if they provide better functionality

Review the JSON export and identify:
- Panel types (stat, timeseries, table, etc.) - check if using legacy types that should be modernized
- Variables and their configurations
- Custom configurations or legacy settings that can be replaced with modern equivalents
- Complex queries that can be simplified with latest `prom.*` helpers
- Opportunities to use newer Grafana features

For each component, determine the appropriate approach:
- Use `panels.statPanel()`, `panels.timeseriesPanel()`, `panels.tablePanel()`, etc. from unified library
- Use `prom.*` helpers for queries (use latest helper functions)
- Use `standards.*` for units, thresholds, legends
- For complex/legacy configs, modernize first, then use Grafonnet's `.with*()` methods

**When to update general lib libraries:**
Only update `../lib/*.libsonnet` if you discover a pattern that is:
- Truly reusable across multiple dashboards (not dashboard-specific)
- Not already covered by existing lib functions
- Worth generalizing for the entire mixin codebase

Example: If you need a new metric calculation pattern used by many dashboards, add it to `../lib/prometheus.libsonnet`. But dashboard-specific panel configurations stay in the main jsonnet file.

### Step 3: Write a single self-contained Jsonnet file

**File Structure:**
Generate a single `<dashboard>.jsonnet` file with this structure:

```jsonnet
// 1. Grafonnet main library
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// 2. Unified libraries (alphabetically)
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// 3. Config definition
local config = {
  datasource: { type: 'prometheus', uid: 'prometheus-thanos' },
  timezone: 'browser',
  timeFrom: 'now-6h',
  pluginVersion: '12.3.0',
};

// 4. Common selectors/helpers (if needed for this dashboard)
local baseSelector = '{job="api",env="prod"}';

// 5. Variable definitions
local hostnameVariable = g.dashboard.variable.query.new(...);
local environmentVariable = g.dashboard.variable.query.new(...);

// 6. Panel definitions (ALL panels defined here, not in separate lib file)
local qpsStat = panels.statPanel(
  title='Current QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total' + baseSelector + '[1m]))', '')],
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

local errorRatePanel = panels.timeseriesPanel(
  title='Error Rate',
  targets=[prom.errorRate('http_requests_total', baseSelector, 'status', 'Error Rate')],
  unit=standards.units.errorRate,
  legendConfig=standards.legend.hidden,
  theme=themes.timeseries.standard
)
+ g.panel.timeSeries.gridPos.withH(6)
+ g.panel.timeSeries.gridPos.withW(12)
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withY(3);

// ... more panels ...

// 7. Dashboard construction
g.dashboard.new('Dashboard Name')
+ g.dashboard.withUid('dashboard-uid')
+ g.dashboard.withTags(['tag1', 'tag2'])
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withVariables([hostnameVariable, environmentVariable])
+ g.dashboard.withPanels([qpsStat, errorRatePanel, /* ... more panels ... */])
```

**Key Points:**
- ✅ All panel definitions are `local` variables in the main file
- ✅ Use unified library constructors (`panels.*`, `prom.*`, `standards.*`)
- ✅ Self-contained - no dashboard-specific lib imports
- ❌ Do NOT create `lib/<dashboard>_panels.libsonnet`
- ❌ Do NOT create `raw_panels.json` or `raw_variables.json`

#### 3.2 Modernize legacy configurations

When converting old dashboard JSON, actively modernize deprecated features:

**Legacy panel type migrations:**
- Old `graph` panel → Modern `timeseries` panel with `panels.timeseriesPanel()`
- Old `singlestat` → Modern `stat` panel with `panels.statPanel()`
- Legacy `table` → Modern `table` with improved features

**Use latest Grafana features:**
- Modern tooltip modes: `'multi'`, `'single'`, `'none'`
- Latest legend options from `standards.legend.*`
- New visualization options (e.g., gradient mode, line interpolation)
- Latest panel plugins if they improve functionality

**Standardize configurations:**
- Units: Use `standards.units.*` (see `references/lib-api-reference.md`)
  - `'reqps'` → `standards.units.qps`
  - `'percentunit'` → `standards.units.errorRate` or `standards.units.percent01`
  - `'s'` → `standards.units.seconds`

- Thresholds: Use `standards.thresholds.*`
  - Error rate → `standards.thresholds.errorRate`
  - Success rate → `standards.thresholds.successRate`
  - Latency → `standards.thresholds.latencySeconds`

- Themes: Choose modern theme (see `references/lib-api-reference.md`)
  - Regular data → `themes.timeseries.standard`
  - Important metrics → `themes.timeseries.emphasized`
  - Reference lines → `themes.timeseries.light`

**Optimize queries:**
Use latest `prom.libsonnet` helper functions:
- `prom.errorRate(...)` - Error rate calculation
- `prom.successRate(...)` - Success rate calculation
- `prom.p50()`, `prom.p90()`, `prom.p99()` - Percentiles
- `prom.apdex(...)` - Apdex score

**Naming conventions:**
Use camelCase for all variables (see `references/best-practices.md`):
- ✅ `local qpsStat = ...`
- ✅ `local errorRatePanel = ...`
- ❌ `local qps_stat = ...`

#### 3.3 Handle complex configurations

For configurations that don't have direct unified library equivalents:

**Strategy 1: Layer additional properties**
```jsonnet
// Start with unified library constructor
local complexPanel = panels.timeseriesPanel(
  title='Complex Panel',
  targets=[...],
  unit=standards.units.qps,
  legendConfig=standards.legend.standard,
  theme=themes.timeseries.standard
)
// Then add custom properties using Grafonnet methods
+ g.panel.timeSeries.options.tooltip.withMode('multi')
+ g.panel.timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
+ g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(50);
```

**Strategy 2: Use Grafonnet base constructors for unsupported panel types**
```jsonnet
// For panel types without unified library support, use Grafonnet directly
local customPanel = g.panel.barChart.new('Custom Panel')
+ g.panel.barChart.queryOptions.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.panel.barChart.queryOptions.withTargets([...])
// Apply unified library styling where possible
+ g.panel.barChart.standardOptions.withUnit(standards.units.count);
```

**Strategy 3: Complex variable configurations**
```jsonnet
// Use Grafonnet's full variable API for complex cases
local complexVariable = g.dashboard.variable.query.new(
  'environment',
  'label_values(up, environment)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.withRegex('/.*prod.*/')
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.selectionOptions.withMulti(false)
+ { allValue: '.*', sort: 1 };  // Additional properties
```

### Step 4: Integrate and verify

#### 4.1 Place the file
- Place the single `<dashboard>.jsonnet` file into `mixin/<system>/` directory
- Verify import paths point to `../lib/` for unified libraries
- No dashboard-specific lib files should be created

#### 4.2 Compile and verify
```bash
# Linux/macOS
cd mixin
bash build.sh

# Windows
cd mixin
.\build.ps1
```

#### 4.3 Fix compilation errors
If you encounter errors, refer to `references/common-issues.md` for solutions.

Common errors:
- `Field does not exist: percent` → Use `percent01` or `percent100`
- `Field does not exist: rich` → Use `standard/compact/detailed/hidden`
- `max stack frames exceeded` → Use `+` and `super` instead of `self`

### Step 5: Test and optimize

#### 5.1 Import and test in Grafana
1. Compile to JSON: `bash build.sh`
2. Import the generated JSON in Grafana UI
3. Verify all panels display correctly
4. Check variable interactions work properly

#### 5.2 Performance optimization
- Use reasonable refresh interval (recommended 30s)
- Use recording rules for complex queries
- Use collapsed Rows for infrequently used panels

#### 5.3 Code review
- Check all panels use unified library constructors
- Verify import order is correct
- Confirm naming follows conventions
- Verify the file is self-contained (no dashboard-specific lib files created)
- If you find truly reusable patterns across multiple dashboards, consider adding them to `../lib/` general libraries

## Important Notes

**Conversion Philosophy:**
1. **Single self-contained file** - Generate ONE `<dashboard>.jsonnet` file, do NOT create dashboard-specific lib files like `lib/<dashboard>_panels.libsonnet`
2. **NO raw JSON fallback** - All panels, variables, and configurations MUST be converted to proper Jsonnet using unified libraries
3. **Modernize everything** - Replace deprecated panel types and configurations with latest Grafana features and plugins
4. **Use unified libraries** - Leverage `panels.*`, `prom.*`, `standards.*`, `themes.*` for all components
5. **Layer additional properties** - For complex configs, use Grafonnet's `.with*()` methods on top of unified library constructors

**File Organization:**
```
mixin/
├── application/
│   ├── api_dashboard.jsonnet          ← Single self-contained file
│   ├── database_dashboard.jsonnet     ← Another dashboard (single file)
│   └── NO lib/<dashboard>_*.libsonnet ← Do NOT create these!
├── lib/                                ← General unified libraries only
│   ├── panels.libsonnet
│   ├── prometheus.libsonnet
│   ├── standards.libsonnet
│   └── themes.libsonnet
```

**When to Update General Lib:**
Only modify `../lib/*.libsonnet` when adding truly reusable patterns:
- ✅ New metric calculation used by multiple dashboards → add to `prometheus.libsonnet`
- ✅ New standard threshold pattern → add to `standards.libsonnet`
- ✅ New panel constructor used widely → add to `panels.libsonnet`
- ❌ Dashboard-specific panel configs → keep in the dashboard jsonnet file
- ❌ One-off custom visualizations → keep in the dashboard jsonnet file

**Quality Standards:**
- Every panel must use `panels.*Panel()` constructors
- Every query should use `prom.*` helpers where applicable
- All units must use `standards.units.*`
- All thresholds must use `standards.thresholds.*`
- Variables constructed using Grafonnet's `g.dashboard.variable.*` methods
- Modernize legacy panel types (graph → timeseries, singlestat → stat)
- Use latest Grafana features and visualization options

**Reference:**
- Use `examples/example-input.json` and `examples/example-output.jsonnet` as conversion reference