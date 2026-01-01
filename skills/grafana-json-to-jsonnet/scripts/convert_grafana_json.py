#!/usr/bin/env python
"""Convert Grafana export JSON into a grafana-code-style Jsonnet scaffold.

This script intentionally generates a safe scaffold, not a perfect conversion.
Unknown panel types or targets are emitted as raw panels for manual cleanup.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Tuple

UNIT_MAP = {
    "reqps": "standards.units.qps",
    "percentunit": "standards.units.percent01",
    "percent": "standards.units.percent100",
    "s": "standards.units.seconds",
    "ms": "standards.units.milliseconds",
    "bytes": "standards.units.bytes",
    "short": "standards.units.count",
}

PANEL_MAP = {
    "timeseries": ("timeseriesPanel", "timeSeries"),
    "stat": ("statPanel", "stat"),
    "table": ("tablePanel", "table"),
    "bargauge": ("barGaugePanel", "barGauge"),
    "piechart": ("pieChartPanel", "pieChart"),
    "row": ("rowPanel", "row"),
}


def slugify(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text or "dashboard"


def load_dashboard(path: Path) -> Dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict) and "dashboard" in data:
        return data["dashboard"]
    return data


def pick_datasource_uid(dashboard: Dict[str, Any], fallback: str) -> str:
    for item in dashboard.get("__inputs", []) or []:
        if item.get("type") == "datasource" and item.get("name"):
            return f"${{{item['name']}}}"
    return fallback


def json_string(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True)


def normalize_unit(unit: str | None) -> str | None:
    if not unit:
        return None
    return UNIT_MAP.get(unit)


def detect_panel_datasource(panel: Dict[str, Any], default_type: str) -> str:
    ds = panel.get("datasource")
    if isinstance(ds, dict) and ds.get("type"):
        return str(ds.get("type"))
    if isinstance(ds, str):
        return ds
    return default_type


def render_targets(panel: Dict[str, Any], datasource_type: str) -> Tuple[List[str], bool]:
    targets = panel.get("targets", []) or []
    rendered: List[str] = []
    for target in targets:
        if not isinstance(target, dict):
            return [], False
        ref_id = target.get("refId", "A")
        if "rawSql" in target:
            sql = str(target.get("rawSql", ""))
            rendered.append(
                "clickhouse.sqlTarget(\n"
                f"  config.datasource,\n  |||\n{sql}\n  |||,\n  refId={json_string(ref_id)}\n)"
            )
            continue
        if "expr" in target:
            expr = str(target.get("expr", ""))
            legend = str(target.get("legendFormat", ""))
            if panel.get("type") == "stat":
                rendered.append(f"prom.instantTarget({json_string(expr)}, {json_string(legend)})")
            elif panel.get("type") == "table":
                rendered.append(f"prom.tableTarget({json_string(expr)}, {json_string(legend)})")
            else:
                rendered.append(f"prom.target({json_string(expr)}, {json_string(legend)})")
            continue
        # Unsupported target type
        return [], False

    if datasource_type.lower().find("elasticsearch") >= 0:
        return [], False
    return rendered, True


def render_variable(var: Dict[str, Any]) -> Tuple[str | None, bool]:
    var_type = var.get("type")
    name = var.get("name")
    query = var.get("query")
    label = var.get("label")

    if not name:
        return None, False

    if var_type == "query" and isinstance(query, str):
        lines = [
            f"local {name}Variable = g.dashboard.variable.query.new(",
            f"  {json_string(name)},",
            f"  {json_string(query)}",
            ")",
            "+ g.dashboard.variable.query.withDatasource(",
            "  type=config.datasource.type,",
            "  uid=config.datasource.uid",
            ")",
        ]
        if label:
            lines.append(f"+ g.dashboard.variable.query.generalOptions.withLabel({json_string(label)})")
        if var.get("includeAll"):
            lines.append("+ g.dashboard.variable.query.selectionOptions.withIncludeAll(true)")
        if var.get("multi"):
            lines.append("+ g.dashboard.variable.query.selectionOptions.withMulti(true)")
        if var.get("refresh"):
            lines.append("+ g.dashboard.variable.query.refresh.onLoad()")
        if var.get("sort") is not None:
            lines.append(f"+ g.dashboard.variable.query.withSort({int(var.get('sort'))})")
        return "\n".join(lines) + ";", True

    if var_type == "custom" and isinstance(query, str):
        options = [opt.strip() for opt in query.split(",") if opt.strip()]
        options_list = ", ".join(json_string(opt) for opt in options)
        lines = [
            f"local {name}Variable = g.dashboard.variable.custom.new(",
            f"  {json_string(name)},",
            f"  [{options_list}]",
            ")",
        ]
        if label:
            lines.append(f"+ g.dashboard.variable.custom.withLabel({json_string(label)})")
        return "\n".join(lines) + ";", True

    if var_type == "interval" and isinstance(query, str):
        values = [v.strip() for v in query.split(",") if v.strip()]
        values_list = ", ".join(json_string(v) for v in values)
        lines = [
            f"local {name}Variable = g.dashboard.variable.interval.new(",
            f"  {json_string(name)},",
            f"  [{values_list}]",
            ")",
        ]
        if label:
            lines.append(f"+ g.dashboard.variable.interval.withLabel({json_string(label)})")
        return "\n".join(lines) + ";", True

    return None, False


def render_panel_function(panel: Dict[str, Any], default_ds_type: str) -> Tuple[str, bool]:
    panel_type = panel.get("type")
    panel_id = panel.get("id")
    title = panel.get("title", f"panel-{panel_id}")
    grid = panel.get("gridPos", {}) or {}

    mapped = PANEL_MAP.get(panel_type)
    if not mapped:
        return f"  panel_{panel_id}(config):: rawPanels[{json_string(str(panel_id))}],", False

    builder_name, grafonnet_panel = mapped
    if panel_type == "row":
        collapsed = bool(panel.get("collapsed", False))
        child_panels = panel.get("panels", []) or []
        child_calls = [f"self.panel_{child.get('id')}(config)" for child in child_panels if child.get("id")]
        child_block = "" if not child_calls else (
            "\n    + g.panel.row.withPanels([\n      "
            + ",\n      ".join(child_calls)
            + "\n    ])"
        )
        return (
            f"  panel_{panel_id}(config)::\n"
            f"    panels.rowPanel({json_string(title)}, collapsed={str(collapsed).lower()})"
            f"{child_block},",
            True,
        )

    panel_ds_type = detect_panel_datasource(panel, default_ds_type)
    targets, ok = render_targets(panel, panel_ds_type)
    if not ok:
        return f"  panel_{panel_id}(config):: rawPanels[{json_string(str(panel_id))}],", False

    unit = normalize_unit(panel.get("fieldConfig", {}).get("defaults", {}).get("unit"))
    unit_line = f"unit={unit}," if unit else ""

    targets_block = "\n      ".join([",\n        ".join([t]) for t in targets])
    panel_lines = [
        f"  panel_{panel_id}(config)::",
        f"    panels.{builder_name}(",
        f"      title={json_string(title)},",
        "      targets=[",
        f"        {',\n        '.join(targets)},",
        "      ],",
        "      datasource=config.datasource,",
    ]
    if unit_line:
        panel_lines.append(f"      {unit_line}")
    panel_lines.append("      pluginVersion=config.pluginVersion")
    panel_lines.append("    )")

    if grid:
        h = int(grid.get("h", 6))
        w = int(grid.get("w", 8))
        x = int(grid.get("x", 0))
        y = int(grid.get("y", 0))
        panel_lines.append(f"    + g.panel.{grafonnet_panel}.gridPos.withH({h})")
        panel_lines.append(f"    + g.panel.{grafonnet_panel}.gridPos.withW({w})")
        panel_lines.append(f"    + g.panel.{grafonnet_panel}.gridPos.withX({x})")
        panel_lines.append(f"    + g.panel.{grafonnet_panel}.gridPos.withY({y})")

    panel_lines[-1] += ","
    return "\n".join(panel_lines), True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Path to Grafana export JSON")
    parser.add_argument("--output-dir", required=True, help="Output directory (e.g. mixin/application)")
    parser.add_argument("--system", required=True, help="System name (e.g. application)")
    parser.add_argument("--datasource-type", default="prometheus", help="Datasource type")
    parser.add_argument("--datasource-uid", default=None, help="Datasource UID")
    parser.add_argument("--slug", default=None, help="Override dashboard slug")
    args = parser.parse_args()

    dashboard = load_dashboard(Path(args.input))
    title = str(dashboard.get("title", "Dashboard"))
    uid = dashboard.get("uid")
    slug = args.slug or slugify(title)

    ds_uid = args.datasource_uid or pick_datasource_uid(dashboard, "${DS_PROMETHEUS}")
    ds_type = args.datasource_type

    output_dir = Path(args.output_dir)
    lib_dir = output_dir / "lib"
    output_dir.mkdir(parents=True, exist_ok=True)
    lib_dir.mkdir(parents=True, exist_ok=True)

    raw_panels = {}
    panels = dashboard.get("panels", []) or []

    child_ids = set()
    for panel in panels:
        if panel.get("type") == "row" and panel.get("panels"):
            for child in panel.get("panels") or []:
                if child.get("id"):
                    child_ids.add(child.get("id"))

    panel_defs: List[str] = []
    panel_refs: List[str] = []

    for panel in panels:
        panel_id = panel.get("id")
        if panel_id is None:
            continue
        raw_panels[str(panel_id)] = panel
        panel_def, _ = render_panel_function(panel, ds_type)
        panel_defs.append(panel_def)
        if panel_id not in child_ids:
            panel_refs.append(f"self.panel_{panel_id}(config)")

    raw_panels_path = lib_dir / f"{slug}_raw_panels.json"
    raw_panels_path.write_text(json.dumps(raw_panels, ensure_ascii=True, indent=2), encoding="utf-8")

    variables = dashboard.get("templating", {}).get("list", []) or []
    variable_defs: List[str] = []
    raw_variables: List[Dict[str, Any]] = []
    variable_refs: List[str] = []
    for var in variables:
        rendered, ok = render_variable(var)
        if ok and rendered:
            variable_defs.append(rendered)
            variable_refs.append(f"{var.get('name')}Variable")
        else:
            raw_variables.append(var)

    raw_vars_path = lib_dir / f"{slug}_raw_variables.json"
    raw_vars_path.write_text(json.dumps(raw_variables, ensure_ascii=True, indent=2), encoding="utf-8")

    panels_lib = "\n".join([
        "local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';",
        "local layouts = import '../../lib/layouts.libsonnet';",
        "local panels = import '../../lib/panels.libsonnet';",
        "local prom = import '../../lib/prometheus.libsonnet';",
        "local standards = import '../../lib/standards.libsonnet';",
        "local themes = import '../../lib/themes.libsonnet';",
        "local clickhouse = import '../../lib/clickhouse.libsonnet';",
        f"local rawPanels = import './{slug}_raw_panels.json';",
        "",
        "{",
        "".join(["\n" + d for d in panel_defs]),
        "",
        "  build(config):: [",
        f"    {',\n    '.join(panel_refs)}",
        "  ],",
        "}",
        "",
    ])

    (lib_dir / f"{slug}_panels.libsonnet").write_text(panels_lib, encoding="utf-8")

    tags = dashboard.get("tags", []) or []
    refresh = dashboard.get("refresh")
    timezone = dashboard.get("timezone", "browser")
    time_from = dashboard.get("time", {}).get("from", "now-6h")
    time_to = dashboard.get("time", {}).get("to", "now")

    variable_section = "\n".join(variable_defs) if variable_defs else ""
    variables_list = ",\n  ".join(variable_refs)
    if variables_list:
        variables_list = f"[\n  {variables_list},\n] + rawVariables"
    else:
        variables_list = "rawVariables"

    dashboard_lines = [
        f"// {title} (generated scaffold)",
        "",
        "local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';",
        f"local panelsLib = import './lib/{slug}_panels.libsonnet';",
        f"local rawVariables = import './lib/{slug}_raw_variables.json';",
        "",
        f"local DATASOURCE_UID = {json_string(ds_uid)};",
        "// local DATASOURCE_UID = '${DS_PROMETHEUS}';",
        "",
        "local config = {",
        "  datasource: {",
        f"    type: {json_string(ds_type)},",
        "    uid: DATASOURCE_UID,",
        "  },",
        f"  timezone: {json_string(timezone)},",
        f"  timeFrom: {json_string(time_from)},",
        f"  timeTo: {json_string(time_to)},",
        "  pluginVersion: '12.3.0',",
        "};",
        "",
        "// -------------------- Variables --------------------",
        "",
        variable_section,
        "",
        f"local variables = {variables_list};",
        "",
        "// -------------------- Dashboard --------------------",
        "",
        f"g.dashboard.new({json_string(title)})",
    ]

    if uid:
        dashboard_lines.append(f"+ g.dashboard.withUid({json_string(uid)})")
    if tags:
        dashboard_lines.append(f"+ g.dashboard.withTags({json_string(tags)})")

    dashboard_lines.extend([
        "+ g.dashboard.withTimezone(config.timezone)",
        "+ g.dashboard.time.withFrom(config.timeFrom)",
        "+ g.dashboard.time.withTo(config.timeTo)",
    ])

    if refresh:
        dashboard_lines.append(f"+ g.dashboard.withRefresh({json_string(refresh)})")

    dashboard_lines.extend([
        "+ g.dashboard.withVariables(variables)",
        "+ g.dashboard.withPanels(panelsLib.build(config))",
        "",
    ])

    (output_dir / f"{slug}.jsonnet").write_text("\n".join([line for line in dashboard_lines if line is not None]), encoding="utf-8")


if __name__ == "__main__":
    main()