# Full Conversion Playbook (Single-File Jsonnet)

Use this document for end-to-end conversion details, examples, and edge cases.

## Contents

- [Reference index (load as needed)](#reference-index-load-as-needed)
- [Quick start (summary)](#quick-start-summary)
- [Critical requirements](#critical-requirements)
- [Conversion philosophy](#conversion-philosophy)
- [Step 1: Review conventions](#step-1-review-conventions)
- [Step 2: Analyze the export JSON and create inventory](#step-2-analyze-the-export-json-and-create-inventory)
- [Step 3: Build a single self-contained Jsonnet file](#step-3-build-a-single-self-contained-jsonnet-file)
  - [Variables with validation checkpoint](#35-variable-configurations)
  - [Row structure and panel organization](#36-row-structure-and-panel-organization)
- [Step 4: Compile and fix build errors](#step-4-compile-and-fix-build-errors)
- [Step 5: Verify completeness with scripts](#step-5-verify-completeness-with-scripts)
- [Step 6: Visual verification in Grafana](#step-6-visual-verification-in-grafana)
- [Step 7: Final optimization](#step-7-final-optimization)
- [Quality checklist](#quality-checklist)

---

## Reference index (load as needed)

- `references/lib-api-reference.md` - unified library APIs and examples.
- `references/mapping.md` - panel/target mapping from JSON -> unified libs.
- `references/verification-guide.md` - inventory and verification scripts.
- `references/common-issues.md` - compilation/runtime troubleshooting patterns.
- `references/examples.md` - detailed input -> output examples (open only when needed).

## Quick start (summary)

1. Review conventions (import order, config block, naming, UID rule).
2. Inventory the source JSON (panels, rows, variables, datasources).
3. Create datasource + config block (provisioning + manual import).
4. Convert panels using `panels.*Panel()` and helper libs.
5. Preserve rows and align panel `gridPos.y` to row `gridPos.y`.
6. Convert variables with `g.dashboard.variable.*`.
7. Assemble dashboard with `__inputs` / `__requires`.
8. Compile and verify completeness (counts, rows, variables).

## Critical requirements

1. Convert all panels, variables, and configurations to Jsonnet using unified libraries.
2. Generate a single self-contained Jsonnet file (no dashboard-specific lib files).
3. Modernize legacy panel types and deprecated options.
4. Regenerate dashboard UID from the dashboard name (do not reuse source UID).
5. Only modify `mixin/lib/*.libsonnet` for truly reusable components.
6. Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.

## Conversion philosophy

- Single self-contained file per dashboard.
- No raw JSON fallback files in final output.
- Prefer unified library constructors and helper functions.
- Layer Grafonnet `.with*()` methods for advanced options.

## Step 1: Review conventions

Use these conventions:

- Import order and config block: follow the skeleton in Step 3.1.
- Naming: lowerCamelCase for locals; dashboard UID uses hyphen-case derived from name.
- Unified libs: `panels.*`, `prom.*`, `standards.*`, `themes.*`, `layouts.*`.
- Row structure: rows are explicit; panel `gridPos.y` matches row `gridPos.y`.
- Formatting: do not run `jsonnet fmt` / `jsonnetfmt`.

See `references/lib-api-reference.md` and `references/mapping.md` for API details.

## Step 2: Analyze the export JSON and create inventory

**CRITICAL: Count all elements before conversion to ensure completeness.**

Run these commands to create an inventory:

```bash
# Total panels (including those in rows)
echo "Total panels (including in rows):"
jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end] | length' input.json

# Top-level panels only
echo "Top-level panels:"
jq '.panels | length' input.json

# Rows count
echo "Rows:"
jq '[.panels[] | select(.type == "row")] | length' input.json

# List all row titles
echo "Row titles:"
jq -r '.panels[] | select(.type == "row") | .title' input.json

# Variables count
echo "Variables:"
jq '.templating.list | length' input.json

# List all variable names
echo "Variable names:"
jq -r '.templating.list[].name' input.json

# Datasources used
echo "Datasources:"
jq -r '.panels[].datasource.type' input.json | sort -u
```

Save this inventory for verification after conversion.

Identify for conversion:
- Panel types (stat, timeseries, table, etc.)
- Variables and templating configuration
- Row structure and which panels belong to each row
- Datasource types and UIDs
- Legacy configs that should be modernized
- Complex queries that can use `prom.*` helpers

## Step 3: Build a single self-contained Jsonnet file

### 3.1 File structure skeleton

```jsonnet
// 1) Grafonnet main library
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// 2) Unified libraries (alphabetical)
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// 3) Datasource configuration (dual-mode support)
// Provisioning mode (real UID). For manual import, switch to ${DS_*}.
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
  pluginVersion: '12.3.0',
};

// 4) Constants / selectors (optional)
local baseSelector = '{job="api",env="prod"}';

// 5) Panels (all panels defined here)
local qpsStat = panels.statPanel(
  title='QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
  datasource=config.datasource,
  unit=standards.units.qps,
  thresholds=standards.thresholds.neutral,
  pluginVersion=config.pluginVersion
)
+ g.panel.stat.gridPos.withH(layouts.stat.height)
+ g.panel.stat.gridPos.withW(layouts.stat.width);

// 6) Rows
local overviewRow = panels.rowPanel('Overview', collapsed=true)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([qpsStat]);

// 7) Variables
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

// 8) Annotations (optional)
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

// 9) Dashboard assembly
local baseDashboard = g.dashboard.new('Dashboard Name')
+ g.dashboard.withUid('dashboard-uid')
+ g.dashboard.withTimezone(config.timezone)
+ g.dashboard.time.withFrom(config.timeFrom)
+ g.dashboard.time.withTo(config.timeTo)
+ g.dashboard.withVariables([hostnameVariable])
+ g.dashboard.withPanels([overviewRow]);

// 10) Final export with metadata (manual import supported)
baseDashboard {
  annotations: annotationsObj,
  schemaVersion: 42,
  version: 1,
  __inputs: [
    {
      name: 'DS_PROMETHEUS',
      label: 'Prometheus Datasource',
      description: 'Select Prometheus datasource',
      type: 'datasource',
      pluginId: 'prometheus',
      pluginName: 'Prometheus',
    },
  ],
  __requires: [
    { type: 'datasource', id: 'prometheus', name: 'Prometheus', version: '1.0.0' },
    { type: 'grafana', id: 'grafana', name: 'Grafana', version: config.pluginVersion },
    { type: 'panel', id: 'timeseries', name: 'Time series', version: '' },
    { type: 'panel', id: 'stat', name: 'Stat', version: '' },
    { type: 'panel', id: 'table', name: 'Table', version: '' },
  ],
}
```

### 3.2 Modernize legacy configurations

- `graph` -> `timeseries`
- `singlestat` -> `stat`
- Prefer `standards.legend.*` and `themes.timeseries.*`
- Use newer tooltip modes and legend options
- Prefer recent Grafonnet patterns and options

### 3.3 Standardize units, thresholds, themes

- Units: `standards.units.*`
- Thresholds: `standards.thresholds.*`
- Themes: `themes.timeseries.*`

### 3.4 Complex configurations

Layer Grafonnet options on top of unified constructors:

```jsonnet
local panel = panels.timeseriesPanel(
  title='Latency',
  targets=[...],
  unit=standards.units.seconds,
  theme=themes.timeseries.standard
)
+ g.panel.timeSeries.options.tooltip.withMode('multi')
+ g.panel.timeSeries.fieldConfig.defaults.custom.withFillOpacity(30);
```

If a panel type is unsupported by unified libs, use Grafonnet directly and still apply `standards.units.*` and `standards.thresholds.*`.

### 3.5 Variable configurations

```jsonnet
local environmentVariable = g.dashboard.variable.query.new(
  'environment',
  'label_values(up{hostname=~"$hostname"}, environment)'
)
+ g.dashboard.variable.query.withDatasource(
  type=config.datasource.type,
  uid=config.datasource.uid
)
+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)
+ g.dashboard.variable.query.selectionOptions.withMulti(false)
+ g.dashboard.variable.query.refresh.onLoad();
```

**Validation checkpoint:** After converting variables, verify count:
```bash
# Count variables in source JSON
SOURCE_VARS=$(jq '.templating.list | length' input.json)

# Count variables in Jsonnet
JSONNET_VARS=$(grep -c "g.dashboard.variable" output.jsonnet)

echo "Source: $SOURCE_VARS, Jsonnet: $JSONNET_VARS"
# Must match
```

Also verify:
- No duplicate or extra variables.
- Regex filters preserved (or added for high-cardinality labels).
- Variables return values in Grafana (non-empty dropdowns).

### 3.6 Row structure and panel organization

**CRITICAL: Rows organize panels in Grafana dashboards. Always preserve row structure.**

Extract row information from source JSON:
```bash
# List all rows with their collapsed state
jq -r '.panels[] | select(.type == "row") | "\(.title) - collapsed: \(.collapsed)"' input.json

# For each row, list panels that belong to it
jq -r '.panels[] | select(.type == "row") | .title' input.json | while read row; do
  echo "Row: $row"
  # Panels in rows are stored in the row's panels array in older Grafana
  # Or they follow the row with matching gridPos.y in newer Grafana
done
```

Convert rows to Jsonnet:
```jsonnet
// Create row objects
local overviewRow = panels.rowPanel('Overview', collapsed=false)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([panel1, panel2]);

local metricsRow = panels.rowPanel('Metrics', collapsed=false)
+ g.panel.row.gridPos.withY(5)
+ g.panel.row.withPanels([panel3]);

// Panels at Y=0 belong to overviewRow
local panel1 = panels.statPanel(...)
+ g.panel.stat.gridPos.withY(0)  // Same Y as overviewRow
+ g.panel.stat.gridPos.withX(0)
+ g.panel.stat.gridPos.withH(4)
+ g.panel.stat.gridPos.withW(6);

local panel2 = panels.statPanel(...)
+ g.panel.stat.gridPos.withY(0)  // Same Y as overviewRow
+ g.panel.stat.gridPos.withX(6)
+ g.panel.stat.gridPos.withH(4)
+ g.panel.stat.gridPos.withW(6);

// Panels at Y=5 belong to metricsRow
local panel3 = panels.timeseriesPanel(...)
+ g.panel.timeSeries.gridPos.withY(5)  // Same Y as metricsRow
+ g.panel.timeSeries.gridPos.withX(0)
+ g.panel.timeSeries.gridPos.withH(8)
+ g.panel.timeSeries.gridPos.withW(24);

// Include rows in correct order
local allPanels = [
  overviewRow,
  metricsRow,
];
```

**Validation checkpoint:** After converting panels, verify count:
```bash
# Count total panels in source (including those in rows, excluding row objects themselves)
SOURCE_PANELS=$(jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row")] | length' input.json)

# Count panel definitions in Jsonnet
JSONNET_PANELS=$(grep -c "local .*Panel = panels\." output.jsonnet)

echo "Source panels: $SOURCE_PANELS, Jsonnet panels: $JSONNET_PANELS"
# Must match
```

## Step 4: Compile and fix build errors

Place the single `<dashboard>.jsonnet` file under `mixin/<system>/` and compile:

```bash
cd mixin
./build.sh   # or build.ps1 on Windows
```

Fix compilation errors. Common issues:
- `Field does not exist: percent` -> use `standards.units.percent01` or `percent100`
- `Field does not exist: rich` -> use `standards.legend.standard/compact/detailed/hidden`
- `max stack frames exceeded` -> use `+` operator instead of recursive `self` references

Consult `references/common-issues.md` for more error patterns.

## Step 5: Verify completeness with scripts

**CRITICAL: Run these validation scripts to ensure nothing is missing.**

Additional checks to include:
- Variables return values in Grafana; no duplicates or extras.
- Regex filters preserved (or added when needed).
- Row membership verified via compiled JSON (`gridPos.y` alignment).

Create a validation script `verify-conversion.sh`:

```bash
#!/bin/bash

INPUT_JSON="input-dashboard.json"
OUTPUT_JSONNET="mixin/application/dashboard.jsonnet"

echo "=== Conversion Completeness Verification ==="

# 1. Panel count
echo -e "\n1. Panel Count Verification:"
SOURCE_PANELS=$(jq '[.panels[] | if .type == "row" then (.panels // [])[] else . end | select(.type != "row")] | length' $INPUT_JSON)
JSONNET_PANELS=$(grep -c "local .*Panel = panels\." $OUTPUT_JSONNET)

echo "Source panels: $SOURCE_PANELS"
echo "Jsonnet panels: $JSONNET_PANELS"

if [ "$SOURCE_PANELS" == "$JSONNET_PANELS" ]; then
  echo "✓ Panel count matches"
else
  echo "✗ ERROR: Panel count mismatch! Missing $(($SOURCE_PANELS - $JSONNET_PANELS)) panels"
  exit 1
fi

# 2. Variable count
echo -e "\n2. Variable Verification:"
SOURCE_VARS=$(jq '.templating.list | length' $INPUT_JSON)
JSONNET_VARS=$(grep -c "g.dashboard.variable" $OUTPUT_JSONNET)

echo "Source variables: $SOURCE_VARS"
echo "Jsonnet variables: $JSONNET_VARS"

if [ "$SOURCE_VARS" == "$JSONNET_VARS" ]; then
  echo "✓ Variable count matches"
else
  echo "✗ ERROR: Variable count mismatch!"

  # Show which variables are missing
  echo "Source variables:"
  jq -r '.templating.list[].name' $INPUT_JSON | sort

  echo "Jsonnet variables:"
  grep "g.dashboard.variable" $OUTPUT_JSONNET | grep -oP "'\K[^']+" | sort

  exit 1
fi

# 3. Row structure
echo -e "\n3. Row Structure Verification:"
SOURCE_ROWS=$(jq '[.panels[] | select(.type == "row")] | length' $INPUT_JSON)
JSONNET_ROWS=$(rg -c "panels\\.rowPanel\\(|g\\.panel\\.row\\.new|type: 'row'" $OUTPUT_JSONNET)

echo "Source rows: $SOURCE_ROWS"
echo "Jsonnet rows: $JSONNET_ROWS"

if [ "$SOURCE_ROWS" == "$JSONNET_ROWS" ]; then
  echo "✓ Row count matches"
else
  echo "✗ WARNING: Row count mismatch"
  echo "Source row titles:"
  jq -r '.panels[] | select(.type == "row") | .title' $INPUT_JSON
fi

echo -e "\n=== All validation checks passed! ==="
```

Run the verification:
```bash
chmod +x verify-conversion.sh
./verify-conversion.sh input-dashboard.json mixin/application/dashboard.jsonnet /path/to/compiled-dashboard.json
```

**If verification fails:**
1. Note which elements are missing (panels, variables, or rows)
2. Return to Step 3 and add the missing elements
3. Recompile (Step 4)
4. Run verification again (Step 5)

Repeat until all checks pass.

## Step 6: Visual verification in Grafana

After automated checks pass, import the dashboard to Grafana and verify:

1. **Panel count**: Should match source dashboard
2. **Variables populate**: All dropdowns should have values
3. **Row structure**: Panels should be organized in rows
4. **No missing panels**: Compare side-by-side with source dashboard
5. **Queries work**: All panels should display data

If any issues are found, return to Step 3 and fix them.

## Step 7: Final optimization

- Import compiled JSON into Grafana and verify panels/variables.
- Use reasonable refresh intervals (30s default).
- Prefer recording rules for expensive queries.

## File organization (single file)

```
mixin/<system>/
- <dashboard>.jsonnet
```

## When to update general libs

Only update `mixin/lib/*.libsonnet` if the pattern is reusable across dashboards:
- New metric calculation used by multiple dashboards -> `prometheus.libsonnet`
- New standard threshold pattern -> `standards.libsonnet`
- New shared panel constructor -> `panels.libsonnet`

Do not add dashboard-specific helpers to global libs.

## Quality standards

- Every panel uses `panels.*Panel()` unless unsupported.
- All units and thresholds use `standards.*`.
- Queries use `prom.*` helpers where possible.
- Variables use `g.dashboard.variable.*` APIs.
- Dashboard UID is regenerated from the dashboard name.
- No dashboard-specific lib files or raw JSON panels remain.

## Optional scaffold script

You can run `scripts/convert_grafana_json.py` to generate a scaffold (entrypoint + lib + raw files).
Use it only as a scratchpad: inline all panels and variables into a single file and delete raw JSON files.

## Examples

- `references/examples.md` (input -> output walkthroughs)
