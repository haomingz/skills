# IBKR 常用代码模板

## Contents
- 连接与断开
- 自动重连（Gateway 每日重启 / 网络中断）
- 历史数据（单标的/批量/连续回溯）
- 实时行情订阅
- 期权链查询
- 股票下单（市价/限价/Bracket）
- 期权下单
- 订单状态跟踪
- 持仓与账户查询
- P&L 实时订阅
- 异步模式

---

## 自动重连（Gateway 每日重启 / 网络中断）

IB Gateway 每天约 **23:45 UTC**（服务器时间）自动重启，TCP 连接断开约 1–5 分钟。策略脚本必须能自动重连并恢复行情订阅，否则错过重连窗口后会静默失效。

### 基于事件的重连（推荐）

```python
import asyncio
import logging
from ib_async import IB, Stock

log = logging.getLogger(__name__)

class AutoReconnectIB:
    def __init__(self, host='127.0.0.1', port=4001, client_id=1):
        self.host = host
        self.port = port
        self.client_id = client_id
        self.ib = IB()
        self._subscribed_contracts = []  # 记录已订阅合约，重连后恢复
        self.ib.disconnectedEvent += self._on_disconnect

    def connect(self):
        self.ib.connect(self.host, self.port, clientId=self.client_id)
        self.ib.sleep(1)
        log.info(f"Connected, account: {self.ib.managedAccounts()}")

    def _on_disconnect(self):
        log.warning("Disconnected from IB Gateway, will reconnect...")
        self.ib.sleep(5)  # 等 Gateway 重启完成
        self._reconnect_loop()

    def _reconnect_loop(self):
        delay = 5
        while not self.ib.isConnected():
            try:
                self.ib.connect(self.host, self.port, clientId=self.client_id)
                self.ib.sleep(1)
                log.info("Reconnected successfully")
                self._restore_subscriptions()
            except Exception as e:
                log.warning(f"Reconnect failed ({e}), retry in {delay}s")
                self.ib.sleep(delay)
                delay = min(delay * 2, 60)  # 指数退避，最长 60 秒

    def subscribe(self, contract):
        """订阅行情，同时记录到恢复列表"""
        self._subscribed_contracts.append(contract)
        return self.ib.reqMktData(contract)

    def _restore_subscriptions(self):
        """重连后恢复所有行情订阅"""
        for contract in self._subscribed_contracts:
            self.ib.reqMktData(contract)
        if self._subscribed_contracts:
            log.info(f"Restored {len(self._subscribed_contracts)} subscriptions")
```

使用方式：

```python
mgr = AutoReconnectIB(port=4001, client_id=1)
mgr.connect()

stock = Stock('AAPL', 'SMART', 'USD')
mgr.ib.qualifyContracts(stock)
ticker = mgr.subscribe(stock)  # 用 subscribe 代替 reqMktData，自动加入恢复列表

mgr.ib.run()  # 阻塞运行，断线时自动重连
```

### asyncio 版本

```python
import asyncio
from ib_async import IB, Stock

async def run_with_reconnect(host='127.0.0.1', port=4001, client_id=1):
    subscribed = []

    async def connect(ib: IB):
        await ib.connectAsync(host, port, clientId=client_id)
        await asyncio.sleep(1)
        # 重连后恢复订阅
        for contract in subscribed:
            ib.reqMktData(contract)

    ib = IB()

    while True:
        try:
            await connect(ib)

            stock = Stock('AAPL', 'SMART', 'USD')
            await ib.qualifyContractsAsync(stock)
            subscribed.append(stock)
            ib.reqMktData(stock)

            # 保持运行直到断线
            await ib.disconnectedEvent
            print("Disconnected, reconnecting in 10s...")
            await asyncio.sleep(10)

        except Exception as e:
            print(f"Error: {e}, retry in 10s")
            await asyncio.sleep(10)

asyncio.run(run_with_reconnect())
```

### 重连后必须重做的事

