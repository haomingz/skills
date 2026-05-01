---
name: akshare-data
description: 使用 AKShare Python 库获取多市场金融数据（30+ 数据类别）。当需要编写 Python 代码获取以下数据时使用：A股历史K线（stock_zh_a_hist）、A股实时行情、A股分钟线、资金流向（stock_individual_fund_flow）、涨停池（stock_zt_pool_em）、龙虎榜（stock_lhb_detail_em）、财务三大报表（stock_profit_sheet_by_report_em）、股东数据（stock_gdfx_top_10_em）、港股/美股历史数据、期货主力连续（futures_main_sina）、基金净值（fund_open_fund_info_em）、宏观经济指标（CPI/PPI/PMI/M2/GDP/LPR/SHIBOR/美国宏观）、行业/概念板块、可转债（bond_zh_cov_daily）、期权。无需注册或登录，返回中文列名的 pandas DataFrame。
requirements:
  - akshare
  - pandas
allowed-tools:
  - Bash(python:*)
  - Read
---

# AKShare 多市场金融数据获取

使用 `akshare` 获取 A股/港股/美股/期货/基金/宏观/加密货币等数据。**无需登录**，直接调用函数，返回中文列名的 pandas DataFrame。

**不适用于**：实时逐笔数据（tick 精度不足）、纯 A 股季频财务报表（BaoStock 更完整）、非 Python 环境。

---

## 安装与验证

```bash
pip install akshare --upgrade        # 最低版本：1.18+
python -c "import akshare as ak; print(ak.__version__)"
```

遇到 `JSONDecodeError`/`KeyError` 等奇怪报错时先升级：依赖的东财/雪球等第三方接口频繁变动。函数签名有疑问时查官方文档：`https://akshare.akfamily.xyz/`

---

## 核心使用模式

无需 login/logout，直接调用函数：

```python
import akshare as ak
import pandas as pd

df = ak.stock_zh_a_hist(
    symbol="000001",        # 6位纯数字，无市场前缀
    period="daily",         # daily/weekly/monthly
    start_date="20240101",  # ⚠️ YYYYMMDD（8位）
    end_date="20241231",
    adjust="qfq"            # qfq=前复权  hfq=后复权  ""=不复权
)
```

### ⚠️ 接口性能分级（关键）

查单只股票时**必须用个股接口**，严禁用全市场接口筛选：

| 接口类型 | 示例 | 耗时 |
|---------|------|------|
| 个股盘口 | `stock_bid_ask_em(symbol="000001")` | ~3s |
| 个股K线 | `stock_zh_a_hist(symbol="000001", ...)` | ~5s |
| 个股资金流 | `stock_individual_fund_flow(stock="000001", market="sz")` | ~3s |
| 沪A实时 | `stock_sh_a_spot_em()` | ~28s |
| 全A实时 ❌慢 | `stock_zh_a_spot_em()` | ~70s |

全市场接口（`stock_zh_a_spot_em`）仅在需要扫描全市场时使用，不要用它查单股信息。

### 与 BaoStock 关键差异

| 特性 | AKShare | BaoStock |
|------|---------|----------|
| 登录/登出 | 不需要 | 必须 |
| 股票代码 | `"000001"`（6位数字）| `"sz.000001"`（含市场前缀）|
| 日期格式 | `"20240101"`（YYYYMMDD）| `"2024-01-01"`（YYYY-MM-DD）|
| 列名 | 中文（"收盘", "成交量"）| 英文（"close", "volume"）|
| 数值类型 | 已自动转换 | 全部字符串，需手动转换 |
| 实时行情 | 支持 | 不支持 |
| 市场覆盖 | A股/港股/美股/期货/加密/宏观 | 主要 A 股 |

---

## 数据获取流程 checklist

```
AKShare 任务进度：
- [ ] 第1步：选择正确 API 级别（个股 vs 全市场，见上表）
- [ ] 第2步：确认股票代码为 6 位纯数字（无 sh./sz. 前缀）
- [ ] 第3步：日线/指数日期为 YYYYMMDD；分钟线日期为 YYYY-MM-DD HH:MM:SS
- [ ] 第4步：调用 API，检查 df.empty 并打印 df.columns
- [ ] 第5步：批量查询时加入 time.sleep(0.5~1.0)
- [ ] 第6步：中文列名按需 rename 为英文
```

