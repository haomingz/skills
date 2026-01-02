// Example before refactor (monolithic)
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local DATASOURCE_UID = 'prometheus-thanos';
local datasource = { type: 'prometheus', uid: DATASOURCE_UID };

local qpsPanel = g.panel.timeSeries.new('QPS')
  + g.panel.timeSeries.queryOptions.withDatasource(
    type=datasource.type,
    uid=datasource.uid
  )
  + g.panel.timeSeries.queryOptions.withTargets([
    { expr: 'sum(rate(http_requests_total[1m]))', legendFormat: 'QPS', refId: 'A' },
  ])
  + g.panel.timeSeries.gridPos.withH(6)
  + g.panel.timeSeries.gridPos.withW(8)
  + g.panel.timeSeries.gridPos.withX(0)
  + g.panel.timeSeries.gridPos.withY(0);

g.dashboard.new('Example')
+ g.dashboard.withUid('example')
+ g.dashboard.withPanels([qpsPanel])