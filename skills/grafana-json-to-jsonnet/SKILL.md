---
name: grafana-json-to-jsonnet
description: Convert Grafana exported dashboard JSON into Jsonnet that matches the grafana-code mixin style (lib split, datasource parameterization, and dashboard metadata). Use when given a Grafana export JSON and asked to integrate it into grafana-code.
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
1. Review `references/style-guide.md` for grafana-code conventions and import order.
2. Run the conversion script to generate a Jsonnet scaffold:
   - `python scripts/convert_grafana_json.py --input <export.json> --output-dir <mixin/system> --system <system> --datasource-type <type> --datasource-uid <uid>`
3. Open the generated Jsonnet and replace TODO sections:
   - Map panel types to `panels.*` builders using `references/mapping.md`.
   - Normalize units and thresholds to `standards.*`.
4. Integrate into `grafana-code`:
   - Place files under `mixin/<system>/` and `mixin/<system>/lib/`.
   - Keep imports pointing to `../lib` and `../../lib` as generated.
   - Compile with `mixin/build.sh` or `mixin/build.ps1` and fix any errors.

## Notes
- The script prioritizes a safe scaffold over a perfect conversion. Unknown panel types are emitted as raw panels for manual handling.
- Use `references/example-input.json` and `references/example-output.jsonnet` as a quick sanity check.