---

## API 速查表

### 行情数据

| 需求 | API |
|------|-----|
| A股日/周/月K线 | `stock_zh_a_hist(symbol, period, start_date, end_date, adjust)` |
| 全A实时（慢~70s）| `stock_zh_a_spot_em()` |
| 沪A实时（~28s）| `stock_sh_a_spot_em()` |
| 深A/创业板/科创板实时 | `stock_sz_a_spot_em()` / `stock_cy_a_spot_em()` / `stock_kc_a_spot_em()` |
| 北证A股实时 | `stock_bj_a_spot_em()` |
| 个股盘口（五档）| `stock_bid_ask_em(symbol)` |
| 个股基本信息 | `stock_individual_info_em(symbol)` |
| A股分钟线 | `stock_zh_a_hist_min_em(symbol, period, start_date, end_date, adjust)` |
| 港股日线 | `stock_hk_hist(symbol, period, start_date, end_date, adjust)` |
| 港股分钟线 | `stock_hk_hist_min_em(symbol, period, start_date, end_date)` |
| 美股日线 | `stock_us_hist(symbol, period, start_date, end_date, adjust)` |
| 美股分钟线 | `stock_us_hist_min_em(symbol, period, start_date, end_date)` |
| A股指数历史 | `index_zh_a_hist(symbol, period, start_date, end_date)` |
| 指数成分股（带权重）| `index_stock_cons_csindex(symbol)` |
| 指数成分股权重 | `index_stock_cons_weight_csindex(symbol)` |

### 板块分析

| 需求 | API |
|------|-----|
| 行业板块列表 | `stock_board_industry_name_em()` |
| 行业板块成分 | `stock_board_industry_cons_em(symbol)` |
| 行业板块历史K线 | `stock_board_industry_hist_em(symbol, period, start_date, end_date)` |
| 概念板块列表 | `stock_board_concept_name_em()` |
| 概念板块成分 | `stock_board_concept_cons_em(symbol)` |
| 概念板块历史K线 | `stock_board_concept_hist_em(symbol, period, start_date, end_date)` |
| 行业资金流 | `stock_fund_flow_industry(indicator)` |
| 概念资金流 | `stock_fund_flow_concept(indicator)` |

### 资金流向

| 需求 | API |
|------|-----|
| 个股资金流（今日）| `stock_individual_fund_flow(stock, market)` |
| 个股资金流排名 | `stock_individual_fund_flow_rank(indicator)` |
| 个股资金流历史 | `stock_fund_flow_individual(stock, market)` |
| 大盘资金流 | `stock_market_fund_flow()` |
| 沪深港通北向 | `stock_hsgt_hist_em(symbol)` |

### 选股工具

| 需求 | API |
|------|-----|
| 涨停池 | `stock_zt_pool_em(date)` |
| 跌停池 | `stock_zt_pool_dtgc_em(date)` |
| 强势股池 | `stock_zt_pool_strong_em(date)` |
| 昨日涨停 | `stock_zt_pool_previous_em(date)` |
| 龙虎榜明细 | `stock_lhb_detail_em(start_date, end_date)` |
| 融资融券（沪）| `stock_margin_sse(start_date, end_date)` |
| 融资融券（深）| `stock_margin_szse(date)` |

### 财务数据

| 需求 | API |
|------|-----|
| 财务摘要（同花顺）| `stock_financial_abstract_ths(symbol, indicator)` |
| 利润表 | `stock_profit_sheet_by_report_em(symbol)` |
| 资产负债表 | `stock_balance_sheet_by_report_em(symbol)` |
| 现金流量表 | `stock_cash_flow_sheet_by_report_em(symbol)` |
| 业绩报表 | `stock_yjbb_em(date)` |
| 业绩预告 | `stock_yjyg_em(date)` |
| 分红配送 | `stock_fhps_em(symbol)` |

### 股东与公司

| 需求 | API |
|------|-----|
| 十大流通股东 | `stock_gdfx_free_top_10_em(symbol)` |
| 十大股东 | `stock_gdfx_top_10_em(symbol)` |
| 股东户数 | `stock_zh_a_gdhs(symbol)` |
| 机构持仓 | `stock_institute_hold(symbol)` |
| 限售解禁 | `stock_restricted_release_queue_em()` |

