---
name: grafana-json-to-jsonnet
description: Converts Grafana dashboard JSON exports to Jsonnet using grafana-code mixin conventions. Use when importing dashboards from Grafana UI exports, migrating to infrastructure-as-code, or integrating JSON dashboards into grafana-code. Produces self-contained Jsonnet files with unified libraries, modernizes legacy panel types, and supports manual import with datasource selection.
---

# Grafana JSON Export to Jsonnet

Convert Grafana JSON exports (UI: Share → Export) to Jsonnet using grafana-code unified libraries. Produce a single self-contained file, modernize legacy panels, and preserve row structure.

**Not suitable for**: Refactoring existing Jsonnet (use `grafana-jsonnet-refactor`), content optimization (use `grafana-dashboard-optimize`), or Python report migration (use `grafana-report-to-dashboard`).

## Workflow with validation

**Copy this checklist and track your progress:**

```
Conversion Progress:
- [ ] Step 1: Analyze source JSON and create inventory
- [ ] Step 2: Convert variables (verify count matches)
- [ ] Step 3: Convert rows (preserve structure)
- [ ] Step 4: Convert panels (verify count and placement)
- [ ] Step 5: Compile and fix build errors
- [ ] Step 6: Verify completeness (run validation checks)
- [ ] Step 7: Fix any missing elements
```

**Step 1: Analyze source JSON and create inventory**

Count all elements in the source JSON (panels, variables, rows). See `references/verification-guide.md` for inventory scripts.
Capture the dashboard title and generate a **new UID derived from the name** (do not reuse the source UID).

**Step 2: Convert variables**

Convert all variables with `g.dashboard.variable.*` constructors. After conversion, verify count matches inventory.

**Step 3: Convert rows**

Create rows with `panels.rowPanel()` or `g.panel.row.new()` and keep `collapsed` + `gridPos` aligned to the source JSON.

**Step 4: Convert panels and assign to rows**

Convert panels with unified constructors (`panels.*Panel()`). Add `id` and `gridPos` via `panels.withIdAndPatches(...)` or `+ { id, gridPos }`. Set each panel's `gridPos.y` to its row `gridPos.y` and keep the original `x/w/h` unless standardizing with `layouts.*`.

**Step 5: Compile and fix build errors**

Run `mixin/build.sh` or `mixin/build.ps1`. Fix any errors.

**Step 6: Verify completeness**

Run verification checks from `references/verification-guide.md`. Ensure panel count, variable count, and row structure match source.

**Step 7: Fix any missing elements**

If verification fails, return to the appropriate step, add missing elements, recompile, and verify again.

## Modernization guidelines

- `graph` -> `timeseries`
- `singlestat` -> `stat`
- Prefer `standards.legend.*` and `themes.timeseries.*`
- Use newer tooltip modes and legend placements

## Manual import support

- Use `${DS_*}` for datasource UID in manual import mode.
- Add `__inputs` and `__requires` so Grafana can prompt for datasources.
- Keep provisioning mode (real UID) as the default line, and comment the manual line.

## UID generation (required)

- Always create a **new** dashboard UID based on the dashboard name.
- Prefer a stable, name-derived UID (e.g., slugified name), and keep it concise (Grafana UID max length is 40).
- Do not carry over the source export UID.

## Row structure preservation

**CRITICAL:** Grafana rows organize panels. Always preserve row structure from source JSON.

Panels belong to a row based on `gridPos.y` coordinate. Set each panel's Y to match its row's Y.

**Example:**
```jsonnet
// Row at Y=0
local overviewRow = panels.rowPanel('Overview', collapsed=true)
+ g.panel.row.gridPos.withY(0)
+ g.panel.row.withPanels([panel1, panel2]);

// Panels at Y=0 belong to overviewRow
local panel1 = panels.statPanel(...)
+ g.panel.stat.gridPos.withY(0);  // Same Y as row
```

For detailed row handling, see `references/full-conversion-playbook.md` section 3.6.

## Minimal structure (single file)

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local helpers = import '../lib/helpers.libsonnet';
local layouts = import '../lib/layouts.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

// Provisioning mode (real UID). For manual import, switch to ${DS_*}.
local DATASOURCE_UID = 'prometheus-thanos';
// local DATASOURCE_UID = '${DS_PROMETHEUS}';

local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  pluginVersion: '12.3.0',
  timezone: 'browser',
  timeFrom: 'now-6h',
  timeTo: 'now',
};

local qpsStat = panels.statPanel(
  title='QPS',
  targets=[prom.instantTarget('sum(rate(http_requests_total[1m]))', '')],
  datasource=config.datasource,
  unit=standards.units.qps,
  pluginVersion=config.pluginVersion
);

g.dashboard.new('Dashboard Name')
+ g.dashboard.withUid('dashboard-name')
+ g.dashboard.withPanels([qpsStat])
```

## Handling complex configs

- For unsupported panel types, use Grafonnet directly and still apply `standards.units.*` and `standards.thresholds.*`.
- For advanced options, layer `.with*()` on top of unified constructors.

## Optional scaffold script

`scripts/convert_grafana_json.py` generates a scaffold (entrypoint + lib + raw files).
Use it only as a scratchpad: inline all panels and variables into the single file and delete raw JSON files.

Example:
```bash
python scripts/convert_grafana_json.py \
  --input <export.json> \
  --output-dir <mixin/system> \
  --system <system> \
  --datasource-type <type> \
  --datasource-uid <uid>
```

## Completeness verification

**CRITICAL:** Run verification after conversion to ensure nothing is missing.

Required checks:
- Panel count matches source JSON
- All variables converted and present
- Row structure preserved
- Dashboard renders correctly in Grafana
- Variables return values in Grafana (non-empty dropdowns)
- No duplicate or extra variables
- Regex filters preserved or added where needed
- Row membership verified (panel `gridPos.y` aligns to row `gridPos.y`, and rows include panels)

**For verification scripts and detailed instructions**: See `references/verification-guide.md`

**If verification fails**, return to the appropriate workflow step, fix issues, recompile, and verify again.

## Quality checklist

**Code quality:**
- [ ] All panels use `panels.*Panel()` and helper libs (`prom.*`, `standards.*`, `themes.*`)
- [ ] Units and thresholds use `standards.*`
- [ ] Legacy panels modernized (`graph` -> `timeseries`, `singlestat` -> `stat`)
- [ ] Dashboard UID is regenerated from the dashboard name (no UID reuse)
- [ ] No dashboard-specific lib files or raw JSON panels remain

**Functional completeness:**
- [ ] Panel count matches source JSON (verified with script)
- [ ] All variables converted and present (verified with script)
- [ ] Row structure preserved (panels organized in correct rows)
- [ ] Variables populate with data when dashboard is imported
- [ ] No panels missing compared to source dashboard
- [ ] Build succeeds without errors

## Formatting guardrail

- Do not run `jsonnetfmt` / `jsonnet fmt` on generated Jsonnet files. Keep formatting manual and consistent with grafana-code mixin style.

## References (load as needed)

- `references/full-conversion-playbook.md`
- `references/lib-api-reference.md`
- `references/mapping.md`
- `references/verification-guide.md`
- `references/common-issues.md`
- `references/examples.md`
- `references/style-and-practices.md`
