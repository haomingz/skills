# 直接使用官方 ibapi 或 Web API（不使用 ib_async）

IBKR 有两条"直接调用"路径，各有不同的适用场景：

| 路径 | 协议 | 适用场景 |
|------|------|---------|
| 官方 `ibapi`（TWS API） | TCP Socket | 需要全功能（期货/期权/完整订单类型），不想依赖第三方 |
| Web API + `requests` | HTTPS REST | 轻量查询、标准 HTTP 集成；个人账户通常配合 CP Gateway/ibeam，OAuth 直连需额外配置 |

**绝大多数 Python 项目应优先用 `ib_async`**（见 SKILL.md）。本文档面向：想理解底层机制、移植到非 Python 环境、或明确需要用官方库的场景。

---

## 路径一：官方 ibapi 直接使用

### 为什么 ibapi 比 ib_async 难用

ibapi 使用**异步回调架构**：所有请求通过 `EClient` 发出，所有响应通过覆写 `EWrapper` 的回调方法接收，请求和响应之间通过 `reqId` 对应，且必须自己管理线程。

```
你的代码                         TWS/Gateway
   │                                  │
   │── reqHistoricalData(reqId) ──→   │  (EClient，发出请求)
   │                                  │
   │←── historicalData(reqId, bar) ── │  (EWrapper 回调，接收数据)
   │←── historicalDataEnd(reqId) ──── │  (EWrapper 回调，结束信号)
```

这意味着**不能用同步的方式写代码**——你必须在回调里处理结果，或者自己用 `threading.Event` 来等待。

`ib_async` 的价值正在于此：它把这套回调机制封装成了同步的函数调用。

### 安装 ibapi

ibapi 需要从 IBKR 官网下载 TWS API 安装包，或通过 pip 安装：

```bash
pip install ibapi
```

### 基本架构：EClient + EWrapper

```python
from ibapi.client import EClient
from ibapi.wrapper import EWrapper
import threading
import time

class IBApp(EWrapper, EClient):
    """继承顺序必须是 EWrapper 在前，EClient 在后"""
    def __init__(self):
        EClient.__init__(self, self)
        self.nextOrderId = None

    # ---- EWrapper 回调覆写 ----

    def error(self, reqId, errorCode, errorString, advancedOrderRejectJson=""):
        # 2104/2106 是通知消息，不是真正的错误
        if errorCode not in (2104, 2106, 2158):
            print(f"Error {errorCode}: {errorString} (reqId={reqId})")

    def nextValidId(self, orderId: int):
        """连接成功后第一个回调，标志连接已就绪"""
        self.nextOrderId = orderId
        print(f"Connected. Next valid order ID: {orderId}")
        self.on_connected()  # 在此发起后续请求

    def on_connected(self):
        """可在子类中覆写，用于在连接就绪后启动业务逻辑"""
        pass


def run_app(app: IBApp, host='127.0.0.1', port=7497, client_id=1):
    """连接并在后台线程中运行消息循环"""
    app.connect(host, port, clientId=client_id)
    thread = threading.Thread(target=app.run, daemon=True)
    thread.start()
    # 等待连接就绪（nextValidId 被调用）
    timeout = 10
    for _ in range(timeout * 10):
        if app.nextOrderId is not None:
            return
        time.sleep(0.1)
    raise TimeoutError("Connection timed out")
```

### 示例 1：请求历史数据

