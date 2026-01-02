---
name: grafana-jsonnet-refactor
description: This skill should be used when refactoring monolithic Grafana Jsonnet dashboards into a clean, self-contained structure using unified libraries. Trigger phrases include "refactor grafana jsonnet", "clean up jsonnet dashboard", "modernize dashboard", "use unified libraries", "remove duplicated code". Use when a dashboard is hard to maintain, has duplicated code, uses outdated patterns, or needs to adopt grafana-code mixin conventions. CRITICAL: Generate a single self-contained jsonnet file - do NOT create dashboard-specific lib files.
---

# Grafana Jsonnet Refactor

## Inputs
- Path to an existing Jsonnet dashboard (messy, with duplicated code)
- Target system folder (for example `mixin/application`)
- Datasource type and UID (for example `prometheus` + `prometheus-thanos`)

## Outputs
- `<dashboard>.jsonnet` (single self-contained dashboard file, refactored and cleaned)
- Optionally: Updates to `../lib/*.libsonnet` (only if adding truly reusable components to the general library)

## Steps

### Step 1: Understand grafana-code conventions
Review the following reference documents to understand the code conventions:
- `references/best-practices.md` - Code organization and naming conventions
- `references/lib-api-reference.md` - Unified library API quick reference
- `references/refactor-checklist.md` - Step-by-step refactoring checklist
- `references/style-guide.md` - grafana-code style guide

### Step 2: Analyze the existing dashboard

**Identify problems**:
1. **Duplicated code**: Multiple panels with similar configurations
2. **Hardcoded values**: Colors, thresholds, units scattered throughout
3. **Local helper functions**: Custom panel builders that should use unified libraries
4. **Inconsistent patterns**: Different panels using different approaches
5. **Legacy configurations**: Old panel types (graph → timeseries), deprecated options
6. **Complex structure**: Overly nested or unorganized code

**Determine refactoring mode**:

Choose one of three approaches based on dashboard complexity:

**Mode 1: Direct Migration** (recommended for < 30 panels, < 1500 lines)
- Completely remove local helper functions
- Directly use unified library functions (`panels.*`, `prom.*`, `standards.*`)
- Best code reduction: 25-28%

**Mode 2: Wrapper Pattern** (recommended for > 30 panels, > 1500 lines)
- Keep local helper function signatures
- Internal implementation calls unified library functions
- Minimal disruption, backward compatible

**Mode 3: Hybrid** (for complex dashboards with special needs)
- Mix of direct migration + wrappers
- Use wrappers only where absolutely needed

### Step 3: Refactor to a single self-contained file

**CRITICAL REQUIREMENTS:**
1. Generate a **single self-contained jsonnet file** - do NOT create `lib/<dashboard>_panels.libsonnet`
2. All panel definitions should be written directly in the main jsonnet file as `local` variables
3. Replace local helper functions with unified library calls
4. Modernize legacy configurations (graph → timeseries, singlestat → stat)
5. Use latest Grafana features and plugins

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

// 3. Datasource configuration (dual-mode support)
// For provisioning: use actual UID
// For manual import: switch to '${DS_PROMETHEUS}' to allow datasource selection
local DATASOURCE_UID = 'prometheus-thanos';  // Replace with your actual datasource UID
// local DATASOURCE_UID = '${DS_PROMETHEUS}';  // manual import mode (uncomment this line, comment above line)

local config = {
  datasource: {
    type: 'prometheus',  // Change to your datasource type (e.g., 'loki', 'tempo', 'elasticsearch')
    uid: DATASOURCE_UID,
  },
  timezone: 'browser',  // Or 'utc', or specific timezone like 'Asia/Shanghai'
  timeFrom: 'now-6h',  // Adjust default time range as needed (e.g., 'now-1h', 'now-24h', 'now-7d')
  timeTo: 'now',
  pluginVersion: '12.3.0',  // Current Grafana version, update as needed
};

