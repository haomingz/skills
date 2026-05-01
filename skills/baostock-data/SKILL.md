---
name: baostock-data
description: 此技能用于使用 BaoStock Python 库获取中国 A 股行情、财务指标、交易日历、指数成分、行业分类和宏观利率数据。适用于用户提到 BaoStock、baostock、A股K线、前复权、后复权、季度财务指标、交易日历、指数成分股、批量下载A股数据、query_history_k_data_plus，或需要编写 BaoStock Python 数据脚本的场景。
---

# BaoStock A 股数据获取

使用 `baostock` 获取中国 A 股历史行情、季频财务指标、证券基本信息、指数成分、交易日历和部分宏观数据。保持脚本结构清晰：登录、查询、手动迭代、转换类型、检查空结果、登出。

**不适用于**：实时行情、港股/美股、非 Python 环境、低延迟生产行情源。多市场或实时行情任务优先考虑 `akshare-data`。

## 安装与验证

```bash
pip install baostock --upgrade
python -c "import baostock as bs; lg = bs.login(); print(lg.error_code, lg.error_msg); bs.logout()"
```

函数签名或字段有疑问时查 `references/api-reference.md`，必要时再对照官方文档：`http://baostock.com/baostock/index.php/Python_API文档`。

## 工作流

**复制此 checklist 追踪进度：**

```
BaoStock 进度:
- [ ] 步骤 1: 确认数据范围与 API
- [ ] 步骤 2: 规范股票代码、日期、字段和复权方式
- [ ] 步骤 3: 编写 login -> query -> 手动迭代 -> logout 脚本
- [ ] 步骤 4: 转换字段类型并处理空结果
- [ ] 步骤 5: 批量任务加入限速、重试和存储
- [ ] 步骤 6: 运行质量检查并修正问题
```

**步骤 1: 确认数据范围与 API**

选择最窄的 BaoStock API，避免为了单只股票或单类指标拉取全市场数据。字段、参数、公式说明加载 `references/api-reference.md`。

常用 API 速查：

| 需求 | API |
|------|-----|
| 日/周/月/分钟 K 线 | `query_history_k_data_plus()` |
| 指定日期全部证券 | `query_all_stock(day)` |
| 股票基本信息 | `query_stock_basic(code)` |
| 交易日历 | `query_trade_dates(start_date, end_date)` |
| 行业分类 | `query_stock_industry(code)` |
| 上证50/沪深300/中证500成分股 | `query_sz50_stocks()` / `query_hs300_stocks()` / `query_zz500_stocks()` |
| 盈利/偿债/现金流/营运/成长能力 | `query_profit_data()` / `query_balance_data()` / `query_cash_flow_data()` / `query_operation_data()` / `query_growth_data()` |
| 杜邦分析 | `query_dupont_data()` |
| 业绩快报/预告 | `query_performance_express_report()` / `query_forecast_report()` |
| 除权除息/复权因子 | `query_dividend_data()` / `query_adjust_factor()` |
| 存贷款利率/准备金率/货币供应/SHIBOR | `query_deposit_rate_data()` / `query_loan_rate_data()` / `query_required_reserve_ratio_data()` / `query_money_supply_data_month()` / `query_shibor_data()` |

**步骤 2: 规范股票代码、日期、字段和复权方式**

使用 BaoStock 带市场前缀的代码格式：

| 板块 | 格式 | 示例 |
|------|------|------|
| 沪市 A 股 | `sh.6xxxxx` | `sh.600000` |
| 深市主板 | `sz.00xxxx` | `sz.000001` |
| 创业板 | `sz.30xxxx` | `sz.300750` |
| 科创板 | `sh.68xxxx` | `sh.688599` |
| 北交所 | `bj.4xxxxx` / `bj.8xxxxx` | `bj.430047` |
| 沪市指数 | `sh.0xxxxx` | `sh.000001` |
| 深市指数 | `sz.3xxxxx` | `sz.399001` |

日期使用 `YYYY-MM-DD`。价格序列显式设置 `adjustflag`：`"1"` 后复权，`"2"` 前复权，`"3"` 不复权。

字段按频率区分：

| 频率 | 常用字段 |
|------|----------|
| 日线 `d` | `date,code,open,high,low,close,preclose,volume,amount,adjustflag,turn,tradestatus,pctChg,peTTM,pbMRQ,isST` |
| 周/月线 `w` / `m` | `date,code,open,high,low,close,volume,amount,adjustflag,turn,pctChg` |
| 分钟线 `5` / `15` / `30` / `60` | `date,time,code,open,high,low,close,volume,amount,adjustflag` |

**步骤 3: 编写 login -> query -> 手动迭代 -> logout 脚本**

