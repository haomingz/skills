# IBKR API 入门指南

## API 类型选择

IBKR 提供三套 API，按使用场景选择：

| API | 协议 | Python 首选库 | 适用场景 |
|-----|------|--------------|---------|
| **TWS API** | TCP Socket（本地）| `ib_async` | 全功能：实时/历史行情、完整订单类型、期货/外汇/期权 |
| **Web API** | REST + WebSocket | `requests` / `ibind` | 标准 HTTP；个人账户通常通过 CP Gateway/ibeam，OAuth 直连需额外申请/配置 |
| **FIX API** | FIX 协议 | 机构专用 | 低延迟机构接入，需单独申请 |

**绝大多数个人量化场景使用 TWS API + ib_async。**

---

## 前置准备

### 1. 开户

在 [interactivebrokers.com](https://www.interactivebrokers.com) 开设账户。同时开通 **Paper Trading Account**（纸面交易账户），用于 API 开发测试，完全免费。

API 使用通常要求账户已完全开通并入金。Paper 账户可以测试交易流程，但实时行情权限通常跟随 live 用户的市场数据订阅设置。

### 2. 下载 IB Gateway 或 TWS

| 应用 | 特点 | 推荐用途 |
|------|------|---------|
| **IB Gateway（Stable）** | 无完整交易 UI，较轻量 | 生产/服务器环境 |
| IB Gateway（Latest）| 含最新特性 | 需要新 API 功能时 |
| Trader Workstation（TWS）| 有完整图形界面 | 开发调试（可视化确认）|

下载地址：https://www.interactivebrokers.com/en/trading/ib-api.php

### 3. 配置 API 连接

#### IB Gateway

`Configure → API → Settings`

- ✅ Enable ActiveX and Socket Clients
- ❌ Read Only API（下单时需关闭）
- ✅ Download open orders on connection
- Socket port: `4001`（实盘）/ `4002`（Paper）

#### Trader Workstation

`Edit → Global Configuration → API → Settings`（同上设置）

- Socket port: `7496`（实盘）/ `7497`（Paper）

### 4. 内存设置（重要）

`Configure → Settings → Memory Allocation` → 设置为 **4096 MB 以上**

拉取大量数据（如期权链）时，Gateway 默认内存容易耗尽导致崩溃。

---

## 安装 ib_async

```bash
pip install ib_async
```

ib_async 是 ib_insync 的社区维护继承版本。**不需要同时安装官方 `ibapi`**，ib_async 内部已实现完整协议。

---

## 快速开始

### 连接并获取持仓

```python
from ib_async import IB

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)  # Paper TWS

# 当前持仓
for pos in ib.positions():
    print(f"{pos.contract.symbol}: {pos.position} @ {pos.avgCost:.4f}")

# 账户净值
account = ib.managedAccounts()[0]
for item in ib.accountSummary(account):
    if item.tag == 'NetLiquidation':
        print(f"Net Liquidation: {float(item.value):,.2f} {item.currency}")

ib.disconnect()
```

### 拉取历史数据

```python
from ib_async import IB, Stock, util

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

contract = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(contract)

bars = ib.reqHistoricalData(
    contract,
    endDateTime='',
    durationStr='30 D',
    barSizeSetting='1 day',
    whatToShow='TRADES',
    useRTH=True,
)
df = util.df(bars)
print(df.tail())
ib.disconnect()
```

### 下市价单（Paper Account）

```python
from ib_async import IB, Stock, MarketOrder

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)  # 务必用 Paper 端口测试

stock = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(stock)

order = MarketOrder('BUY', 1)
trade = ib.placeOrder(stock, order)

ib.sleep(2)
print(f"Order status: {trade.orderStatus.status}")
ib.disconnect()
```

---

## 端口速查

| 环境 | 应用 | 端口 |
|------|------|------|
| Paper Trading | TWS | 7497 |
| Live | TWS | 7496 |
| Paper Trading | IB Gateway | 4002 |
| Live | IB Gateway | 4001 |

---

## 自动化运行（无头环境）

### TWS/Gateway 自动登录 — IBC

[IBC](https://github.com/IbcAlpha/IBC) 自动注入凭据到 TWS/Gateway 登录界面，适合服务器无人值守运行。

- TWS 必须使用 **offline/standalone** 版本（不是自动更新版）；IB Gateway 本身不走 TWS 的自动更新模式，但生产环境仍建议固定 stable/latest 版本并验证后升级
- 支持 IBKR Mobile 2FA（配置重试窗口）
- 硬件 token、特殊 2FA 流程需要在目标账户上单独实测

关键配置（`config.ini`）：

```ini
IbLoginId=your_username
IbPassword=your_password
TradingMode=paper
FIX=no
ReadonlyLogin=no
AcceptIncomingConnectionAction=accept
```

### Web API Gateway 无头认证 — ibeam

[ibeam](https://github.com/Voyz/ibeam) 基于 Selenium + Docker，自动化 Client Portal Web API Gateway 的认证。

OAuth 1.0a/2.0 直连 `api.ibkr.com` 不需要 CP Gateway，但通常需要额外审批、密钥配置或机构/第三方接入流程；个人量化脚本最常见路径仍是 CP Gateway + ibeam。

```yaml
# docker-compose.yml
services:
  ibeam:
    image: voyz/ibeam
    env_file: env.list
    ports:
      - 5000:5000
    network_mode: bridge
    restart: 'no'
```

```
# env.list
IBEAM_ACCOUNT=your_account
IBEAM_PASSWORD=your_password
```

启动后验证：
```bash
curl -k https://localhost:5000/v1/api/one/user
```

---

## 市场数据订阅说明

| 数据级别 | 费用 | 使用方式 |
|---------|------|---------|
| Cboe One + IEX（US 股票/ETF 非综合实时）| 免费 | 账户默认可用；不是全市场 NBBO 综合源 |
| 延迟数据 | 免费（可用市场）| `ib.reqMarketDataType(3)` |
| NYSE/NASDAQ 综合实时 | 需按网络/交易所订阅 | 在 Account Management 订阅，以官网价格为准 |
| 期货实时（CME/NYMEX 等）| 需按交易所订阅 | 以官网价格为准 |
| Level 2 委托簿 | 需付费 | 订阅后 `ib.reqMktDepth()` |

**坑**：实时行情权限按用户名和市场数据订阅控制，不按账户控制。TWS 界面、Paper 用户和 API 连接共用市场数据线（默认 100 条），实时/延迟/空值表现要以当前登录用户名的权限为准。

详细定价：https://www.interactivebrokers.com/en/pricing/market-data-pricing.php

---

## 常见问题

**Q: 连接报 ConnectionRefusedError？**
确认 TWS/Gateway 已启动，且 `Enable ActiveX and Socket Clients` 已勾选，端口号与代码一致。

**Q: 历史数据报 Error 162（Pacing violation）？**
历史数据请求频率超限。在循环中加 `time.sleep(2)` 间隔，10 分钟内总请求 ≤ 60 次。

**Q: 行情数据全为 None/0？**
使用了实时数据类型（`reqMarketDataType(1)`）但没有订阅。切换为 `reqMarketDataType(3)` 用免费延迟数据测试。

**Q: 下单报 Read-Only？**
TWS/Gateway API Settings 中关闭 "Read Only API"。

**Q: 期权链请求导致 Gateway 卡死？**
`reqContractDetails` 不指定到期日会拉取全量合约（可能数千个），撑爆 Gateway 内存。始终指定具体到期日，并将内存设置调高到 4096 MB 以上。