// 4. Common selectors/helpers (if needed for this dashboard)
// Replace with your actual Prometheus label selectors
local baseSelector = '{job="api",env="prod"}';  // Example: adjust to match your metrics

// 5. Variable definitions
local hostnameVariable = g.dashboard.variable.query.new(
  'hostname',
  'label_values(up, hostname)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.refresh.onLoad();

local environmentVariable = g.dashboard.variable.query.new(
  'environment',
  'label_values(up{hostname=~"$hostname"}, environment)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.refresh.onLoad();

// 6. Panel definitions (ALL panels defined here, not in separate lib file)
// NOTE: Replace metric names, queries, and panel titles with your actual dashboard requirements
local qpsStat = panels.statPanel(
  title='Current QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total' + baseSelector + '[1m]))', '')],  // Replace with your metrics
  datasource=config.datasource,
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width)
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withY(0);

local errorRatePanel = panels.timeseriesPanel(
  title='Error Rate',
  targets=[prom.errorRate('http_requests_total', baseSelector, 'status', 'Error Rate')],
  datasource=config.datasource,
  unit=standards.units.errorRate,
  legendConfig=standards.legend.hidden,
  theme=themes.timeseries.standard,
  pluginVersion=config.pluginVersion
)
+ g.panel.timeSeries.gridPos.withH(6)
+ g.panel.timeSeries.gridPos.withW(12)
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withY(3);

// ... more panels ...

// 7. Annotations configuration
local annotationsObj = {
  list: [
    {
      builtIn: 1,
      datasource: { type: 'grafana', uid: '-- Grafana --' },
      enable: true,
      hide: true,
      iconColor: 'rgba(0, 211, 255, 1)',
      name: 'Annotations & Alerts',
      type: 'dashboard',
    },
  ],
};

// 8. Dashboard construction (using chained method calls)
local baseDashboard = g.dashboard.new('Dashboard Name')  // Replace with your dashboard title
+ g.dashboard.withUid('dashboard-uid')  // Replace with unique dashboard UID (lowercase, hyphens)
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withEditable(true)
+ g.dashboard.withTags(['tag1', 'tag2'])  // Replace with relevant tags for your dashboard
+ g.dashboard.withRefresh('30s')  // Adjust refresh interval (e.g., '5s', '1m', '5m', '15m')
+ g.dashboard.withVariables([hostnameVariable, environmentVariable])
+ g.dashboard.withPanels([qpsStat, errorRatePanel, /* ... more panels ... */]);

// 9. Final export with metadata (supports manual import with datasource selection)
// NOTE: Adjust datasource types in __inputs and __requires to match your actual datasources
// Common datasource types: prometheus, loki, tempo, elasticsearch, grafana-clickhouse-datasource, mysql, postgres
baseDashboard {
  annotations: annotationsObj,
  graphTooltip: 0,  // 0 = default, 1 = shared crosshair, 2 = shared tooltip
  schemaVersion: 42,
  version: 1,
  __inputs: [
    {
      name: 'DS_PROMETHEUS',  // Change to match your datasource (e.g., DS_LOKI, DS_TEMPO)
      label: 'Prometheus Datasource',  // Update label to match datasource type
      description: 'Select Prometheus datasource',  // Update description
      type: 'datasource',
      pluginId: 'prometheus',  // Change to actual plugin ID (e.g., 'loki', 'tempo', 'elasticsearch')
      pluginName: 'Prometheus',  // Change to actual plugin name
    },
  ],
  __elements: {},
  __requires: [
    {
      type: 'datasource',
      id: 'prometheus',  // Change to actual datasource plugin ID
      name: 'Prometheus',  // Change to actual datasource name
      version: '1.0.0',
    },
    {
      type: 'grafana',
      id: 'grafana',
      name: 'Grafana',
      version: config.pluginVersion,
    },
    {
      type: 'panel',
      id: 'timeseries',
      name: 'Time series',
      version: '',
    },
    {
      type: 'panel',
      id: 'stat',
      name: 'Stat',
      version: '',
    },
    {
      type: 'panel',
      id: 'table',
      name: 'Table',
      version: '',
    },
    // Add other panel types as needed: bargauge, gauge, etc.
  ],
}
```

**Key Points:**
- ✅ All panel definitions are `local` variables in the main file
- ✅ Use unified library constructors (`panels.*`, `prom.*`, `standards.*`)
- ✅ Self-contained - no dashboard-specific lib imports
- ❌ Do NOT create `lib/<dashboard>_panels.libsonnet`
- ❌ Do NOT keep large local helper functions - use unified libraries instead

### Step 4: Replace local helpers with unified library calls

**Common replacements:**

```jsonnet
// ❌ Before: Custom helper function
local promTarget(expr, legendFormat, refId='A') = {
  datasource: { type: 'prometheus', uid: 'prometheus-thanos' },
  expr: expr,
  legendFormat: legendFormat,
  refId: refId,
};