每个脚本或 worker 进程维护独立会话。使用 `try/finally` 确保登出。

```python
import baostock as bs
import pandas as pd


def baostock_result_to_df(rs) -> pd.DataFrame:
    rows = []
    while (rs.error_code == "0") and rs.next():
        rows.append(rs.get_row_data())
    return pd.DataFrame(rows, columns=rs.fields)


lg = bs.login()
try:
    if lg.error_code != "0":
        raise RuntimeError(f"BaoStock login failed: {lg.error_msg}")

    rs = bs.query_history_k_data_plus(
        "sh.600000",
        "date,code,open,high,low,close,volume,amount,adjustflag,turn,tradestatus,pctChg",
        start_date="2024-01-01",
        end_date="2024-12-31",
        frequency="d",
        adjustflag="2",
    )
    if rs.error_code != "0":
        raise RuntimeError(f"BaoStock query failed: {rs.error_msg}")

    df = baostock_result_to_df(rs)
finally:
    bs.logout()
```

**步骤 4: 转换字段类型并处理空结果**

BaoStock 返回值基本都是字符串。构造 DataFrame 后再统一转换，停牌、退市、非交易日、未披露季度都可能返回空结果。

```python
if df.empty:
    raise ValueError("BaoStock returned no rows; check symbol, date range, trading status, and API coverage")

for col in ["open", "high", "low", "close", "volume", "amount", "turn", "pctChg"]:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce")

if "date" in df.columns:
    df["date"] = pd.to_datetime(df["date"])
```

**步骤 5: 批量任务加入限速、重试和存储**

加载 `references/common-recipes.md` 获取批量下载、行业筛选、指数成分下载、技术指标、回测骨架和静默登录模板。

加载 `references/production-patterns.md` 获取 Parquet 存储、限速重试、增量更新、多进程下载、分钟线追加和 DuckDB 查询模式。

批量下载优先使用进程级并行，避免多个线程共享同一个 BaoStock 会话。

**步骤 6: 运行质量检查并修正问题**

运行下方质量 checklist。若检查失败，回到对应步骤修正后重新验证。

## 常见陷阱

- 不使用 `rs.get_data()`；BaoStock 可能调用 pandas 2.x 已删除的 API。统一用 `rs.next()` 和 `rs.get_row_data()` 手动迭代。
- 每次查询后检查 `rs.error_code`，不要只检查 DataFrame。
- 停牌日 `turn` 等字段可能是空字符串，数值转换使用 `errors="coerce"`。
- 停牌日 `volume` 可能是字符串 `"0"`，过滤前确认字段类型。
- 分钟线不支持指数，指数分钟线返回空结果时按边界情况处理。
- 周线/月线通常在周期最后交易日形成，提前查询当期数据可能为空。
- 非交易日调用 `query_all_stock(day)` 可能返回空；先用交易日历确认。
- 货币供应量月度接口使用 `YYYY-MM`，年度接口使用 `YYYY`，不要套用日线日期格式。
- 长时间闲置后会话可能失效，批量任务需要重连和重试。
- `login()` / `logout()` 会打印 stdout；需要静默运行时参考 `references/common-recipes.md`。

## 约束

- 保留 `login -> query -> manual iteration -> logout` 的会话结构。
- 明确设置 `adjustflag`，不要依赖默认不复权。
- 将字段列表与 `frequency` 对齐，避免日线字段和分钟线字段混用。
- 空结果必须被记录、跳过或显式报错，不能静默吞掉。
- 批量下载必须加入限速、异常日志和可恢复存储。

## 质量检查

- [ ] `name` 与目录名一致，frontmatter 只保留必要元数据。
- [ ] API 选择与用户需求匹配。
- [ ] 股票代码使用 `sh.` / `sz.` / `bj.` 前缀。
- [ ] 日期格式符合 BaoStock 接口要求。
- [ ] K 线字段与频率匹配。
- [ ] `adjustflag` 已明确设置。
- [ ] 查询后检查 `rs.error_code`。
- [ ] 使用手动迭代，不调用 `rs.get_data()`。
- [ ] 数值列使用 `pd.to_numeric(..., errors="coerce")`。
- [ ] 空结果、停牌、非交易日、退市和未披露数据都有处理策略。
- [ ] 批量任务包含限速、重试和日志。

## 参考资料（按需加载）

- `references/api-reference.md` - API 签名、参数、字段和公式说明。
- `references/common-recipes.md` - 批量下载、行业筛选、指数成分、技术指标、回测骨架、静默登录。
- `references/production-patterns.md` - Parquet 存储、限速重试、增量更新、多进程、分钟线存储、DuckDB 查询。
- 官方文档：`http://baostock.com/baostock/index.php/Python_API文档`
