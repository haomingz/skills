local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local layouts = import '../../lib/layouts.libsonnet';
local panels = import '../../lib/panels.libsonnet';
local prom = import '../../lib/prometheus.libsonnet';
local standards = import '../../lib/standards.libsonnet';
local themes = import '../../lib/themes.libsonnet';

{
  qpsStat(config)::
    panels.statPanel(
      title='QPS',
      targets=[
        prom.instantTarget('sum(rate(http_requests_total[1m]))', ''),
      ],
      datasource=config.datasource,
      unit=standards.units.qps,
      thresholds=standards.thresholds.neutral,
      pluginVersion=config.pluginVersion
    )
    + g.panel.stat.gridPos.withH(layouts.stat.height)
    + g.panel.stat.gridPos.withW(layouts.stat.width)
    + g.panel.stat.gridPos.withX(0)
    + g.panel.stat.gridPos.withY(0),

  qpsTrend(config)::
    panels.timeseriesPanel(
      title='QPS Trend',
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
    + g.panel.timeSeries.gridPos.withY(4),

  build(config):: [
    self.qpsStat(config),
    self.qpsTrend(config),
  ],
}