| 操作 | 断线后状态 | 重连后是否自动恢复 |
|------|-----------|-----------------|
| `reqMktData` 行情订阅 | 全部丢失 | ❌ 必须重新订阅 |
| `reqRealTimeBars` | 全部丢失 | ❌ 必须重新订阅 |
| `reqMktDepth` Level 2 | 全部丢失 | ❌ 必须重新订阅 |
| `positions()` 持仓 | 自动同步 | ✅ 重连后自动推送 |
| `accountSummary` | 自动同步 | ✅ |
| 未成交挂单 | 服务端保留 | ✅ 连接后自动恢复（若开启 Download open orders）|
| `clientId` 绑定的订单 | 服务端保留 | ✅ |

### IBC 每日重启时间设置

避免 Gateway 在交易时段重启，把重启时间设在盘后：

```ini
# IBC config.ini / Docker 环境变量
AutoRestartTime=11:59 PM   # 本地时间（东部）→ 约 23:59 ET，期货盘前
# 或
AUTO_RESTART_TIME=11:59 PM  # gnzsnz/ib-gateway Docker
```

IB Gateway 内置的强制重启在约 23:45 UTC（18:45 ET），与 IBC AutoRestartTime 是不同机制。两个重启窗口都要确保策略能自动恢复。

---

## 连接与断开

```python
from ib_async import IB, util
import time

def make_ib(port=7497, client_id=1) -> IB:
    ib = IB()
    ib.connect('127.0.0.1', port, clientId=client_id)
    ib.sleep(1)  # 等待 2104/2106 数据服务就绪通知
    return ib

ib = make_ib()
print(f"Connected: {ib.isConnected()}, account: {ib.managedAccounts()}")

# 断开（短连接时先 sleep 让缓冲区 flush）
ib.sleep(1)
ib.disconnect()
```

---

## 历史数据

### 单标的日线

```python
from ib_async import IB, Stock, util

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

stock = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(stock)

bars = ib.reqHistoricalData(
    stock,
    endDateTime='',
    durationStr='1 Y',
    barSizeSetting='1 day',
    whatToShow='TRADES',
    useRTH=True,
)
df = util.df(bars)
print(df[['date', 'open', 'high', 'low', 'close', 'volume']].tail())
ib.disconnect()
```

### 批量多标的（带节流控制）

```python
import time
from ib_async import IB, Stock, util
import pandas as pd

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA']
data = {}

for i, sym in enumerate(symbols):
    contract = Stock(sym, 'SMART', 'USD')
    ib.qualifyContracts(contract)
    bars = ib.reqHistoricalData(
        contract,
        endDateTime='',
        durationStr='90 D',
        barSizeSetting='1 day',
        whatToShow='TRADES',
        useRTH=True,
    )
    if bars:
        data[sym] = util.df(bars).set_index('date')['close']
        print(f"[{i+1}/{len(symbols)}] {sym}: {len(bars)} bars")
    else:
        print(f"[{i+1}/{len(symbols)}] {sym}: no data")
    time.sleep(2)  # 历史数据 pacing：每次间隔 ≥ 2 秒

prices = pd.DataFrame(data)
ib.disconnect()
```

### 连续回溯获取全量历史

```python
import datetime
from ib_async import IB, Stock, util

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

contract = Stock('TSLA', 'SMART', 'USD')
ib.qualifyContracts(contract)

dt = ''
bars_list = []
while True:
    bars = ib.reqHistoricalData(
        contract,
        endDateTime=dt,
        durationStr='10 D',
        barSizeSetting='1 min',
        whatToShow='TRADES',
        useRTH=True,
        formatDate=1,
    )
    if not bars:
        break
    bars_list.append(bars)
    dt = bars[0].date
    print(f"Got {len(bars)} bars, oldest: {dt}")
    time.sleep(3)  # pacing

all_bars = [b for bars in reversed(bars_list) for b in bars]
df = util.df(all_bars)
df.to_csv('TSLA_1min.csv', index=False)
print(f"Total: {len(df)} bars")
ib.disconnect()
```

---

## 实时行情订阅

```python
from ib_async import IB, Stock

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

ib.reqMarketDataType(3)  # 延迟数据（免费，测试用）
# ib.reqMarketDataType(1)  # 实时数据（需订阅）

stock = Stock('AAPL', 'SMART', 'USD')
ticker = ib.reqMktData(stock, '', False, False)

# 等待数据填充
ib.sleep(2)
print(f"AAPL: last={ticker.last}, bid={ticker.bid}, ask={ticker.ask}, vol={ticker.volume}")

# 事件驱动更新
def on_pending_tickers(tickers):
    for t in tickers:
        print(f"{t.contract.symbol}: {t.last:.2f}")

ib.pendingTickersEvent += on_pending_tickers

ib.sleep(30)  # 保持订阅 30 秒

ib.cancelMktData(stock)
ib.disconnect()
```

