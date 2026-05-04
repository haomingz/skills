# IBKR TWS API 参考

合约类型、订单类型、关键方法、速率限制、错误代码的完整参考。

## Contents
- 合约类型
- 订单类型与 TIF
- 历史数据参数
- 速率限制
- 关键错误代码

---

## 合约类型

### 快捷构造（ib_async）

```python
from ib_async import Stock, Forex, Future, Option, Index, CFD, Bond, FuturesOption

Stock('AAPL', 'SMART', 'USD')
Stock('MSFT', 'SMART', 'USD', primaryExchange='NASDAQ')  # 多交易所上市需指定

Forex('EURUSD')            # 自动使用 IDEALPRO 交易所
Forex('USDJPY')

Future('ES', '20251219', 'CME')   # E-mini S&P 500
Future('NQ', '20251219', 'CME')   # E-mini Nasdaq
Future('CL', '20251120', 'NYMEX') # 原油
Future('GC', '20251127', 'COMEX') # 黄金
Future('ZB', '20251219', 'CBOT')  # 美国 30 年国债

Option('AAPL', '20251219', 230, 'C', 'SMART')   # Call
Option('SPY',  '20251231', 600, 'P', 'SMART')    # Put

Index('SPX', 'CBOE')    # 标普 500 指数（仅数据）
Index('VIX', 'CBOE')    # VIX 波动率指数
Index('NDX', 'NASDAQ')

CFD('IBUS30')   # 道琼斯 CFD
Bond(secIdType='ISIN', secId='US03076KAA60')

FuturesOption('ES', '20251219', 5000, 'C', 'CME')  # 期货期权
```

### secType 枚举

| secType | 资产类别 |
|---------|---------|
| `STK` | 股票 / ETF |
| `OPT` | 美式/欧式期权 |
| `FUT` | 期货 |
| `CASH` | 外汇（Spot Forex） |
| `IND` | 指数 |
| `CFD` | 差价合约 |
| `BOND` | 债券 |
| `FUND` | 共同基金 |
| `FOP` | 期货期权 |
| `WAR` | 认股权证 |
| `BAG` | Combo / Spread |

### exchange 常用值

| exchange | 说明 |
|----------|------|
| `SMART` | IB 智能路由（股票/期权首选） |
| `IDEALPRO` | 外汇市场 |
| `CME` | 芝加哥商业交易所 |
| `CBOT` | 芝加哥期货交易所 |
| `NYMEX` | 纽约商业交易所 |
| `COMEX` | 商品交易所 |
| `CBOE` | 芝加哥期权交易所 |
| `NYSE` / `NASDAQ` / `ARCA` | 直接路由 |
| `GLOBEX` | CME Globex 电子平台 |

---

## 订单类型与 TIF

### orderType 枚举

| orderType | 说明 | 主要参数 |
|-----------|------|---------|
| `MKT` | 市价单 | — |
| `LMT` | 限价单 | `lmtPrice` |
| `STP` | 止损市价单 | `auxPrice`（触发价）|
| `STP LMT` | 止损限价单 | `auxPrice` + `lmtPrice` |
| `TRAIL` | 跟踪止损 | `trailingPercent` 或 `auxPrice`（跟踪额）|
| `TRAIL LIMIT` | 跟踪止损限价 | `trailingPercent` + `lmtPriceOffset` |
| `MOC` | 收盘市价单 | — |
| `LOC` | 收盘限价单 | `lmtPrice` |
| `MID` | 中间价单 | — |
| `VWAP` | VWAP 算法单 | — |
| `REL` | Relative（Pegged to Primary）| `auxPrice`（偏移量）|

### TIF（Time In Force）

| tif | 说明 |
|-----|------|
| `DAY` | 当日有效（默认） |
| `GTC` | Good Till Canceled |
| `IOC` | Immediate Or Cancel |
| `GTD` | Good Till Date（需设 `goodTillDate`）|
| `OPG` | 开盘时执行（Market on Open）|
| `FOK` | Fill Or Kill |
| `DTC` | Day Till Canceled |

### ib_async 快捷构造器

```python
from ib_async import (
    MarketOrder, LimitOrder, StopOrder, StopLimitOrder,
    MarketOnCloseOrder, LimitOnCloseOrder,
)

MarketOrder('BUY', 100)
LimitOrder('BUY', 100, 180.0)
StopOrder('SELL', 100, 170.0)
StopLimitOrder('SELL', 100, stopPrice=170.0, lmtPrice=169.0)
MarketOnCloseOrder('BUY', 100)
LimitOnCloseOrder('SELL', 100, 195.0)

# Bracket（入场 + 止盈 + 止损，返回 3 个 Order 的列表）
bracket = ib.bracketOrder('BUY', 100, limitPrice=180.0,
                           takeProfitPrice=200.0, stopLossPrice=170.0)
```