// ✅ After: Use unified library
// Simply use: prom.target(expr, legendFormat, refId)

// ❌ Before: Custom panel builder
local timeseriesPanel(title, targets, unit) = {
  type: 'timeseries',
  title: title,
  targets: targets,
  fieldConfig: {
    defaults: {
      unit: unit,
      custom: {
        fillOpacity: 18,
        lineWidth: 2,
      },
    },
  },
};

// ✅ After: Use unified library
// panels.timeseriesPanel(
//   title=title,
//   targets=targets,
//   unit=unit,
//   theme=themes.timeseries.standard
// )
```

**Wrapper Pattern (for complex dashboards):**

```jsonnet
// Keep the helper signature, but call unified library internally
local promTarget(expr, legendFormat, refId='A', instant=false) =
  if instant then
    prom.instantTarget(expr, legendFormat, refId)
  else
    prom.target(expr, legendFormat, refId);

local timeseriesPanel(title, targets, unit, legendConfig=null) =
  panels.timeseriesPanel(
    title=title,
    targets=targets,
    unit=unit,
    legendConfig=if legendConfig != null then legendConfig else standards.legend.standard,
    theme=themes.timeseries.standard
  );
```

### Step 5: Modernize and standardize

**Replace hardcoded values:**

```jsonnet
// ❌ Before: Hardcoded units
unit: 'reqps'
unit: 'percentunit'

// ✅ After: Use standards
unit: standards.units.qps
unit: standards.units.errorRate

// ❌ Before: Hardcoded thresholds
thresholds: {
  steps: [
    { color: 'green', value: null },
    { color: 'yellow', value: 0.02 },
    { color: 'red', value: 0.05 },
  ],
}

// ✅ After: Use standards
thresholds: standards.thresholds.errorRate

// ❌ Before: Hardcoded colors
color: '#52C41A'
color: '#F5222D'

// ✅ After: Use helpers
color: helpers.colors.green
color: helpers.colors.red
```

**Modernize legacy panel types:**

```jsonnet
// ❌ Before: Old graph panel
type: 'graph'

// ✅ After: Modern timeseries
panels.timeseriesPanel(...)

// ❌ Before: Old singlestat
type: 'singlestat'

// ✅ After: Modern stat
panels.statPanel(...)
```

### Step 6: Clean up and organize

**Naming conventions:**
- Use camelCase for all variables (not snake_case)
- Group related panels together
- Keep logical ordering (overview → details)

```jsonnet
// ✅ Good naming
local qpsStat = panels.statPanel(...);
local errorRatePanel = panels.timeseriesPanel(...);
local latencyP99Panel = panels.timeseriesPanel(...);

// ❌ Bad naming
local qps_stat = panels.statPanel(...);
local panel1 = panels.timeseriesPanel(...);
local x = panels.timeseriesPanel(...);
```

**Remove duplicated configuration:**

```jsonnet
// ❌ Before: Repeated gridPos
local panel1 = panels.statPanel(...) + g.panel.stat.gridPos.withH(4) + g.panel.stat.gridPos.withW(6);
local panel2 = panels.statPanel(...) + g.panel.stat.gridPos.withH(4) + g.panel.stat.gridPos.withW(6);
local panel3 = panels.statPanel(...) + g.panel.stat.gridPos.withH(4) + g.panel.stat.gridPos.withW(6);

