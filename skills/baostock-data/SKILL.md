---
name: baostock-data
description: 使用 BaoStock Python 库获取中国 A 股证券数据（免费，无需注册）。当需要编写 Python 代码获取 A 股 K 线数据、季度财务报表、股票基本信息、指数成分股或宏观经济指标时使用。涵盖 query_history_k_data_plus、季度财务数据、交易日历、选股筛选、技术指标计算、批量下载等场景。
---

# BaoStock A 股数据获取

使用 `baostock`（证券宝）获取中国 A 股历史行情与财务数据。无需注册，结果以 pandas DataFrame 返回。

**不适用于**：实时行情（无实时推送接口）、港股/美股、非 Python 环境。

---

## 安装与验证

```bash
pip install baostock --upgrade
# 验证：应输出 "login success!"
python -c "import baostock as bs; lg = bs.login(); print(lg.error_msg); bs.logout()"
```

---

## 核心会话模式

每个脚本必须以 `login()` 开头，`logout()` 结尾：

```python
import baostock as bs
import pandas as pd

lg = bs.login()
assert lg.error_code == '0', f"登录失败: {lg.error_msg}"

# ... 数据查询 ...

bs.logout()
```

### ⚠️ pandas 2.0+ 兼容写法（必读）

BaoStock 内部使用了已在 pandas 2.0 中删除的 `DataFrame.append()`，**`rs.get_data()` 在 pandas 2.0+ 环境下会崩溃**。统一使用手动循环：

```python
# ✅ 正确（兼容所有 pandas 版本）
rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
df = pd.DataFrame(rows, columns=rs.fields)

# ❌ 错误（pandas 2.0+ 崩溃）
df = rs.get_data()
```

---

## 股票代码格式

| 板块 | 代码规律 | 示例 |
|------|----------|------|
| 沪市A股（主板） | `sh.6xxxxx` | `sh.600000`（浦发银行）|
| 深市主板 | `sz.00xxxx` | `sz.000001`（平安银行）|
| 创业板 | `sz.30xxxx` | `sz.300750`（宁德时代）|
| 科创板 | `sh.68xxxx` | `sh.688599` |
| 北交所 | `bj.4xxxxx`/`bj.8xxxxx` | `bj.430047` |
| 沪市指数 | `sh.0xxxxx` | `sh.000001`（上证综指）|
| 深市指数 | `sz.3xxxxx` | `sz.399001`（深证成指）|

按板块筛选（从 `query_all_stock` 结果过滤）：

```python
df_sh   = df[df['code'].str.startswith('sh.6')]   # 沪市A股
df_main = df[df['code'].str.startswith('sz.00')]   # 深市主板
df_gem  = df[df['code'].str.startswith('sz.30')]   # 创业板
df_star = df[df['code'].str.startswith('sh.68')]   # 科创板
```

---

## 数据获取流程 checklist

```
BaoStock 任务进度：
- [ ] 第1步：确认所需 API 和字段
- [ ] 第2步：检查股票代码格式和板块
- [ ] 第3步：编写 login → query → 手动循环 → logout 脚本
- [ ] 第4步：验证结果（error_code == '0'，DataFrame 非空）
- [ ] 第5步：将字符串列转换为数值类型
- [ ] 第6步：处理边界情况（停牌、退市、非交易日、空季度）
```

---

## API 速查表

| 需求 | API |
|------|-----|
| 日/周/月/分钟 K 线 | `query_history_k_data_plus()` |
| 指定日期全部证券代码 | `query_all_stock(day)` |
| 股票基本信息 | `query_stock_basic(code)` |
| 交易日历 | `query_trade_dates(start_date, end_date)` |
| 行业分类（申万） | `query_stock_industry(code)` |
| 指数成分股 | `query_sz50_stocks()` / `query_hs300_stocks()` / `query_zz500_stocks()` |
| 季频盈利能力 | `query_profit_data(code, year, quarter)` |
| 季频偿债能力 | `query_balance_data(code, year, quarter)` |
| 季频现金流量 | `query_cash_flow_data(code, year, quarter)` |
| 季频营运能力 | `query_operation_data(code, year, quarter)` |
| 季频成长能力 | `query_growth_data(code, year, quarter)` |
| 杜邦分析 | `query_dupont_data(code, year, quarter)` |
| 业绩快报 | `query_performance_express_report(code, start_date, end_date)` |
| 业绩预告 | `query_forecast_report(code, start_date, end_date)` |
| 除权除息信息 | `query_dividend_data(code, year, yearType)` |
| 复权因子 | `query_adjust_factor(code, start_date, end_date)` |
| 存款/贷款利率 | `query_deposit_rate_data()` / `query_loan_rate_data()` |
| 存款准备金率 | `query_required_reserve_ratio_data()` |
| 货币供应量 | `query_money_supply_data_month()` / `query_money_supply_data_year()` |
| SHIBOR | `query_shibor_data(start_date, end_date)` |

---

## 最小代码骨架