---

## 历史数据参数

### durationStr 格式

```
'N S'   # N 秒   例: '60 S', '1800 S'
'N D'   # N 天   例: '1 D', '5 D', '10 D'
'N W'   # N 周   例: '1 W', '2 W'
'N M'   # N 月   例: '1 M', '3 M', '6 M'
'N Y'   # N 年   例: '1 Y', '5 Y'
```

### durationStr × barSizeSetting 合法范围

| durationStr | barSize 下限 | barSize 上限 |
|-------------|-------------|-------------|
| `60 S` | `1 secs` | `1 min` |
| `1800 S` | `1 secs` | `30 mins` |
| `1 D` | `1 min` | `1 day` |
| `1 W` | `3 mins` | `1 week` |
| `1 M` | `30 mins` | `1 month` |
| `1 Y` | `1 day` | `1 month` |

### 全部 barSizeSetting 值

```
1 secs · 5 secs · 10 secs · 15 secs · 30 secs
1 min · 2 mins · 3 mins · 5 mins · 10 mins · 15 mins · 20 mins · 30 mins
1 hour · 2 hours · 3 hours · 4 hours · 8 hours
1 day · 1 week · 1 month
```

### whatToShow 枚举

| 值 | 说明 |
|----|------|
| `TRADES` | 成交均价（股票/期货常用）|
| `MIDPOINT` | 买卖中间价（外汇常用）|
| `BID` | 买价 |
| `ASK` | 卖价 |
| `BID_ASK` | 同时（计双倍限速）|
| `ADJUSTED_LAST` | 复权收盘价（股票）|
| `HISTORICAL_VOLATILITY` | 历史波动率 |
| `OPTION_IMPLIED_VOLATILITY` | 隐含波动率 |

### 历史数据不可用情形

- 30 秒以下 bar 超过 6 个月前
- 已到期期权/期权历史（按到期日起 2 年截止）
- 已到期期货超过到期 2 年
- 已退市证券
- 组合合约（Combo）的原生历史数据

---

## 速率限制

### 请求速率上限

```
默认: 50 条消息/秒（= market data lines / 2 = 100 / 2）
超限后: Error 100，连续 3 次断开连接
```

### 历史数据 Pacing

| 规则 | 限制 |
|------|------|
| 相同合约/交易所/数据类型重复请求 | 间隔 > 15 秒 |
| 同一合约 2 秒内请求次数 | < 6 次 |
| 10 分钟内总历史数据请求 | ≤ 60 次 |
| BID_ASK 计算倍率 | × 2（一次等于两次）|
| 并发历史请求上限 | 50 个 |

### 市场数据线上限

- 默认 100 条并发行情订阅
- `ib.reqMktData()` 每次消耗一条线；`ib.cancelMktData()` 释放
- 查看使用量：TWS 中按 `Ctrl+Alt+=`
- 超限后新订阅返回空数据（不报错）

---

## 常见错误代码

| 代码 | 消息（简） | 原因 | 解决方案 |
|------|-----------|------|---------|
| 100 | Max rate exceeded | 请求频率超 50/秒 | 降低发送频率 |
| 162 | Historical data pacing | 历史请求过频 | 每次间隔 ≥ 2 秒；10 分钟 ≤ 60 次 |
| 200 | No security definition | 合约参数错误 | 检查 symbol/exchange/currency；先 qualifyContracts |
| 201 | Order rejected | 订单被拒绝 | 查看 trade.log 的 reason 字段 |
| 300 | Can't find EId | 取消不存在的订阅 | 忽略或检查 reqId |
| 309 | Max market depth requests | Level 2 超过 3 个 | 取消旧订阅 |
| 354 | Market data not subscribed | 未订阅数据 | 用 `reqMarketDataType(3)` 切换延迟数据 |
| 420 | Invalid real-time query | 实时数据请求违规 | 检查数据类型设置 |
| 502 | Couldn't connect to TWS | TWS 未启动或端口错 | 确认 TWS/Gateway 运行，端口匹配 |
| 504 | Not connected | 连接已断开 | 重连后重试 |
| 507 | Bad Message Length | clientId 冲突 / TWS 锁定 | 换 clientId；检查 TWS 状态 |
| 2104 | Market data farm OK | 通知（非错误）| 忽略，表示数据服务就绪 |
| 2106 | HMDS data farm OK | 通知（非错误）| 忽略，历史数据服务就绪 |
| 10006 | Missing parent order | Bracket 子单太快 | 子单之间加 50 ms 延迟 |
| 10168 | Subscription required | 需要额外数据订阅 | 在 Account Management 订阅对应市场 |
