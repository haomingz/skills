# Conversion Guide (Short)

This guide summarizes the conversion workflow. For full details and examples, read `references/full-conversion-playbook.md`.

## Core requirements

- Single self-contained Jsonnet file per dashboard (no dashboard-specific lib files).
- All panels/variables are converted to unified libs, no raw JSON fallback.
- Modernize legacy panel types and options.
- Only update `mixin/lib/*.libsonnet` for truly reusable patterns.
- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.

## Recommended workflow

1. Review conventions in `style-guide.md`, `best-practices.md`, and `lib-api-reference.md`.
2. Audit the export JSON for panel types, variables, datasources, and legacy configs.
3. Create config and datasource blocks (support provisioning UID and manual import mode).
4. Define all panels as `local` variables using `panels.*Panel()` and helpers.
5. Group panels into rows using `panels.rowPanel(...)` or `g.panel.row.new(...)`.
6. Define variables with `g.dashboard.variable.*`.
7. Assemble the dashboard and include `__inputs` / `__requires`.
8. Compile with `mixin/build.sh` or `mixin/build.ps1` and fix issues.

## Optional scaffold script

You can run `scripts/convert_grafana_json.py` to generate a scaffold (entrypoint + lib + raw files).
Use it only as a scratchpad: inline all panels and variables into a single file and delete any raw JSON files.

Example:
```
python scripts/convert_grafana_json.py \
  --input <export.json> \
  --output-dir <mixin/system> \
  --system <system> \
  --datasource-type <type> \
  --datasource-uid <uid>
```

## Quick checks

- All panels use unified constructors (`panels.*`, `prom.*`, `standards.*`).
- Units and thresholds are standardized.
- No dashboard-specific libs remain.
- Variables return values in Grafana; no duplicates or extras.
- Regex filters are preserved (or added where needed).
- Row membership is correct (panel `gridPos.y` aligns to row `gridPos.y` and rows include panels).