```python
from ibapi.client import EClient
from ibapi.wrapper import EWrapper
from ibapi.contract import Contract
import threading, time

class HistoricalApp(EWrapper, EClient):
    def __init__(self):
        EClient.__init__(self, self)
        self.nextOrderId = None
        self.bars = []
        self.done = threading.Event()

    def error(self, reqId, errorCode, errorString, advancedOrderRejectJson=""):
        if errorCode not in (2104, 2106, 2158):
            print(f"Error {errorCode}: {errorString}")

    def nextValidId(self, orderId: int):
        self.nextOrderId = orderId
        # 连接就绪后立即发起历史数据请求
        contract = Contract()
        contract.symbol = "AAPL"
        contract.secType = "STK"
        contract.exchange = "SMART"
        contract.currency = "USD"

        self.reqHistoricalData(
            reqId=1,
            contract=contract,
            endDateTime="",           # 空=当前时间
            durationStr="30 D",
            barSizeSetting="1 day",
            whatToShow="TRADES",
            useRTH=1,
            formatDate=1,
            keepUpToDate=False,
            chartOptions=[],
        )

    def historicalData(self, reqId: int, bar):
        self.bars.append({
            "date": bar.date,
            "open": bar.open,
            "high": bar.high,
            "low": bar.low,
            "close": bar.close,
            "volume": bar.volume,
        })

    def historicalDataEnd(self, reqId: int, start: str, end: str):
        print(f"Done. {len(self.bars)} bars received.")
        self.done.set()  # 通知主线程数据已到齐


app = HistoricalApp()
app.connect('127.0.0.1', 7497, clientId=1)

thread = threading.Thread(target=app.run, daemon=True)
thread.start()

# 主线程阻塞等待数据
app.done.wait(timeout=30)
app.disconnect()

import pandas as pd
df = pd.DataFrame(app.bars)
print(df.tail())
```

### 示例 2：下单并监听成交

```python
from ibapi.client import EClient
from ibapi.wrapper import EWrapper
from ibapi.contract import Contract
from ibapi.order import Order
from decimal import Decimal
import threading, time

class OrderApp(EWrapper, EClient):
    def __init__(self):
        EClient.__init__(self, self)
        self.nextOrderId = None

    def error(self, reqId, errorCode, errorString, advancedOrderRejectJson=""):
        if errorCode not in (2104, 2106, 2158):
            print(f"Error {errorCode}: {errorString}")

    def nextValidId(self, orderId: int):
        self.nextOrderId = orderId
        self.place_order()

    def place_order(self):
        contract = Contract()
        contract.symbol = "AAPL"
        contract.secType = "STK"
        contract.exchange = "SMART"
        contract.currency = "USD"

        order = Order()
        order.orderId = self.nextOrderId
        order.action = "BUY"
        order.orderType = "LMT"
        order.totalQuantity = 1
        order.lmtPrice = 175.00
        order.tif = "DAY"

        self.placeOrder(self.nextOrderId, contract, order)
        print(f"Order placed: orderId={self.nextOrderId}")

    def orderStatus(self, orderId, status, filled: Decimal, remaining: Decimal,
                    avgFillPrice, permId, parentId, lastFillPrice, clientId,
                    whyHeld, mktCapPrice):
        print(f"orderId={orderId} status={status} filled={filled} avgPrice={avgFillPrice}")

    def openOrder(self, orderId, contract, order, orderState):
        print(f"openOrder: {orderId} {contract.symbol} {order.action} {order.totalQuantity}")

    def execDetails(self, reqId, contract, execution):
        print(f"Execution: {execution.shares}@{execution.price}")


app = OrderApp()
app.connect('127.0.0.1', 7497, clientId=1)
thread = threading.Thread(target=app.run, daemon=True)
thread.start()
time.sleep(30)  # 保持连接等待成交
app.disconnect()
```

### ibapi 与 ib_async 对比

| 维度 | `ibapi`（官方）| `ib_async` |
|------|--------------|------------|
| **代码量** | 多（每个请求需覆写回调）| 少（同步写法，函数直接返回结果）|
| **学习曲线** | 陡（需理解回调/线程模型）| 平缓 |
| **最新特性** | 最快获得（官方维护）| 稍有滞后（社区跟进）|
| **稳定性** | 官方保证 | 社区维护（原作者 2024 年离世后接力）|
| **Jupyter 友好** | ❌（线程冲突）| ✅（内置 `util.startLoop()`）|
| **asyncio 集成** | 手动实现 | 原生支持 |
| **适合场景** | 需要最新 API 功能、机构级自定义 | 绝大多数个人/团队量化场景 |

