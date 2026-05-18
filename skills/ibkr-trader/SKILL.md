---
name: ibkr-trader
description: 此技能用于通过 Interactive Brokers（IBKR）API 进行自动化交易操作，包括连接 TWS/IB Gateway、合约查询与校验、行情数据获取（实时/历史）、下单交易（股票/期权/期货/外汇）、账户和持仓查询。优先使用 ib_async（ib_insync 的维护分支）封装库，并优先从环境变量解析 IB Gateway/TWS 的地址、端口和 clientId。适用于用户提到 IBKR API、Interactive Brokers、TWS API、ib_insync、ib_async、IB Gateway、ibapi、placeOrder、reqHistoricalData、qualifyContracts、期货下单、全球多市场自动化交易的场景。
---

# IBKR Trader API 调用（TWS API）

此技能专注于 **TWS API**（TCP socket），通过 ib_async 或官方 ibapi 连接本地 TWS / IB Gateway 进程。

| 调用方式 | 优点 | 适用场景 |
|---------|------|---------|
| `ib_async`（推荐） | 同步写法，自动保持连接同步，asyncio 友好 | Python 项目首选（ib_insync 的维护分支） |
| 官方 `ibapi` | 官方支持，原生回调架构 | 需要最新特性、非 Python 环境 |

**不适用于**：Web API / Client Portal API（REST + WebSocket，需要 CP Gateway 进程，功能子集，不支持 tick 数据和算法订单）；无法在本地运行 TWS 或 IB Gateway 进程的纯云无头环境；加密货币高频交易；thinkorswim 专有功能。

## 安装

```bash
pip install ib_async       # 推荐（ib_insync 的维护继承版本）
# 或
pip install ib_insync      # 老版本，已停止维护但仍可用
```

官方 `ibapi` 不需要单独安装（ib_async 内部实现了完整协议）。

## 前置条件

