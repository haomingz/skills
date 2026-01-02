# Refactor Guide (Short)

Use this guide to refactor a Grafana Jsonnet dashboard while keeping behavior stable. For full details and examples, read `references/full-refactor-playbook.md`.

## Primary goals

- Reduce duplication and improve maintainability.
- Align with grafana-code unified libraries (`panels`, `prom`, `standards`, `themes`, `layouts`).
- Preserve metric semantics and layout intent.

## Decide the structure

- Keep a single file if the dashboard is small and has minimal repetition.
- Split into entrypoint + `lib/<dashboard>_panels.libsonnet` if there are many panels, repeated patterns, or shared selectors.

## Recommended steps

1. Inventory panels, variables, datasources, and repeated configs.
2. Normalize datasource config and common selectors.
3. Extract panel builders and shared helpers into lib when needed.
4. Replace raw Grafonnet blocks with unified constructors.
5. Compile and verify (`mixin/build.sh` or `mixin/build.ps1`).

## Common refactor moves

- Consolidate duplicated selectors into `local baseSelector`.
- Replace handwritten PromQL with `prom.*` helpers.
- Standardize units and thresholds via `standards.*`.
- Move repeated panel options into shared helpers (lib) if splitting.