---

## 期权链查询

```python
from ib_async import IB, Stock, Option, util
import time

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

# 1. 校验标的股票
underlying = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(underlying)

# 2. 获取期权参数（交易所、到期日集合、行权价集合）
chains = ib.reqSecDefOptParams(
    underlyingSymbol='AAPL',
    futFopExchange='',
    underlyingSecType='STK',
    underlyingConId=underlying.conId,
)
chain = next(c for c in chains if c.exchange == 'SMART')
print(f"Expirations: {sorted(chain.expirations)[:5]}")
print(f"Strikes: {sorted(chain.strikes)[:10]}")

# 3. 构建特定到期日的期权合约（必须指定具体到期日，不要全量拉取）
expiry = '20251219'
strikes = [s for s in chain.strikes if 220 <= s <= 240]  # 缩小范围
rights = ['C', 'P']

contracts = [
    Option('AAPL', expiry, strike, right, 'SMART')
    for strike in strikes
    for right in rights
]

# 4. 批量 qualify（分批，每批 ≤ 50）
qualified = []
batch_size = 50
for i in range(0, len(contracts), batch_size):
    batch = contracts[i:i+batch_size]
    ib.qualifyContracts(*batch)
    qualified.extend([c for c in batch if c.conId])
    time.sleep(0.5)

print(f"Qualified {len(qualified)} contracts")

# 5. 请求快照行情（延迟数据）
ib.reqMarketDataType(3)
tickers = [ib.reqMktData(c, '106', False, False) for c in qualified[:20]]
ib.sleep(3)

for t in tickers:
    print(f"{t.contract.strike}{t.contract.right}: "
          f"bid={t.bid}, ask={t.ask}, iv={t.impliedVolatility:.3f}")

ib.disconnect()
```

---

## 股票下单

### 市价单

```python
from ib_async import IB, Stock, MarketOrder

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

stock = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(stock)

order = MarketOrder('BUY', 10)
trade = ib.placeOrder(stock, order)

ib.sleep(2)
print(f"Status: {trade.orderStatus.status}")
print(f"Filled: {trade.orderStatus.filled} @ avg {trade.orderStatus.avgFillPrice}")
ib.disconnect()
```

### 限价单（GTC）

```python
from ib_async import LimitOrder, Order

# 使用内置构造器
order = LimitOrder('BUY', 10, 175.0)
order.tif = 'GTC'

# 或手工设置
order = Order()
order.action = 'BUY'
order.orderType = 'LMT'
order.totalQuantity = 10
order.lmtPrice = 175.0
order.tif = 'GTC'
order.outsideRth = True  # 允许盘前盘后

trade = ib.placeOrder(stock, order)
```

### Bracket 组合单

```python
# 入场 + 止盈 + 止损
bracket = ib.bracketOrder(
    action='BUY',
    quantity=10,
    limitPrice=180.0,
    takeProfitPrice=200.0,
    stopLossPrice=170.0,
)

trades = []
for leg in bracket:
    trade = ib.placeOrder(stock, leg)
    trades.append(trade)
    ib.sleep(0.05)  # 子单之间短暂等待，防止 Error 10006

parent_trade = trades[0]
```

### 跟踪止损

```python
from ib_async import Order

trail = Order()
trail.action = 'SELL'
trail.orderType = 'TRAIL'
trail.totalQuantity = 10
trail.trailingPercent = 5.0  # 5% 跟踪止损
# 或用价格：trail.auxPrice = 5.0（跟踪 $5）

trade = ib.placeOrder(stock, trail)
```

---

## 期权下单

```python
from ib_async import IB, Option, LimitOrder

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

# 买入期权开仓
opt = Option('AAPL', '20251219', 230, 'C', 'SMART')
ib.qualifyContracts(opt)

# 限价买入 1 手 call（乘数 100，这里 quantity=1 代表 1 个合约）
order = LimitOrder('BUY', 1, 5.50)   # 5.50 是期权价格（每股），总成本约 $550
trade = ib.placeOrder(opt, order)

ib.sleep(2)
print(f"Option order status: {trade.orderStatus.status}")
ib.disconnect()
```

