# Refactor Guide (Short)

Use this guide to refactor a Grafana Jsonnet dashboard while keeping behavior stable. For full details and examples, read `references/full-refactor-playbook.md`.

## Primary goals

- Reduce duplication and improve maintainability.
- Align with grafana-code unified libraries (`panels`, `prom`, `standards`, `themes`, `layouts`).
- Preserve metric semantics and layout intent.

## Decide the structure

- Keep a single file and use local helpers for repeated patterns.
- Only update `mixin/lib/*.libsonnet` when a pattern is truly reusable across dashboards.

## Recommended steps

1. Inventory panels, variables, datasources, and repeated configs.
2. Normalize datasource config and common selectors.
3. Replace raw Grafonnet blocks with unified constructors.
4. Group panels into rows with `panels.rowPanel(...)` or `g.panel.row.new(...)`.
5. Compile and verify (`mixin/build.sh` or `mixin/build.ps1`).

## Common refactor moves

- Consolidate duplicated selectors into `local baseSelector`.
- Replace handwritten PromQL with `prom.*` helpers.
- Standardize units and thresholds via `standards.*`.
- Move repeated panel options into local helpers, or into `mixin/lib/*.libsonnet` if globally reusable.
- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.