1. 下载并安装 [IB Gateway](https://www.interactivebrokers.com/en/trading/ib-api.php) 或 Trader Workstation（TWS）
2. 登录后启用 API：`Configure → API → Settings → Enable ActiveX and Socket Clients`
3. 确认端口：TWS 实盘 `7496`，Paper `7497`；Gateway 实盘 `4001`，Paper `4002`
4. 关闭 Read-Only 模式（需要下单时）
5. 设置 Memory Allocation ≥ 4096 MB（批量数据防崩溃）

详见 `references/setup-and-auth.md`。

## 工作流

**复制此 checklist 追踪进度：**

```
IBKR API 进度:
- [ ] 步骤 1: 连接 TWS/Gateway
- [ ] 步骤 2: 校验合约（qualifyContracts）
- [ ] 步骤 3: 选择任务类型（行情 / 历史数据 / 下单 / 账户）
- [ ] 步骤 4: 调用 API，等待响应
- [ ] 步骤 5: 处理数据
- [ ] 步骤 6: 断开连接 / 质量检查
```

**步骤 1: 连接 TWS/Gateway**

解析连接端点时按顺序执行：

1. 优先读取环境变量：`IBKR_HOST` / `TWS_HOST`、`IBKR_PORT` / `TWS_PORT`、`IBKR_CLIENT_ID` / `TWS_CLIENT_ID`
2. 没有环境变量时使用默认候选：`127.0.0.1:7497`（Paper TWS）、`127.0.0.1:4002`（Paper Gateway）、`127.0.0.1:7496`（实盘 TWS）、`127.0.0.1:4001`（实盘 Gateway）
3. 默认地址和端口不通时，继续探索本机监听端口，优先查找 `tws`、`ibgateway`、`jts`、`java` 相关进程并测试其监听地址与端口

```python
import os
import socket
from ib_async import IB, util

# Jupyter Notebook 中需要取消注释下行
# util.startLoop()

DEFAULT_ENDPOINTS = (
    ('127.0.0.1', 7497),  # Paper TWS
    ('127.0.0.1', 4002),  # Paper Gateway
    ('127.0.0.1', 7496),  # Live TWS
    ('127.0.0.1', 4001),  # Live Gateway
)
CONNECT_PROBE_TIMEOUT = 2.0  # seconds; keep endpoint discovery fast
DEFAULT_CLIENT_ID = 1  # local single-script default; change when clientId conflicts

def can_open(host, port, timeout=CONNECT_PROBE_TIMEOUT):
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except OSError:
        return False

def resolve_ibkr_endpoint():
    env_host = os.getenv('IBKR_HOST') or os.getenv('TWS_HOST')
    env_port = os.getenv('IBKR_PORT') or os.getenv('TWS_PORT')
    host = env_host or '127.0.0.1'
    client_id = int(os.getenv('IBKR_CLIENT_ID') or os.getenv('TWS_CLIENT_ID') or DEFAULT_CLIENT_ID)

    candidates = []
    if env_port:
        candidates.append((host, int(env_port)))
    elif env_host:
        candidates.extend((host, default_port) for _, default_port in DEFAULT_ENDPOINTS)
    candidates.extend(DEFAULT_ENDPOINTS)

    seen = set()
    for candidate_host, candidate_port in candidates:
        if (candidate_host, candidate_port) in seen:
            continue
        seen.add((candidate_host, candidate_port))
        if can_open(candidate_host, candidate_port):
            return candidate_host, candidate_port, client_id

    raise RuntimeError(
        "No IBKR TWS/Gateway socket found. Inspect local listeners for "
        "tws/ibgateway/jts/java processes, then set IBKR_HOST and IBKR_PORT."
    )

host, port, client_id = resolve_ibkr_endpoint()
ib = IB()
ib.connect(host, port, clientId=client_id)
print(ib.isConnected())  # True
```

每个连接必须使用唯一的 `clientId`，同一 TWS 实例可同时连接多个客户端。端点自动解析失败时读取 `references/setup-and-auth.md` 的“连接发现顺序”排查监听进程。

**步骤 2: 校验合约**

合约必须先 qualify 才能请求数据或下单。ib_async 会自动填入 `conId` 等必要字段：

```python
from ib_async import Stock, Forex, Future, Option, Index

# 股票
stock = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(stock)  # 填充 conId，确认唯一

# 期货（ES 标普 500）
es = Future('ES', '20251219', 'CME')
ib.qualifyContracts(es)

# 外汇
eurusd = Forex('EURUSD')

# 期权（需指定到期日/行权价/类型）
opt = Option('AAPL', '20251219', 230, 'C', 'SMART')
ib.qualifyContracts(opt)
```

完整合约类型见 `references/api-reference.md`。

**步骤 3: 选择任务类型**

| 需求 | 方法 |
|------|------|
| 实时行情（Level 1） | `ib.reqMktData(contract)` |
| 历史 K 线 | `ib.reqHistoricalData(contract, ...)` |
| 期权链 | `ib.reqSecDefOptParams(...)` + `ib.reqHistoricalData` |
| 市场深度（Level 2） | `ib.reqMktDepth(contract)` |
| 下单 | `ib.placeOrder(contract, order)` |
| 持仓/账户 | `ib.positions()` / `ib.accountSummary()` |

**步骤 4a: 历史行情数据**

```python
import pandas as pd
from ib_async import util

bars = ib.reqHistoricalData(
    stock,
    endDateTime='',          # 空字符串=当前时间
    durationStr='30 D',      # 时间范围
    barSizeSetting='1 day',  # K 线粒度
    whatToShow='TRADES',     # 数据类型
    useRTH=True,             # 仅正常交易时段
)
df = util.df(bars)
print(df[['date', 'open', 'high', 'low', 'close', 'volume']].tail())
```

历史数据节流限制：10 分钟内不超过 60 次请求，批量下载需要加延迟。完整 duration/barSize 对照表见 `references/api-reference.md`。

**步骤 4b: 实时行情**

```python
# 设置行情类型（1=实时/需订阅，3=延迟15分钟/免费，4=延迟冻结）
ib.reqMarketDataType(3)  # 用免费延迟数据测试

ticker = ib.reqMktData(stock, '', False, False)
ib.sleep(2)  # 等待数据到达
print(f"{ticker.last}  bid={ticker.bid}  ask={ticker.ask}  vol={ticker.volume}")

# 取消订阅
ib.cancelMktData(stock)
```

**步骤 4c: 下单交易**

```python
from ib_async import MarketOrder, LimitOrder, StopOrder

# 市价买入
order = MarketOrder('BUY', 100)
trade = ib.placeOrder(stock, order)
ib.sleep(1)
print(trade.orderStatus.status)  # PendingSubmit / PreSubmitted / Submitted / Filled

# 限价单
limit_order = LimitOrder('BUY', 100, 180.0)
trade = ib.placeOrder(stock, limit_order)

# Bracket 组合单（限价入场 + 止盈 + 止损）
bracket = ib.bracketOrder(
    action='BUY',
    quantity=100,
    limitPrice=180.0,
    takeProfitPrice=200.0,
    stopLossPrice=170.0,
)
for leg in bracket:
    ib.placeOrder(stock, leg)

# 取消订单
ib.cancelOrder(trade.order)
```

完整订单类型和期权策略见 `references/common-recipes.md`。

**步骤 5: 账户与持仓**

```python
# 持仓列表
positions = ib.positions()
for pos in positions:
    print(f"{pos.contract.symbol}: {pos.position} @ avg {pos.avgCost:.2f}")

# 账户摘要
account = ib.managedAccounts()[0]
summary = ib.accountSummary(account)
for item in summary:
    if item.tag in ('NetLiquidation', 'TotalCashValue', 'UnrealizedPnL'):
        print(f"{item.tag}: {item.value} {item.currency}")

# 实时 P&L 订阅
pnl = ib.reqPnL(account)
ib.sleep(1)
print(f"Daily P&L: {pnl.dailyPnL:.2f}")
```

**步骤 6: 断开连接**

```python
ib.sleep(1)  # 短连接场景：给时间 flush 缓冲区
ib.disconnect()
```

## 关键限制与陷阱

- **pacing violation**：历史数据 10 分钟内 ≤ 60 次请求；相同合约 2 秒内 < 6 次；批量请求加 `time.sleep(2)`
- **clientId 冲突**：同一 TWS 会话中每个连接需唯一 clientId；错误 507 表示 clientId 已被使用
- **端点发现失败**：优先设置 `IBKR_HOST`、`IBKR_PORT`、`IBKR_CLIENT_ID`；默认端口不通时检查本机 `tws` / `ibgateway` / `jts` / `java` 监听端口
- **Read-Only 模式**：TWS 默认启用，需在 API Settings 中关闭才能下单
- **市场数据订阅**：免费层仅有 Cboe One + IEX（部分股票），Period 期权/期货实时数据需额外付费订阅
- **100 市场数据线上限**：默认账户 100 条并发行情线；`Ctrl+Alt+=` 可查看当前使用量
- **期权链大请求**：`reqContractDetails` 不指定 expiry 会拉取全部合约，容易触发 Gateway 内存崩溃，必须指定到期日范围
- **TWS 每日重启**：TWS/Gateway 每日约 UTC 23:45–0:00 服务器重置，需要自动重连逻辑
- **短连接需要延迟**：断开前 `ib.sleep(1)` 让数据 flush；否则最后的请求可能未发出

## 质量检查

- [ ] `ib.isConnected()` 返回 `True` 后再调用任何请求
- [ ] 已按环境变量、默认端口、本机监听进程的顺序解析 TWS/Gateway 地址和端口
- [ ] 所有合约已调用 `qualifyContracts()` 且 `conId > 0`
- [ ] 历史数据请求频率符合 pacing 限制（批量时加延迟）
- [ ] 市场数据类型已设置（`reqMarketDataType`）
- [ ] 下单前确认 API Settings 中关闭了 Read-Only 模式
- [ ] 使用 Paper Account（port 7497/4002）测试，不在实盘账户直接测试
- [ ] 订阅了 `trade.filledEvent` 或轮询 `trade.orderStatus.status` 跟踪成交
- [ ] 批量历史数据请求加了 `time.sleep(2)` 或更长间隔
- [ ] 期权链请求指定了具体到期日，未发出无限宽请求

## 参考资料（按需加载）

- `references/setup-and-auth.md` - TWS/Gateway 安装配置、IBC 自动登录、ibeam Docker、连接重试
- `references/api-reference.md` - 合约类型、订单类型、关键方法签名、错误代码、速率限制、历史数据参数对照
- `references/common-recipes.md` - 完整可运行代码：批量历史下载、期权链、多腿策略下单、持仓监控、异步模式