```python
import baostock as bs
import pandas as pd

bs.login()

rs = bs.query_history_k_data_plus(
    "sh.600000",
    "date,code,open,high,low,close,preclose,volume,amount,adjustflag,turn,tradestatus,pctChg,peTTM,pbMRQ,isST",
    start_date="2024-01-01",
    end_date="2024-12-31",
    frequency="d",     # d=日 w=周 m=月 5/15/30/60=分钟线
    adjustflag="2"     # 1=后复权 2=前复权 3=不复权(默认)
)

rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
df = pd.DataFrame(rows, columns=rs.fields)

bs.logout()

# 字段类型转换（所有返回值均为字符串）
df['close'] = pd.to_numeric(df['close'], errors='coerce')
df['turn']  = pd.to_numeric(df['turn'],  errors='coerce')  # 停牌日为空字符串 → NaN
df['date']  = pd.to_datetime(df['date'])
```

---

## K 线字段速查

**日线**（`frequency="d"`）：

```
date, code, open, high, low, close, preclose, volume, amount,
adjustflag, turn, tradestatus, pctChg, peTTM, pbMRQ, psTTM, pcfNcfTTM, isST
```

**分钟线**（`frequency="5"/"15"/"30"/"60"`）：

```
date, time, code, open, high, low, close, volume, amount, adjustflag
```
- 分钟线**不含指数**，仅支持 2020-01-03 起数据
- `time` 字段格式：`YYYYMMDDHHMMSSsss`（17位字符串）

**周/月线**（`frequency="w"/"m"`）：

```
date, code, open, high, low, close, volume, amount, adjustflag, turn, pctChg
```

---

## 常见陷阱

1. **所有返回值均为字符串** — 数值列统一用 `pd.to_numeric(df[col], errors='coerce')`

2. **停牌日换手率为空字符串** — 直接 `float()` 会抛异常，须用 `errors='coerce'` 转 NaN

3. **停牌日数据过滤** — 停牌日 `volume == '0'`（字符串），过滤方式：
   ```python
   df = df[df['volume'] != '0']
   ```

4. **周线/月线只在最后交易日更新** — 周线每周最后交易日可获取，月线每月最后交易日可获取；提前查询当期数据返回空

5. **分钟线 QPS 约 20 次/秒** — 批量下载多只股票分钟线时须限速：
   ```python
   import time; time.sleep(0.05)  # 每次请求后等 50ms
   ```

6. **复权方法与通达信不同** — BaoStock 使用"涨跌幅复权法"，绝对价格与同花顺/通达信不一致，但收益率计算结果相同

7. **指数没有分钟线** — `sh.000001` 等指数代码查询分钟线会静默返回空 DataFrame

8. **会话超时需重新登录** — 长时间闲置后须重新调用 `bs.login()`：
   ```python
   try:
       rs = bs.query_history_k_data_plus(...)
   except Exception:
       bs.logout(); bs.login()
       rs = bs.query_history_k_data_plus(...)  # 重试
   ```

9. **非线程安全** — 多股并发下载用 `multiprocessing`，不要用 `threading`

10. **非交易日查询全部股票返回空** — 先用 `query_trade_dates()` 确认为交易日

11. **`login()`/`logout()` 会向 stdout 打印提示** — 如需静默运行，用 `contextlib.redirect_stdout(open(os.devnull, 'w'))`

---

## AI Agent 操作策略

执行量化分析任务时遵循以下三条原则：

**1. 验证优先，不假设数据存在**
每次查询后检查 `rs.error_code == '0'` 和 `df.empty`；停牌/退市股返回空 DataFrame 属正常，跳过继续，不报错中断。

**2. 多步组合分析形成决策链**
典型链路：`query_stock_industry` 筛行业 → `query_hs300_stocks` 锁定成分股 → `query_history_k_data_plus` 取K线 → 季频财务指标 → 综合评分输出。不要仅凭单一接口得出结论。

**3. 限速与重试，不静默失败**
批量查询加 `time.sleep(0.05)`；网络中断后 `bs.logout(); bs.login()` 重连再重试；遇到空结果要记录日志而非忽略。

---

## 质量 checklist

完成 BaoStock 脚本前确认：

- [ ] `bs.login()` 在所有查询之前调用；`bs.logout()` 在结尾调用
- [ ] 每次查询后检查 `rs.error_code == '0'`
- [ ] 使用手动循环而非 `rs.get_data()`（pandas 2.0+ 兼容）
- [ ] 数值列已用 `pd.to_numeric(errors='coerce')` 转换
- [ ] `turn` 字段使用 `errors='coerce'` 处理停牌空值
- [ ] 分钟线字段与日线字段未混用
- [ ] `adjustflag` 已明确设置（默认 `"3"` 不复权）
- [ ] 批量分钟线下载已加限速

---

## References

- `references/api-reference.md` — 全部 API 的参数说明与返回字段（含算法公式）
- `references/common-recipes.md` — 常用任务代码模板（批量下载、技术指标、回测框架、静默登录）
- `references/production-patterns.md` — 生产级模式（Parquet存储、QPS限速、增量更新、全市场下载）