// ✅ After: Use layouts
local panel1 = panels.statPanel(...) + g.panel.stat.gridPos.withH(layouts.stat.height) + g.panel.stat.gridPos.withW(layouts.stat.width);
local panel2 = panels.statPanel(...) + g.panel.stat.gridPos.withH(layouts.stat.height) + g.panel.stat.gridPos.withW(layouts.stat.width);
local panel3 = panels.statPanel(...) + g.panel.stat.gridPos.withH(layouts.stat.height) + g.panel.stat.gridPos.withW(layouts.stat.width);
```

### Step 7: Verify and test

**Compile and verify:**
```bash
# Linux/macOS
cd mixin
bash build.sh

# Windows
cd mixin
.\build.ps1
```

**Quality checks:**
- [ ] Compiles without errors
- [ ] Panel count matches original
- [ ] No local helper functions (or wrappers call unified libraries)
- [ ] Uses `standards.units.*` for all units
- [ ] Uses `standards.thresholds.*` for all thresholds
- [ ] Uses `standards.legend.*` for legend configs
- [ ] Uses `themes.timeseries.*` for timeseries styling
- [ ] Uses `prom.*` for all Prometheus queries
- [ ] All variables use camelCase
- [ ] Single self-contained file (no dashboard-specific lib)

**Import and test in Grafana:**
1. Compile to JSON: `bash build.sh`
2. Import the generated JSON in Grafana UI
3. Verify all panels display correctly
4. Check variable interactions work properly

## Important Notes

**Refactoring Philosophy:**
1. **Single self-contained file** - Generate ONE `<dashboard>.jsonnet` file
2. **No dashboard-specific libs** - Do NOT create `lib/<dashboard>_panels.libsonnet`
3. **Use unified libraries** - Leverage `panels.*`, `prom.*`, `standards.*`, `themes.*`
4. **Modernize everything** - Replace deprecated panel types and configurations
5. **Remove duplication** - Eliminate repeated code and hardcoded values

**When to Update General Lib:**
Only modify `../lib/*.libsonnet` when adding truly reusable patterns:
- ✅ New metric calculation used by multiple dashboards → add to `prometheus.libsonnet`
- ✅ New standard threshold pattern → add to `standards.libsonnet`
- ✅ New panel constructor used widely → add to `panels.libsonnet`
- ❌ Dashboard-specific panel configs → keep in the dashboard jsonnet file
- ❌ One-off custom visualizations → keep in the dashboard jsonnet file

**Quality Standards:**
- Every panel must use `panels.*Panel()` constructors (or wrappers that call them)
- Every query should use `prom.*` helpers where applicable (or wrappers that call them)
- All units must use `standards.units.*`
- All thresholds must use `standards.thresholds.*`
- Variables constructed using Grafonnet's `g.dashboard.variable.*` methods
- Modernize legacy panel types (graph → timeseries, singlestat → stat)
- Use latest Grafana features and visualization options

**Three Refactoring Modes:**

| Mode | Dashboard Size | Approach | Code Reduction | Example |
|------|---------------|----------|----------------|---------|
| Direct Migration | < 30 panels, < 1500 lines | Remove helpers, use libs directly | 25-28% | ingress_nginx, jvm_micrometer |
| Wrapper Pattern | > 30 panels, > 1500 lines | Keep helper signatures, call libs internally | 2-5% | k8s_pod_monitor, service_monitor |
| Hybrid | Complex dashboards | Mix of both approaches | 10-20% | Custom cases |

**Reference:**
- See `references/refactor-checklist.md` for detailed step-by-step checklist
- See `references/best-practices.md` for code organization guidelines
- See `references/lib-api-reference.md` for unified library API reference