**结论**：ibapi 是 ib_async 的底层，ib_async 只是消除了样板代码。功能完全相同，选 ib_async 只会让代码更短，不会损失能力。

---

## 路径二：Web API + requests 直接调用

IBKR Web API（Client Portal API）是标准 HTTPS REST，可以用任何语言的 HTTP 客户端调用。

**前置条件**：个人账户最常见方式是运行一个 **CP Gateway** 进程（Java 程序，负责 session 管理和转发请求），或用 ibeam Docker 自动化运行。经 IBKR 配置过 OAuth 1.0a/2.0 的账户/机构可以直连 `https://api.ibkr.com/v1/api`，不需要本地 Gateway。

### Gateway 地址

```
本地 Gateway 基础 URL: https://localhost:5000/v1/api
```

所有请求发往 `localhost:5000`。Gateway 使用自签名证书，Python 中需加 `verify=False`。

### Session 保活

CP Gateway session 会在无操作后超时。IBKR 文档建议定期调用 `/tickle`，常见做法是约每 60 秒调用一次，并在访问 `/iserver` 端点前确认 brokerage session 状态：

```python
import requests, urllib3

urllib3.disable_warnings()  # 屏蔽自签名证书警告
BASE = "https://localhost:5000/v1/api"

def tickle():
    """保活 session，每 60 秒调用一次"""
    resp = requests.get(f"{BASE}/tickle", verify=False)
    return resp.json()

def is_authenticated():
    resp = requests.get(f"{BASE}/iserver/auth/status", verify=False)
    data = resp.json()
    return data.get("authenticated", False)

# 检查并重建 brokerage session（访问 /iserver 端点前必须）
def init_brokerage_session():
    resp = requests.post(
        f"{BASE}/iserver/reauthenticate",
        verify=False,
    )
    return resp.json()
```

### 账户查询

```python
# 获取账户列表
accounts = requests.get(f"{BASE}/portfolio/accounts", verify=False).json()
account_id = accounts[0]["id"]
print(f"Account: {account_id}")

# 账户摘要（余额）
summary = requests.get(
    f"{BASE}/portfolio/{account_id}/summary",
    verify=False,
).json()
print(f"Net Liquidation: {summary.get('netliquidation', {}).get('amount')}")

# 持仓
positions = requests.get(
    f"{BASE}/portfolio/{account_id}/positions/0",  # 0 = 第一页
    verify=False,
).json()
for pos in positions:
    print(f"{pos['contractDesc']}: {pos['position']} @ {pos['mktPrice']:.2f}")
```

### 合约搜索（获取 conid）

Web API 用 `conid`（合约 ID）代替合约对象：

```python
# 按 symbol 搜索合约
resp = requests.get(
    f"{BASE}/iserver/secdef/search",
    params={"symbol": "AAPL", "secType": "STK"},
    verify=False,
)
results = resp.json()
conid = results[0]["conid"]   # AAPL 的 conid = 265598
print(f"AAPL conid: {conid}")

# 期货合约
resp = requests.get(
    f"{BASE}/iserver/secdef/search",
    params={"symbol": "ES", "secType": "FUT", "exchange": "CME"},
    verify=False,
)
```

### 市场数据快照

```python
# 需要先订阅，再轮询快照
# 常用 field codes:
# 31=last price  55=symbol  70=high  71=low  84=bid  86=ask  7295=open  7296=close  87=volume

conid = 265598  # AAPL

# 第一次调用触发订阅，可能返回空
resp = requests.get(
    f"{BASE}/iserver/marketdata/snapshot",
    params={"conids": conid, "fields": "31,55,70,71,84,86,7295,7296"},
    verify=False,
)
import time; time.sleep(1)

# 第二次调用获取实际数据
resp = requests.get(
    f"{BASE}/iserver/marketdata/snapshot",
    params={"conids": conid, "fields": "31,55,70,71,84,86,7295,7296"},
    verify=False,
)
data = resp.json()[0]
print(f"AAPL: last={data.get('31')}, bid={data.get('84')}, ask={data.get('86')}")

# 取消订阅
requests.get(f"{BASE}/iserver/marketdata/{conid}/unsubscribe", verify=False)
```

