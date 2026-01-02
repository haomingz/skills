---
name: grafana-json-to-jsonnet
description: This skill should be used when converting Grafana dashboard JSON exports to Jsonnet that matches the grafana-code mixin style. Trigger phrases include "convert grafana json", "grafana export to jsonnet", "import grafana dashboard", "grafana-code integration", "json to jsonnet". CRITICAL REQUIREMENTS: (1) Fully convert to Jsonnet using unified libs, no raw JSON fallback. (2) Produce a single self-contained jsonnet file (no dashboard-specific lib files). (3) Modernize legacy panel types and options. (4) Only update `mixin/lib/*.libsonnet` for truly reusable components.
---

# Grafana JSON Export to Jsonnet

## When to use

- You are given a Grafana export JSON file and need to integrate it into `grafana-code`.

## Trigger phrases (hints)

- "convert grafana json"
- "grafana export to jsonnet"
- "import grafana dashboard"
- "grafana-code integration"
- "json to jsonnet"

## Inputs

- Grafana export JSON file (Grafana UI: Share -> Export)
- Target mixin system folder (for example `mixin/application`)
- Datasource type and UID (for example `prometheus` + `prometheus-thanos`)

## Outputs

- `<output>/<dashboard>.jsonnet` (single self-contained dashboard file)
- Optional updates to `mixin/lib/*.libsonnet` (only for reusable components)

## Critical requirements

1. Convert all panels, variables, and configs to Jsonnet using unified libraries.
2. Produce a single self-contained Jsonnet file (no dashboard-specific lib files).
3. Modernize legacy panel types and deprecated options.
4. Only update `mixin/lib/*.libsonnet` for truly reusable components.

## Non-negotiable rules

- All panel definitions live as `local` variables in the main file.
- No raw JSON fallback files in final output.
- Use unified constructors first, then layer Grafonnet `.with*()` for advanced options.
- Use latest Grafana features when modern equivalents exist.

## Workflow

1. Review conventions (`style-guide.md`, `best-practices.md`, `lib-api-reference.md`).
2. Analyze the export JSON (panel types, variables, datasources, legacy configs).
3. Define a `config` block with datasource, time range, and `pluginVersion`.
4. Convert variables with `g.dashboard.variable.*`.
5. Convert panels as `local` variables using unified constructors (`panels.*`, `prom.*`, `standards.*`, `themes.*`).
6. Assemble the dashboard and add `__inputs` / `__requires` for manual import.
7. Compile and verify with `mixin/build.sh` or `mixin/build.ps1`.

## Modernization guidelines (short)

- `graph` -> `timeseries`
- `singlestat` -> `stat`
- Prefer `standards.legend.*` and `themes.timeseries.*`
- Use newer tooltip modes and legend placements

## Manual import support (recommended)

- Use `${DS_*}` for datasource UID in manual import mode.
- Add `__inputs` and `__requires` so Grafana can prompt for datasources.
- Keep provisioning mode (real UID) as the default line, and comment the manual line.

## Minimal structure (single file)

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panels = import '../lib/panels.libsonnet';
local prom = import '../lib/prometheus.libsonnet';
local standards = import '../lib/standards.libsonnet';
local themes = import '../lib/themes.libsonnet';

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
+ g.dashboard.withPanels([qpsStat])
```

## Handling complex configs

- For unsupported panel types, use Grafonnet directly and still apply `standards.units.*` and `standards.thresholds.*`.
- For advanced options, layer `.with*()` on top of unified constructors.

## Optional scaffold script

`skills/grafana-json-to-jsonnet/scripts/convert_grafana_json.py` generates a scaffold (entrypoint + lib + raw files).
Use it only as a scratchpad: inline all panels and variables into the single file and delete raw JSON files.

Example:
```
python scripts/convert_grafana_json.py \
  --input <export.json> \
  --output-dir <mixin/system> \
  --system <system> \
  --datasource-type <type> \
  --datasource-uid <uid>
```

## Quality checklist

- All panels use `panels.*Panel()` and helper libs (`prom.*`, `standards.*`, `themes.*`).
- Units and thresholds are standardized.
- Legacy panels are modernized (`graph` -> `timeseries`, `singlestat` -> `stat`).
- No dashboard-specific lib files or raw JSON panels remain.

## References (load as needed)

- `references/conversion-guide.md`
- `references/full-conversion-playbook.md`
- `references/style-guide.md`
- `references/best-practices.md`
- `references/lib-api-reference.md`
- `references/mapping.md`
- `references/common-issues.md`
- `examples/grafana-json-to-jsonnet/input-dashboard.json`
- `examples/grafana-json-to-jsonnet/output-dashboard.jsonnet`