---

## 订单状态跟踪

```python
# 方法 1：事件回调
def on_filled(trade, fill):
    print(f"Filled {fill.execution.shares} @ {fill.execution.price}")

def on_status_change(trade):
    print(f"Status: {trade.orderStatus.status}")

trade.fillEvent += on_filled
trade.statusEvent += on_status_change

# 方法 2：轮询（同步等待）
import asyncio

def wait_for_fill(trade, timeout=30):
    deadline = asyncio.get_event_loop().time() + timeout
    while asyncio.get_event_loop().time() < deadline:
        ib.sleep(0.5)
        if trade.isDone():
            return trade
    return None  # 超时

trade = ib.placeOrder(stock, MarketOrder('BUY', 10))
result = wait_for_fill(trade)

if result and result.orderStatus.status == 'Filled':
    print(f"Done: {result.orderStatus.avgFillPrice}")
else:
    ib.cancelOrder(trade.order)
    print("Timeout, order cancelled")

# 取消指定订单
ib.cancelOrder(trade.order)

# 取消全部订单
for trade in ib.openTrades():
    ib.cancelOrder(trade.order)
```

---

## 持仓与账户查询

```python
from ib_async import IB

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)
ib.sleep(1)  # 等待账户数据同步

# 持仓列表
positions = ib.positions()
for pos in positions:
    c = pos.contract
    print(f"{c.symbol} ({c.secType}): qty={pos.position:.0f}, "
          f"avgCost={pos.avgCost:.4f}")

# 含市值的持仓（portfolio item）
for item in ib.portfolio():
    c = item.contract
    print(f"{c.symbol}: mktValue={item.marketValue:.2f}, "
          f"unrealPnL={item.unrealizedPnL:.2f}")

# 账户摘要
account = ib.managedAccounts()[0]
summary = ib.accountSummary(account)
key_tags = {'NetLiquidation', 'TotalCashValue', 'BuyingPower',
            'UnrealizedPnL', 'RealizedPnL', 'GrossPositionValue'}
for item in summary:
    if item.tag in key_tags:
        print(f"{item.tag}: {float(item.value):,.2f} {item.currency}")

ib.disconnect()
```

---

## P&L 实时订阅

```python
from ib_async import IB

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

account = ib.managedAccounts()[0]
pnl = ib.reqPnL(account)

def on_pnl(pnl_obj):
    print(f"Daily: {pnl_obj.dailyPnL:.2f}, "
          f"Unrealized: {pnl_obj.unrealizedPnL:.2f}, "
          f"Realized: {pnl_obj.realizedPnL:.2f}")

pnl.updateEvent += on_pnl
ib.sleep(10)

ib.cancelPnL(account)
ib.disconnect()
```

---

## 异步模式（asyncio）

```python
import asyncio
from ib_async import IB, Stock, util

async def fetch_history(symbol: str):
    ib = IB()
    await ib.connectAsync('127.0.0.1', 7497, clientId=2)

    contract = Stock(symbol, 'SMART', 'USD')
    await ib.qualifyContractsAsync(contract)

    bars = await ib.reqHistoricalDataAsync(
        contract,
        endDateTime='',
        durationStr='30 D',
        barSizeSetting='1 day',
        whatToShow='TRADES',
        useRTH=True,
    )
    df = util.df(bars)
    ib.disconnect()
    return df

df = asyncio.run(fetch_history('AAPL'))
print(df.tail())
```

### 多标的并发请求（asyncio）

```python
async def fetch_multi(symbols: list):
    ib = IB()
    await ib.connectAsync('127.0.0.1', 7497, clientId=3)

    results = {}
    for sym in symbols:
        contract = Stock(sym, 'SMART', 'USD')
        await ib.qualifyContractsAsync(contract)
        bars = await ib.reqHistoricalDataAsync(
            contract, endDateTime='', durationStr='30 D',
            barSizeSetting='1 day', whatToShow='TRADES', useRTH=True,
        )
        results[sym] = util.df(bars)
        await asyncio.sleep(2)  # pacing

    ib.disconnect()
    return results

results = asyncio.run(fetch_multi(['AAPL', 'MSFT', 'GOOGL']))
```
