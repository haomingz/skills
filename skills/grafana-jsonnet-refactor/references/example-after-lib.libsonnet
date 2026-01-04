// Example reusable helper for mixin/lib (only if shared across dashboards).
// Do not create dashboard-specific lib files.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local layouts = import './layouts.libsonnet';
local panels = import './panels.libsonnet';
local prom = import './prometheus.libsonnet';
local standards = import './standards.libsonnet';
local themes = import './themes.libsonnet';

{
  qpsPanel(config)::
    panels.timeseriesPanel(
      title='QPS',
      targets=[
        prom.target('sum(rate(http_requests_total[1m]))', 'QPS'),
      ],
      datasource=config.datasource,
      unit=standards.units.qps,
      legendConfig=standards.legend.standard,
      theme=themes.timeseries.standard,
      pluginVersion=config.pluginVersion
    )
    + g.panel.timeSeries.gridPos.withH(layouts.timeseries.small.height)
    + g.panel.timeSeries.gridPos.withW(layouts.timeseries.small.width)
    + g.panel.timeSeries.gridPos.withX(0)
    + g.panel.timeSeries.gridPos.withY(0),

  build(config):: [
    self.qpsPanel(config),
  ],
}