### 市场宏观（中国）

| 需求 | API |
|------|-----|
| 全A市净率/市盈率 | `stock_a_all_pb()` / `stock_a_ttm_lyr()` |
| CPI 月度（NBS）| `macro_china_cpi()` |
| CPI 同比（Jin10）| `macro_china_cpi_yearly()` |
| PPI 月度（NBS）| `macro_china_ppi()` |
| PPI 同比（Jin10）| `macro_china_ppi_yearly()` |
| PMI 制造业 | `macro_china_pmi_yearly()` |
| M2 货币供应 | `macro_china_m2_yearly()` |
| GDP 季度 | `macro_china_gdp()` |
| LPR 贷款基础利率 | `macro_china_lpr()` |
| SHIBOR 同业拆借 | `macro_china_shibor_all()` |
| 外汇储备 | `macro_china_fx_reserves_yearly()` |
| 固定资产投资 | `macro_china_fixed_asset_investment_yoy()` |
| 社会消费品零售 | `macro_china_retail_sales_yoy()` |
| 工业增加值 | `macro_china_industrial_production_yoy()` |
| 进出口（贸易差额）| `macro_china_trade_all()` |

### 市场宏观（美国）

| 需求 | API |
|------|-----|
| 美国 CPI | `macro_usa_cpi_monthly()` |
| 美国 PMI | `macro_usa_pmi()` |
| 美国 GDP | `macro_usa_gdp_monthly()` |
| 美国非农就业 | `macro_usa_non_farm()` |
| 美联储利率决议 | `macro_usa_interest_rate()` |

### ETF

| 需求 | API |
|------|-----|
| ETF 全市场实时行情（含 IOPV/折价率/资金流）| `fund_etf_spot_em()` |
| ETF 历史K线（日/周/月）| `fund_etf_hist_em(symbol, period, start_date, end_date, adjust)` |
| ETF 分钟线 | `fund_etf_hist_min_em(symbol, period, start_date, end_date, adjust)` |
| ETF 列表（新浪，含市价）| `fund_etf_category_sina(symbol="ETF基金")` |
| ETF 历史净值（单只）| `fund_etf_fund_info_em(fund, start_date, end_date)` |
| 全部基金列表（含类型）| `fund_name_em()` |

ETF 代码格式：6位数字，无市场前缀；沪市 `51xxxx`（如 `510300`），深市 `15xxxx`（如 `159919`）

### 其他市场

| 需求 | API |
|------|-----|
| 期货主力连续 | `futures_main_sina(symbol, start_date, end_date)` |
| 期货品种映射 | `futures_display_main_sina()` |
| 开放式基金净值 | `fund_open_fund_info_em(fund, indicator)` |
| 基金列表 | `fund_open_fund_daily_em()` |
| 可转债实时行情 | `bond_zh_cov()` |
| 可转债历史K线 | `bond_zh_cov_daily(symbol)` |
| 期权实时行情 | `option_current_em(symbol)` |
| 加密货币 BTC K线 | `crypto_binance_btc_usdt_kline(period)` |
| 外汇（美元/人民币）| `forex_usd_cny()` |

---

## 最小代码骨架

```python
import akshare as ak
import pandas as pd
import time

# A股日线（前复权）
df = ak.stock_zh_a_hist(
    symbol="000001",          # 6位数字
    period="daily",
    start_date="20240101",    # YYYYMMDD
    end_date="20241231",
    adjust="qfq"
)
assert not df.empty, "返回空 DataFrame，检查代码或日期"

# 列名：日期 股票代码 开盘 收盘 最高 最低 成交量 成交额 振幅 涨跌幅 涨跌额 换手率
df = df.rename(columns={
    "日期": "date", "收盘": "close", "开盘": "open",
    "最高": "high", "最低": "low", "成交量": "volume",
    "涨跌幅": "pct_chg", "换手率": "turnover"
})
```

---

## 常见陷阱

1. **日期格式 YYYYMMDD** — 日线/指数/期货传入 `"2024-01-01"` 会报错，必须用 `"20240101"`

2. **分钟线日期格式不同** — `stock_zh_a_hist_min_em` 的日期用 `"YYYY-MM-DD HH:MM:SS"` 格式

