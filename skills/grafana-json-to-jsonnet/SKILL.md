---
name: grafana-json-to-jsonnet
description: This skill should be used when converting Grafana dashboard JSON exports to Jsonnet that matches the grafana-code mixin style. Trigger phrases include "convert grafana json", "grafana export to jsonnet", "import grafana dashboard", "grafana-code integration", "json to jsonnet". Use when the user provides a Grafana export JSON file and asks to integrate it into grafana-code with lib split, datasource parameterization, and dashboard metadata.
---

# Grafana JSON Export to Jsonnet

## Inputs
- Grafana export JSON file (from Grafana UI: Share -> Export)
- Target mixin system folder (for example `mixin/application`)
- Datasource type and UID (for example `prometheus` + `prometheus-thanos`)

## Outputs
- `<output>/<dashboard>.jsonnet` (dashboard entrypoint)
- `<output>/lib/<dashboard>_panels.libsonnet` (panel builders)
- `<output>/lib/<dashboard>_raw_panels.json` (raw fallback panels)
- `<output>/lib/<dashboard>_raw_variables.json` (raw fallback variables)

## Steps

### Step 1: Understand grafana-code conventions
Review the following reference documents to understand the code conventions:
- `references/best-practices.md` - Code organization and naming conventions
- `references/lib-api-reference.md` - Unified library API quick reference
- `references/style-guide.md` - grafana-code style guide

### Step 2: Run conversion script to generate Jsonnet scaffold
```bash
python scripts/convert_grafana_json.py \
  --input <export.json> \
  --output-dir <mixin/system> \
  --system <system> \
  --datasource-type <type> \
  --datasource-uid <uid>
```

Generated files:
- `<dashboard>.jsonnet` - Dashboard entrypoint
- `lib/<dashboard>_panels.libsonnet` - Panel builders (if needed)
- `lib/<dashboard>_raw_panels.json` - Panels that cannot be auto-converted (require manual handling)

### Step 3: Review and refine the generated Jsonnet

#### 3.1 Check import order
Ensure import order follows conventions (see `references/best-practices.md`):
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
local config = { ... };

// 4. Variable definitions
// 5. Panel definitions
// 6. Dashboard construction
```

#### 3.2 Replace TODO markers

**Panel type mapping:**
Use `references/lib-api-reference.md` to find the correct panel constructors:
- Stat Panel → `panels.statPanel(...)`
- Timeseries Panel → `panels.timeseriesPanel(...)`
- Table Panel → `panels.tablePanel(...)`
- Row → `panels.rowPanel(...)`

**Unit standardization:**
Replace hardcoded units with `standards.units.*`:
- `'reqps'` → `standards.units.qps`
- `'percentunit'` → `standards.units.errorRate` or `standards.units.percent01`
- `'s'` → `standards.units.seconds`
- `'ms'` → `standards.units.milliseconds`
- `'bytes'` → `standards.units.bytes`

**Threshold standardization:**
Use `standards.thresholds.*`:
- Error rate → `standards.thresholds.errorRate`
- Success rate → `standards.thresholds.successRate`
- Latency (seconds) → `standards.thresholds.latencySeconds`
- No alert meaning → `standards.thresholds.neutral`

**Theme selection:**
Choose appropriate theme based on data type (see `references/lib-api-reference.md`):
- Regular timeseries → `themes.timeseries.standard`
- Important metrics → `themes.timeseries.emphasized`
- Reference lines → `themes.timeseries.light`
- Bar chart → `themes.timeseries.bars`

**Legend configuration:**
Select based on series count (see `references/best-practices.md`):
- 1-3 series → `standards.legend.detailed`
- 4-8 series → `standards.legend.standard`
- 9+ series → `standards.legend.compact`
- Single series/reference → `standards.legend.hidden`

#### 3.3 Optimize queries
Use `prom.libsonnet` helper functions to simplify queries:
- Error rate → `prom.errorRate(...)`
- Success rate → `prom.successRate(...)`
- Percentiles → `prom.p50(...)`, `prom.p90(...)`, `prom.p99(...)`
- Apdex Score → `prom.apdex(...)`

#### 3.4 Check naming conventions
Ensure camelCase naming (see `references/best-practices.md`):
- ✅ `local qpsStat = ...`
- ✅ `local errorRatePanel = ...`
- ❌ `local qps_stat = ...`

### Step 4: Integrate into grafana-code

#### 4.1 Place files
- Place `<dashboard>.jsonnet` into `mixin/<system>/`
- If there are lib files, place them into `mixin/<system>/lib/`
- Keep import paths pointing to `../lib` (unified libs) and `../../lib` (if used)

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
- Check for extractable duplicate code

## Notes
- The script prioritizes a safe scaffold over a perfect conversion. Unknown panel types are emitted as raw panels for manual handling.
- Use `examples/example-input.json` and `examples/example-output.jsonnet` as a quick sanity check.