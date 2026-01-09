# Full Refactor Playbook

This playbook provides detailed steps and patterns for refactoring Grafana Jsonnet dashboards.

## Contents

- [Reference index (load as needed)](#reference-index-load-as-needed)
- [Quick start (summary)](#quick-start-summary)
- [Goals and constraints](#goals-and-constraints)
- [Step 1: Audit the current dashboard](#step-1-audit-the-current-dashboard)
- [Step 2: Decide the structure](#step-2-decide-the-structure)
- [Step 3: Normalize config and selectors](#step-3-normalize-config-and-selectors)
- [Step 4: Extract local helpers](#step-4-extract-local-helpers)
- [Step 5: Keep the file organized](#step-5-keep-the-file-organized)
- [Step 6: Replace raw Grafonnet blocks](#step-6-replace-raw-grafonnet-blocks)
- [Step 7: Multi-datasource refactor (when needed)](#step-7-multi-datasource-refactor-when-needed)
- [Step 8: Verify behavior](#step-8-verify-behavior)
- [Quality checks](#quality-checks)

---

## Reference index (load as needed)

- `references/refactor-checklist.md` - quick checklist for conventions and validation.
- `references/examples.md` - before/after examples and optional lib helper.
- `references/visual-style-guides.md` - style/threshold/table conventions.

## Quick start (summary)

1. Review conventions in `references/refactor-checklist.md`.
2. Inventory panels, variables, datasources, and row structure.
3. Normalize config and shared selectors.
4. Replace raw Grafonnet with unified `panels.*` constructors.
5. Preserve layout and row membership (`gridPos.y` matches row `gridPos.y`).
6. Compile and verify behavior in Grafana.

## Goals and constraints

- Preserve metrics and layout behavior.
- Reduce duplication and align with unified libraries.
- Keep changes focused; avoid wide rewrites.
- Only update `mixin/lib/*.libsonnet` if a pattern is reusable across dashboards.
- Do not run `jsonnet fmt` / `jsonnetfmt` on generated Jsonnet files.

## Step 1: Audit the current dashboard

Capture:
- Panel list and types
- Variables and their queries
- Datasource usage (single or multiple)
- Repeated query patterns or panel options
- Layout intent and row structure

## Step 2: Decide the structure

- Keep a single file and use local helpers or wrapper functions for repeated patterns.
- Only update `mixin/lib/*.libsonnet` if a pattern is reusable across dashboards.

## Step 3: Normalize config and selectors

Create a `config` object for:
- `datasource` or `datasources` (multi-backend)
- `timezone`, `timeFrom`, `timeTo`, `pluginVersion`
- Shared selectors (label filters, time ranges)

Example:

```jsonnet
local config = {
  datasource: { type: 'prometheus', uid: DATASOURCE_UID },
  pluginVersion: '12.3.0',
};

local baseSelector = '{job="api",env="prod"}';
```

## Step 4: Extract local helpers

- Create local helper functions for repeated panel patterns.
- Wrap unified library constructors (`panels.*`, `prom.*`) and add `id/gridPos` via `panels.withIdAndPatches(...)`.
- Keep helpers in the same file; avoid dashboard-specific libs.

Example local helper:

```jsonnet
local httpRatePanel(title, expr, id, gridPos) =
  panels.withIdAndPatches(
    panels.timeseriesPanel(
      title=title,
      targets=[prom.target(expr, 'QPS')],
      datasource=config.datasource,
      unit=standards.units.qps,
      theme=themes.timeseries.standard,
      pluginVersion=config.pluginVersion
    ),
    id=id,
    gridPos=gridPos
  );
```

## Step 5: Keep the file organized

Recommended order:
- imports → config → constants → helpers → panels → rows → variables → dashboard

## Step 6: Replace raw Grafonnet blocks

- For each panel, prefer unified constructors.
- Layer Grafonnet `.with*()` methods for advanced options.
- Normalize units and thresholds with `standards.*`.

## Step 7: Multi-datasource refactor (when needed)

If a dashboard uses multiple backends:

```jsonnet
local config = {
  datasources: {
    prometheus: { type: 'prometheus', uid: PROM_UID },
    elasticsearch: { type: 'elasticsearch', uid: ES_UID },
  },
  pluginVersion: '12.3.0',
};
```

Pass the correct datasource into each panel constructor and keep targets consistent.

## Step 8: Verify behavior

- Compile with `mixin/build.sh` or `mixin/build.ps1`.
- Check variable interaction, panel rendering, and layout.
- Compare metrics and calculations with the original dashboard.
- Verify variables return values (no duplicates, regex preserved).
- Verify row membership (panel `gridPos.y` aligns to row `gridPos.y`, and rows include panels).

## Common pitfalls

- Moving dashboard-specific panels into `mixin/lib/`.
- Creating dashboard-specific lib files instead of local helpers.
- Changing query semantics while refactoring.
- Leaving duplicated selectors across panels.
- Losing row collapse/expand behavior.
- Changing default time range or refresh unintentionally.