### 历史数据

```python
import requests

resp = requests.get(
    f"{BASE}/iserver/marketdata/history",
    params={
        "conid": 265598,     # AAPL
        "exchange": "SMART",
        "period": "1M",      # 1M=1月, 1W=1周, 1D=1天, 1h=1小时
        "bar": "1d",         # 1d/1h/5min/1min
        "outsideRth": False,
    },
    verify=False,
)
history = resp.json()
for bar in history.get("data", [])[-5:]:
    # t=时间戳(ms), o=开盘, h=高, l=低, c=收盘, v=成交量
    print(f"t={bar['t']}, close={bar['c']}")
```

### 下单

```python
# 必须先获取 brokerage session
init_brokerage_session()

# 市价买入 AAPL 1 股
order_body = {
    "orders": [{
        "conid": 265598,       # AAPL conid
        "secType": "STK",
        "orderType": "MKT",
        "side": "BUY",
        "quantity": 1,
        "tif": "DAY",
    }]
}

resp = requests.post(
    f"{BASE}/iserver/account/{account_id}/orders",
    json=order_body,
    verify=False,
)
result = resp.json()

# IBKR 可能返回确认问题，需要二次确认
if isinstance(result, list) and result[0].get("id"):
    confirm_id = result[0]["id"]
    # 二次确认（回答确认问题）
    confirm_resp = requests.post(
        f"{BASE}/iserver/reply/{confirm_id}",
        json={"confirmed": True},
        verify=False,
    )
    print(confirm_resp.json())
else:
    # 直接成功
    print(result)
```

### 查询和取消订单

```python
# 查询当日订单
orders = requests.get(
    f"{BASE}/iserver/account/orders",
    verify=False,
).json()

for order in orders.get("orders", []):
    print(f"{order.get('ticker')}: {order.get('side')} "
          f"{order.get('remainingQuantity')} @ status={order.get('status')}")

# 取消订单
order_id = "1234567890"  # 从 orders 列表取
resp = requests.delete(
    f"{BASE}/iserver/account/{account_id}/order/{order_id}",
    verify=False,
)
print(resp.json())
```

### Web API 速率限制（关键端点）

| 端点 | 限制 |
|------|------|
| `/iserver/marketdata/snapshot` | 10 次/秒 |
| `/iserver/marketdata/history` | 5 并发请求 |
| `/iserver/account/orders` | 1 次/5 秒 |
| `/iserver/account/pnl/partitioned` | 1 次/5 秒 |
| `/portfolio/accounts` | 1 次/5 秒 |
| `/tickle` | 1 次/秒 |
| `/iserver/scanner/run` | 1 次/秒 |

---

## 三条路径选择建议

| 场景 | 推荐方式 |
|------|---------|
| Python 项目，需要全功能（期货/期权/实时行情/完整订单） | `ib_async` |
| 理解底层机制 / 需要官方最新特性 | `ibapi` 直接使用（本文路径一）|
| 非 Python 环境（Go/JS/Rust） | Web API + 原生 HTTP 客户端（本文路径二）|
| Cloud 服务器 + 简单查询（不跑 TWS/Gateway 桌面）| Web API + requests + ibeam/CP Gateway，或已获批的 OAuth 直连 |
| 高频交易 / 机构级别 | FIX API（需单独申请，不在本文范围）|

**核心区别**：
- `ibapi` 和 `ib_async` 走同一条 TCP socket 路径，功能完全等价，只是代码写法不同
- Web API 是独立的 HTTPS 路径，功能略少（部分高级订单/数据能力不如 TWS API），但更适合标准 HTTP 集成
- TWS API 需要本地运行 TWS/Gateway 进程；Web API 个人常用路径需要本地/Docker 运行 CP Gateway，OAuth 直连则需要 IBKR 额外配置