3. **6 位纯数字代码** — 不含 `sh.`/`sz.` 前缀；资金流向接口还需传入 `market="sz"` 或 `market="sh"`

4. **东财 IP 封锁** — 批量查询必须限速；正常 `time.sleep(0.5)`，遭遇封锁后改为 `2~3s`

5. **列名为中文** — 用 `df["收盘"]` 访问，不能用 `df["close"]`；需下游处理时用 `rename()` 转换

6. **版本更新频繁** — 接口变动后旧版本抛 `JSONDecodeError`/`KeyError`；先 `pip install akshare --upgrade`

7. **分钟线历史深度有限** — 1 分钟线只有近 5 个交易日，5~60 分钟线一般近 120 个交易日；`period="1"` 时 `adjust` 无效

8. **全市场接口极慢** — `stock_zh_a_spot_em()` 约 70s；单股查询绝不用全市场接口

9. **期货代码用 Sina 命名** — 螺纹钢主力是 `"RB"`，不是 `"rb2510"`；先调 `futures_display_main_sina()` 获取映射

10. **退市股/非交易日静默返回空** — 每次查询后检查 `df.empty`，记录日志，不要假设数据存在

11. **资金流向需传 market 参数** — `stock_individual_fund_flow(stock="000001", market="sz")`；市场标识：沪市主板 `"sh"`，深市/创业板 `"sz"`

12. **数据源后缀影响字段和稳定性** — 同一数据类型有多个数据源变体，列名和覆盖深度不同：
    - `_em`（东方财富）：A股行情首选，字段最全，但有 IP 封锁风险
    - `_ths`（同花顺）：财务数据的替代源，部分接口比东财稳定
    - `_xq`（雪球）：公司概况、持仓数据，字段与 `_em` 不同，不能互换
    - `_sina`（新浪）：较老数据源，历史更深，部分接口更稳定（如 `futures_main_sina`）
    遇到 `_em` 接口封锁时，优先找同名 `_ths` 或 `_xq` 版本作为备用。

---

## AI Agent 操作策略

**1. 优先个股接口，按需才用全市场**
单股任务用 `stock_individual_info_em`、`stock_zh_a_hist`、`stock_bid_ask_em`；只有真正需要扫描全市场时才用 `stock_zh_a_spot_em()`。

**2. 验证数据非空**
每次查询后检查 `df.empty` 和 `df.columns`；代码错误/退市/非交易日均静默返回空，需记录日志而非忽略。

**3. 多维度组合分析**
典型量化链路：`stock_board_industry_cons_em()` 筛板块成分 → `stock_zh_a_hist()` 取K线 → `stock_individual_fund_flow()` 确认资金 → `stock_gdfx_free_top_10_em()` 查股东 → `macro_china_*` 宏观辅助。

---

## 质量 checklist

- [ ] 日线/指数/期货日期格式为 `YYYYMMDD`
- [ ] 分钟线日期格式为 `YYYY-MM-DD HH:MM:SS`
- [ ] 股票代码为 6 位纯数字（无市场前缀）
- [ ] `adjust` 参数已明确设置
- [ ] 个股查询用个股接口，未滥用全市场接口
- [ ] 批量查询已加 `time.sleep()`
- [ ] 每次查询后已检查 `df.empty`
- [ ] 资金流向接口已传入正确 `market` 参数

---

## 常用股票代码参考

| 名称 | 代码 | market |
|------|------|--------|
| 平安银行 | 000001 | sz |
| 贵州茅台 | 600519 | sh |
| 宁德时代 | 300750 | sz |
| 比亚迪 | 002594 | sz |
| 招商银行 | 600036 | sh |
| 腾讯控股 | 00700 | hk |
| 苹果 | AAPL | us |
| 沪深300指数 | 000300 | index |

---

## References

- `references/api-reference.md` — 全部 API 参数签名与返回字段（行情/财务/资金/板块/宏观/加密/期货/基金）
- `references/common-recipes.md` — 常用任务代码模板（批量下载、涨停分析、资金流向、财务报表、龙虎榜、宏观、增量存储）
- 官方文档：`https://akshare.akfamily.xyz/` — 接口签名变动时的权威来源
- GitHub：`https://github.com/akfamily/akshare` — Issues 中可查最新已知 bug 和接口变动
