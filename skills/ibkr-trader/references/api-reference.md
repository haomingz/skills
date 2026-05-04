# IBKR TWS API 参考

## Contents
- 合约类型（Contract）
- 订单类型（Order）
- 关键 IB 方法签名
- 历史数据参数对照表
- 市场数据类型
- 速率限制
- 常见错误代码

---

## 合约类型（Contract）

### 快捷构造器（ib_async）

```python
from ib_async import Stock, Forex, Future, Option, Index, CFD, Bond, FuturesOption

# 美股
Stock('AAPL', 'SMART', 'USD')
Stock('MSFT', 'SMART', 'USD', primaryExchange='NASDAQ')  # 多交易所上市时指定主交易所

# 外汇（以 IDEALPRO 交易所交易）
Forex('EURUSD')
Forex('USDJPY')

# 期货（必须指定到期日，格式 YYYYMMDD）
Future('ES', '20251219', 'CME')       # E-mini S&P 500
Future('NQ', '20251219', 'CME')       # E-mini Nasdaq
Future('CL', '20251120', 'NYMEX')     # 原油
Future('GC', '20251127', 'COMEX')     # 黄金

# 美股期权（symbol, expiry YYYYMMDD, strike, 'C'/'P', exchange）
Option('AAPL', '20251219', 230, 'C', 'SMART')
Option('SPY',  '20251231', 600, 'P', 'SMART')

# 指数（用于历史数据请求，不可交易）
Index('SPX', 'CBOE')
Index('NDX', 'NASDAQ')

# CFD
CFD('IBUS30')   # Dow Jones CFD

# 债券（通过 ISIN 指定）
Bond(secIdType='ISIN', secId='US03076KAA60')
```

### 手工构造（原始 Contract）

```python
from ib_async import Contract

c = Contract()
c.symbol = 'AAPL'
c.secType = 'STK'
c.exchange = 'SMART'
c.currency = 'USD'
```

### secType 枚举

| secType | 资产类别 |
|---------|---------|
| `STK` | 股票/ETF |
| `OPT` | 期权 |
| `FUT` | 期货 |
| `CASH` | 外汇（Forex） |
| `IND` | 指数 |
| `CFD` | 差价合约 |
| `BOND` | 债券 |
| `FUND` | 共同基金 |
| `FOP` | 期货期权 |
| `WAR` | 认股权证 |

---

## 订单类型（Order）

### ib_async 内置订单构造器

```python
from ib_async import (
    MarketOrder, LimitOrder, StopOrder, StopLimitOrder,
    MarketOnCloseOrder, LimitOnCloseOrder
)

# 市价单
MarketOrder('BUY', 100)
MarketOrder('SELL', 50)

# 限价单
LimitOrder('BUY', 100, 180.00)   # 180 元限价买 100 股
LimitOrder('SELL', 100, 200.00)

# 止损单（市价止损）
StopOrder('SELL', 100, 170.00)   # 价格跌到 170 时市价卖出

# 止损限价单
StopLimitOrder('SELL', 100, stopPrice=170.00, lmtPrice=169.00)

# 收盘市价单 / 收盘限价单
MarketOnCloseOrder('BUY', 100)
LimitOnCloseOrder('SELL', 100, 195.00)

# Bracket 组合单（入场+止盈+止损）
bracket = ib.bracketOrder(
    action='BUY',
    quantity=100,
    limitPrice=180.0,
    takeProfitPrice=200.0,
    stopLossPrice=170.0,
)
# bracket 是一个包含 3 个 Order 的列表，需逐一提交
for leg in bracket:
    ib.placeOrder(contract, leg)
```

### 手工构造 Order 对象

```python
from ib_async import Order

order = Order()
order.action = 'BUY'          # 'BUY' 或 'SELL'
order.orderType = 'LMT'       # 'MKT', 'LMT', 'STP', 'STP LMT', 'MOC', 'LOC'
order.totalQuantity = 100
order.lmtPrice = 180.0
order.tif = 'DAY'             # 'DAY', 'GTC', 'IOC', 'GTD', 'OPG', 'FOK'
order.outsideRth = False      # True = 允许盘前盘后交易
```

