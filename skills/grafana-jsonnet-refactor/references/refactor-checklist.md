# Refactor Checklist

## Structure
- Keep the entrypoint file focused on imports, config, variables, and dashboard assembly.
- Move panel construction and shared logic into `lib/<dashboard>_panels.libsonnet`.

## Libraries
- Use `panels.*` constructors (stat, timeseries, table, etc.).
- Use `standards.units`, `standards.thresholds`, and `themes` for consistent styling.

## Datasource
- Centralize datasource config in the entrypoint with `DATASOURCE_UID` and `config.datasource`.
- Pass `config.datasource` into all `panels.*` calls.

## Layout
- Apply `g.panel.*.gridPos.withH/W/X/Y` consistently.
- Prefer `layouts.*` when standard sizes are acceptable.

## Cleanups
- Remove repeated raw Grafonnet blocks where `panels.*` can be used.
- Normalize units to `standards.units.*`.
- Normalize thresholds to `standards.thresholds.*`.