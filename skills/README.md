# Skills 目录

本目录收录所有 Claude Code skill，按领域分为 **Grafana 可观测性** 和 **金融交易** 两组。

每个 skill 采用三层加载：frontmatter 常驻上下文（~100 词）→ SKILL.md 触发时加载 → `references/` 按需读取。

---

## Grafana 可观测性

| Skill | 用途 | 触发短语 |
|-------|------|----------|
| [grafana-json-to-jsonnet](grafana-json-to-jsonnet/SKILL.md) | Grafana UI 导出 JSON 转 Jsonnet（grafana-code mixin 规范） | "convert grafana json", "import grafana dashboard", "grafana JSON 转 Jsonnet" |
| [grafana-jsonnet-refactor](grafana-jsonnet-refactor/SKILL.md) | 重构现有 Jsonnet：消除重复、对齐统一库 | "refactor grafana jsonnet", "split dashboard", "Jsonnet 重构" |
| [grafana-report-to-dashboard](grafana-report-to-dashboard/SKILL.md) | Python 报表脚本（Elasticsearch）迁移为 Grafana 双数据源仪表板 | "migrate report to grafana", "convert python report", "报表转 Grafana" |
| [grafana-dashboard-optimize](grafana-dashboard-optimize/SKILL.md) | 仪表板可观测性审计与优化（RED/USE/Golden Signals） | "optimize grafana dashboard", "dashboard audit", "仪表板优化" |

### Grafana skill 选哪个

```
有 JSON 文件要转 Jsonnet        → grafana-json-to-jsonnet
已有 Jsonnet 需要整理/重构      → grafana-jsonnet-refactor
有 Python 报表脚本要迁移        → grafana-report-to-dashboard
审查仪表板内容质量（RED/USE）   → grafana-dashboard-optimize
```

---

## 金融交易

| Skill | 用途 | 触发短语 |
|-------|------|----------|
| [baostock-data](baostock-data/SKILL.md) | 中国 A 股行情、财务、指数成分、宏观利率（BaoStock） | "baostock", "A股K线", "季度财务指标", "query_history_k_data_plus" |
| [akshare-data](akshare-data/SKILL.md) | A股/港股/美股/期货/基金/宏观多市场数据（AKShare） | "akshare", "A股实时行情", "资金流向", "龙虎榜", "宏观数据" |
| [schwab-trader](schwab-trader/SKILL.md) | Charles Schwab API 美股交易：OAuth、行情、下单、账户查询 | "Schwab API", "schwab-py", "美股 API 下单", "get_price_history", "place_order" |
| [ibkr-trader](ibkr-trader/SKILL.md) | IBKR TWS API 全球多市场交易（ib_async）：实时行情、期货、期权、外汇 | "IBKR API", "ib_async", "IB Gateway", "reqHistoricalData", "qualifyContracts" |

### 金融 skill 选哪个

```
A 股历史行情、季频财务指标      → baostock-data
多市场（A股/港股/美股/宏观）   → akshare-data
美股交易（Schwab 账户）         → schwab-trader
全球多市场交易（IBKR 账户）     → ibkr-trader（TWS API via ib_async）
  ↳ Web API / REST 调用           → 参见 docs/ibkr-api/（无对应 skill）
```

---

## 目录结构

```
skills/{name}/
├── SKILL.md          # 技能定义（frontmatter + 工作流 checklist）
└── references/       # 详细参考文档（API 参考、完整示例、故障排除）
    ├── api-reference.md
    ├── common-recipes.md
    └── ...
```

参考文档组织原则：SKILL.md 只放核心工作流，详细内容下沉到 `references/`，引用深度不超过一层。