### orderType 枚举

| orderType | 说明 |
|-----------|------|
| `MKT` | 市价单 |
| `LMT` | 限价单 |
| `STP` | 止损（市价）单 |
| `STP LMT` | 止损限价单 |
| `TRAIL` | 跟踪止损 |
| `TRAIL LIMIT` | 跟踪止损限价 |
| `MOC` | 收盘市价单 |
| `LOC` | 收盘限价单 |
| `MID` | 中间价单 |
| `VWAP` | VWAP 算法单 |

### tif（Time In Force）

| tif | 说明 |
|-----|------|
| `DAY` | 当日有效（默认） |
| `GTC` | Good Till Canceled |
| `IOC` | Immediate Or Cancel |
| `GTD` | Good Till Date |
| `OPG` | 开盘时执行 |
| `FOK` | Fill Or Kill |

---

## 关键 IB 方法签名

### 连接管理

```python
ib.connect(host, port, clientId, timeout=20, readonly=False)
ib.disconnect()
ib.isConnected()         # bool
ib.managedAccounts()     # ['U1234567']
```

### 合约

```python
ib.qualifyContracts(*contracts)          # 填充 conId，就地修改
ib.reqContractDetails(contract)          # 返回 ContractDetails 列表
ib.reqSecDefOptParams(                   # 期权链定义（参数集）
    underlyingSymbol, futFopExchange,
    underlyingSecType, underlyingConId)
```

### 市场数据

```python
ib.reqMarketDataType(marketDataType)     # 1=实时 2=冻结 3=延迟 4=延迟冻结
ib.reqMktData(contract, genericTickList='', snapshot=False, regulatorySnapshot=False)
ib.cancelMktData(contract)
ib.reqMktDepth(contract, numRows=5)     # Level 2 委托簿
ib.cancelMktDepth(contract)
```

### 历史数据

```python
ib.reqHistoricalData(
    contract,
    endDateTime,       # 空字符串=当前；或 'YYYYMMDD HH:MM:SS'
    durationStr,       # '1 D', '5 D', '1 W', '1 M', '1 Y', '60 S'
    barSizeSetting,    # 见下表
    whatToShow,        # 'TRADES', 'MIDPOINT', 'BID', 'ASK', 'BID_ASK', 'ADJUSTED_LAST'
    useRTH,            # True=仅正常交易时段
    formatDate=1,      # 1=字符串日期 2=UNIX 时间戳
    keepUpToDate=False # True=持续更新（streaming historical）
)
```

### 订单管理

```python
trade = ib.placeOrder(contract, order)  # 返回 Trade 对象，实时更新
ib.cancelOrder(order, manualCancelOrderTime='')
ib.reqOpenOrders()      # 请求所有开放订单（含其他客户端）
ib.openOrders()         # 当前客户端开放订单（缓存，快）
ib.openTrades()         # 当前客户端 Trade 对象列表
ib.trades()             # 所有 Trade（含已完成）
ib.fills()              # 成交记录列表
```

### 账户与持仓

```python
ib.positions()                                  # 所有账户持仓
ib.portfolio()                                  # 含市值的持仓
ib.accountSummary(account='')                   # 账户摘要
ib.accountValues(account='')                    # 所有账户数值（缓存）
ib.reqAccountUpdates(subscribe=True, acctCode='')  # 订阅账户更新
pnl = ib.reqPnL(account, modelCode='')         # 订阅 P&L
ib.cancelPnL(account)
```

---

## 历史数据参数对照表

### durationStr × barSizeSetting 合法组合

| durationStr | 最小 barSize | 最大 barSize |
|-------------|-------------|-------------|
| `60 S` | `1 secs` | `1 min` |
| `1800 S` | `1 secs` | `30 mins` |
| `1 D` | `1 min` | `1 day` |
| `1 W` | `3 mins` | `1 week` |
| `1 M` | `30 mins` | `1 month` |
| `1 Y` | `1 day` | `1 month` |

### barSizeSetting 完整枚举

```
1 secs, 5 secs, 10 secs, 15 secs, 30 secs
1 min, 2 mins, 3 mins, 5 mins, 10 mins, 15 mins, 20 mins, 30 mins
1 hour, 2 hours, 3 hours, 4 hours, 8 hours
1 day, 1 week, 1 month
```

### whatToShow 枚举

| 值 | 说明 | 适用合约 |
|----|------|---------|
| `TRADES` | 成交均价 | STK, FUT |
| `MIDPOINT` | 买卖中间价 | CASH, STK |
| `BID` | 买价 | 所有 |
| `ASK` | 卖价 | 所有 |
| `BID_ASK` | 同时请求（计算两倍限速）| 所有 |
| `ADJUSTED_LAST` | 复权收盘价 | STK |
| `HISTORICAL_VOLATILITY` | 历史波动率 | STK |
| `OPTION_IMPLIED_VOLATILITY` | 隐含波动率 | STK, OPT |

---

## 市场数据类型

```python
ib.reqMarketDataType(1)  # 实时数据（需市场数据订阅）
ib.reqMarketDataType(2)  # 冻结数据（实时订阅，市场关闭后保留最后价格）
ib.reqMarketDataType(3)  # 延迟数据（15分钟延迟，免费）
ib.reqMarketDataType(4)  # 延迟冻结（延迟+保留关闭时价格，免费）
```

---

## 速率限制

### API 消息速率

- 默认上限：**50 条消息/秒**（等于 market data lines / 2）
- 超限处理（取决于 TWS 设置）：
  - Error 100 + 3 次违规后断开连接
  - 或 TWS 自动排队（不断开，但请求被延迟）

### 历史数据 Pacing

| 规则 | 限制 |
|------|------|
| 相同合约/交易所/数据类型重复请求 | 间隔 > 15 秒 |
| 同一合约 2 秒内请求次数 | < 6 次 |
| 10 分钟内总请求次数 | ≤ 60 次 |
| BID_ASK 请求计算 | × 2 倍（一次算两次）|
| 并发历史数据请求上限 | 50 个 |

### 市场数据线上限

- 默认 100 条并发市场数据线
- 增加方式：提升账户佣金量 或 购买 Quote Booster
- 查看当前使用：TWS 中 `Ctrl+Alt+=`

---

## 常见错误代码

| 错误码 | 消息 | 原因与处理 |
|--------|------|-----------|
| 100 | Max rate exceeded | 发送频率超限；降低请求速率 |
| 162 | Historical data request pacing violation | 历史数据请求过快；加 `time.sleep(2)` |
| 200 | No security definition | 合约参数错误或未 qualify；检查 symbol/exchange/currency |
| 201 | Order rejected | 订单被拒；查看详细 reason 字段 |
| 300 | Can't find EId with tickerId | 重复取消不存在的订阅 |
| 309 | Max number of market depth requests | Level 2 上限 3 个；取消旧的再发新的 |
| 354 | Requested market data is not subscribed | 未订阅对应市场数据；切换到延迟数据(type=3) |
| 420 | Invalid real-time query | 实时数据请求违规 |
| 502 | Couldn't connect to TWS | 端口/IP 不匹配；确认 TWS 已启动 |
| 504 | Not connected | 连接断开后发送请求；重连后再试 |
| 507 | Bad Message Length | clientId 冲突或 TWS 锁定 |
| 2104/2106 | Market data farm connection is OK | 通知信息（非错误），数据服务已就绪 |
| 10006 | Missing parent order | Bracket 子订单提交太快；加 50ms 延迟 |
| 10168 | Requested market data requires additional subscription | 需要额外数据订阅 |
