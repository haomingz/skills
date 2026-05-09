# IBKR 第三方工具详解

涵盖 ib_async、IBC、ibeam、ibind、两个 Docker 镜像以及其他实用社区工具的介绍、用途和配置方法。

## Contents
- [ib_async — TWS API 封装库](#ib_async)
- [IBC — TWS/Gateway 自动登录控制器](#ibc)
- [ibeam — Web API Gateway 无头认证](#ibeam)
- [ibind — Web API Python 客户端](#ibind)
- [Docker 镜像：gnzsnz/ib-gateway vs extrange/ibkr-docker](#docker-镜像对比)
  - [gnzsnz/ib-gateway](#gnzsnzib-gateway)
  - [extrange/ibkr-docker](#extrangeibkr-docker)
  - [两镜像对比](#两镜像对比)
- [其他实用工具](#其他实用工具)
  - [ib_fundamental — 基本面数据](#ib_fundamental)
  - [ibkr-cli — 命令行交易工具（轻量）](#ibkr-cli)
  - [icli — 命令行交易工具（全功能）](#icli)
  - [ibkr-mcp — MCP Server（AI 接入）](#ibkr-mcp)
- [工具组合选型](#工具组合选型)

---

## ib_async

**GitHub**: https://github.com/ib-api-reloaded/ib_async  
**文档**: https://ib-api-reloaded.github.io/ib_async/  
**安装**: `pip install ib_async`  

### 是什么

`ib_async` 是 `ib_insync` 的社区维护继承版本，由 `ib-api-reloaded` 组织维护。

核心价值：**把 IBKR 官方 ibapi 的异步回调架构封装成同步写法**，无需手动管理线程、`EWrapper` 回调和 `reqId` 映射。

### 为什么选 ib_async 而非官方 ibapi

| 维度 | 官方 ibapi | ib_async |
|------|-----------|---------|
| 编程模型 | EWrapper 回调，需手动注册 | 同步调用，直接返回结果 |
| 并发管理 | 手写 threading | 自动处理，内部 asyncio |
| reqId 管理 | 手动分配和追踪 | 自动分配 |
| 代码量 | 获取历史数据约 50 行 | 约 8 行 |
| asyncio 支持 | 无官方支持 | 原生支持 `async with IB()` |
| 安装 | 从 GitHub 下载 wheel | `pip install ib_async` |

### 安装

```bash
pip install ib_async
# 不需要同时安装官方 ibapi，ib_async 内部已实现完整协议
```

### 同步写法（最常用）

```python
from ib_async import IB, Stock, MarketOrder, util

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)  # Paper TWS

# 合约校验（必须在下单/请求数据前）
stock = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(stock)

# 历史数据
bars = ib.reqHistoricalData(
    stock,
    endDateTime='',
    durationStr='30 D',
    barSizeSetting='1 day',
    whatToShow='TRADES',
    useRTH=True,
)
df = util.df(bars)

# 下单
order = MarketOrder('BUY', 1)
trade = ib.placeOrder(stock, order)
ib.sleep(2)
print(trade.orderStatus.status)

ib.disconnect()
```

### asyncio 写法

```python
import asyncio
from ib_async import IB, Stock

async def main():
    async with IB() as ib:
        await ib.connectAsync('127.0.0.1', 7497, clientId=1)
        stock = Stock('AAPL', 'SMART', 'USD')
        await ib.qualifyContractsAsync(stock)
        bars = await ib.reqHistoricalDataAsync(
            stock, endDateTime='', durationStr='5 D',
            barSizeSetting='1 hour', whatToShow='TRADES', useRTH=True,
        )
        print(f"Got {len(bars)} bars")

asyncio.run(main())
```

### 实时数据事件订阅

```python
from ib_async import IB, Stock

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)

stock = Stock('AAPL', 'SMART', 'USD')
ib.qualifyContracts(stock)

ticker = ib.reqMktData(stock)

def on_pending_tickers(tickers):
    for t in tickers:
        print(f"{t.contract.symbol}: bid={t.bid} ask={t.ask} last={t.last}")

ib.pendingTickersEvent += on_pending_tickers
ib.run()  # 阻塞运行（Ctrl+C 退出）
```

### Bracket 组合单

```python
bracket = ib.bracketOrder(
    'BUY', 10,
    limitPrice=180.0,
    takeProfitPrice=200.0,
    stopLossPrice=170.0,
)
for order in bracket:
    ib.placeOrder(stock, order)
```

### 注意事项

- `clientId` 必须唯一，同一 TWS 连接两个脚本时分别用不同 clientId
- `qualifyContracts` 必须先于下单或请求数据，否则合约 conId 为 0 会导致错误
- `ib.sleep()` 是专用方法（非 `time.sleep`），让事件循环处理回调
- 使用延迟数据测试时先调用 `ib.reqMarketDataType(3)`

---

## IBC

**GitHub**: https://github.com/IbcAlpha/IBC  
**类型**: Java 工具（不是 Python 库）  
**用途**: 自动化 TWS / IB Gateway 的登录、对话框处理和日常重启

### 是什么

IBC（Interactive Brokers Controller）是一个 Java 程序，通过注入凭据和自动点击 TWS/Gateway 的登录界面，实现无人值守启动。适合服务器环境下定时自动重启 Gateway。

### 关键限制

**IBC 不能与 self-updating TWS 配合使用，TWS 必须安装 offline/standalone 版本。** IB Gateway 本身没有 TWS 那种自动更新模式，但生产环境仍建议固定 stable/latest 版本并在升级前测试。
下载地址：https://www.interactivebrokers.com/en/trading/ib-api.php

### 安装

```bash
# Linux/macOS
mkdir ~/IBC && cd ~/IBC
unzip IBC-*.zip   # 解压下载的 release zip

# Windows：解压到 C:\IBC
```

### 配置文件（config.ini）

```ini
[IBController]
FIX=no
IbLoginId=your_username
IbPassword=your_password
TradingMode=paper              # paper 或 live
ForceTwoFactorAuthentication=no
ReadonlyLogin=no

AcceptIncomingConnectionAction=accept
AutoRestartTime=11:59 PM       # 每日自动重启时间（本地时间）
TWOFA_TIMEOUT_ACTION=restart   # exit 或 restart
LoginDialogDisplayTimeout=60
```

### 启动命令

**Linux/macOS — IB Gateway：**

```bash
bash ~/IBC/gatewaystart.sh ~/IBC/config.ini ~/Jts/ibgateway/latest ~/IBC
```

**Linux/macOS — TWS：**

```bash
bash ~/IBC/twsstart.sh ~/IBC/config.ini ~/Jts ~/IBC
```

**Windows — PowerShell：**

```powershell
& "C:\IBC\Scripts\StartGateway.bat" "C:\IBC\config.ini" "C:\Jts\ibgateway\latest" "C:\IBC"
```

### systemd 集成（Linux）

```ini
# /etc/systemd/system/ibgateway.service
[Unit]
Description=IB Gateway with IBC
After=network.target

[Service]
Type=simple
User=trader
ExecStart=/bin/bash /home/trader/IBC/gatewaystart.sh /home/trader/IBC/config.ini /home/trader/Jts/ibgateway/latest /home/trader/IBC
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
```

### 2FA 说明

IBC 支持 IBKR Mobile 软件令牌（TOTP）：
- 首次登录需在手机 App 上点击确认
- `TWOFA_TIMEOUT_ACTION=restart` 超时后自动重试，等待用户手机确认
- **不支持**硬件 RSA token

### IBC vs 手动登录

| 场景 | IBC | 手动 |
|------|-----|------|
| 服务器无人值守 | ✅ 自动 | ❌ 需人工 |
| 每日自动重启 | ✅ AutoRestartTime | ❌ 需人工 |
| 对话框自动确认 | ✅ | ❌ |
| 自动更新版 TWS | ❌ 不支持 | ✅ 可用 |

---

## ibeam

**GitHub**: https://github.com/Voyz/ibeam  
**作者**: Voyz（与 ibind 同一作者）  
**用途**: Client Portal Web API Gateway 的无头认证  
**适用路径**: Web API（非 TWS API）

### 是什么

ibeam 使用 Selenium + Xvfb 虚拟显示，在无桌面的服务器上自动完成 IBKR Client Portal Gateway 的 Web 登录流程，维持 CP Gateway session 不过期。

**注意**：ibeam 是 Web API 路径专用工具；**不能**用于 TWS API。

### Docker 方式（推荐）

```yaml
# docker-compose.yml
services:
  ibeam:
    image: voyz/ibeam:latest
    env_file: ibeam.env
    ports:
      - "5000:5000"
    network_mode: bridge
    restart: unless-stopped
```

```bash
# ibeam.env
IBEAM_ACCOUNT=your_ibkr_username
IBEAM_PASSWORD=your_ibkr_password
# IBEAM_KEY=your_pin  # 可选：PIN + Mobile 2FA 时填写
```

```bash
docker-compose up -d
curl -k https://localhost:5000/v1/api/one/user  # 验证认证成功
```

### 独立运行（非 Docker）

```bash
pip install ibeam

export IBEAM_ACCOUNT=your_username
export IBEAM_PASSWORD=your_password
ibeam start
```

### Session 保活

CP Gateway 会在无操作后超时。ibeam 内置 tickle 定时任务，自动调用 `/v1/api/tickle` 保持 session 活跃。

手动 tickle：

```bash
curl -k -X POST https://localhost:5000/v1/api/tickle
```

### 与 ibind 配合使用

```python
from ibind import IbkrClient
client = IbkrClient(url='https://localhost:5000/v1/api/')
accounts = client.portfolio_accounts()
```

### ibeam vs IBC

| 维度 | ibeam | IBC |
|------|-------|-----|
| 适用 API | Web API（CP Gateway）| TWS API（TWS/IB Gateway）|
| 实现方式 | Selenium 模拟 Web 登录 | Java 注入 TWS GUI |
| Docker 支持 | ✅ 原生 | 需要手动配置（ib-gateway-docker 封装）|
| 适合场景 | 云端 REST API | 本地/云端 TWS API |

---

## ibind

**GitHub**: https://github.com/Voyz/ibind  
**安装**: `pip install ibind`  
**用途**: IBKR Web API（CP API）的 Python 客户端

### 是什么

`ibind` 是专为 IBKR Web API 1.0 设计的 Python 库，提供：
- `IbkrClient`：REST API 封装，同步调用
- `IbkrWsClient`：WebSocket 客户端，线程安全，基于队列

支持标准 CP Gateway 认证（通过 ibeam）和 OAuth 1.0a 两种认证方式。

### REST 客户端

```python
from ibind import IbkrClient

client = IbkrClient(
    account_id='U1234567',
    url='https://localhost:5000/v1/api/',
    cacert=False,  # 本地测试关闭 SSL 验证
)

accounts = client.portfolio_accounts()
print(accounts.data)

positions = client.portfolio_positions()
for pos in positions.data:
    print(pos)

summary = client.account_summary()
print(summary.data)
```

### 行情数据

```python
# 股票实时快照（conid 是合约 ID，AAPL conid=265598）
snapshot = client.market_data_snapshot(conids=['265598'], fields=['31', '84', '86'])
# 31=last price, 84=bid, 86=ask

# 历史数据
history = client.market_data_history(conid='265598', period='1d', bar='1h')
```

### 下单

```python
# 市价买入 AAPL 1 股
order = {
    'conid': 265598,
    'orderType': 'MKT',
    'side': 'BUY',
    'quantity': 1,
    'tif': 'DAY',
}
result = client.place_order(account_id='U1234567', orders=[order])
print(result.data)
```

### WebSocket 客户端

```python
from ibind import IbkrWsClient, IbkrWsKey

ws_client = IbkrWsClient(account_id='U1234567', url='wss://localhost:5000/v1/api/ws', cacert=False)
ws_client.start()
ws_client.subscribe(channel=IbkrWsKey.PNL)

import queue
while True:
    try:
        msg = ws_client.queues[IbkrWsKey.PNL].get(timeout=5)
        print(msg)
    except queue.Empty:
        pass
```

可用 channel：`PNL`、`TRADES`、`ORDERS`、`MARKET_DATA`、`ACCOUNT_UPDATES`

### OAuth 1.0a（无 CP Gateway）

```python
client = IbkrClient(
    account_id='U1234567',
    url='https://api.ibkr.com/v1/api/',
    oauth=True,
    consumer_key='your_consumer_key',
    access_token='your_access_token',
    access_token_secret='your_access_token_secret',
    dh_prime='your_dh_prime',
)
```

OAuth 1.0a 适合已经完成 IBKR 审批和密钥配置的云端部署——不依赖任何本地 CP Gateway 进程，完全无头。

### ibind vs 裸 requests 对比

| 维度 | ibind | 裸 requests |
|------|-------|-------------|
| Session tickle | 自动处理 | 需手动定时 |
| 错误处理 | 统一封装 | 手写 |
| WebSocket | 内置队列模型 | 需自己实现 |
| OAuth 支持 | 内置 | 需手写签名逻辑 |
| 代码量 | 少 | 多 |

---

## Docker 镜像对比

两个主流社区 Docker 镜像均提供"IB Gateway + IBC + Xvfb + noVNC"的全套一体化封装，但设计取向不同。

---

### gnzsnz/ib-gateway

**GitHub**: https://github.com/gnzsnz/ib-gateway  
**镜像**: `ghcr.io/gnzsnz/ib-gateway`  
**维护者**: gnzsnz（同时也是 ib_async 贡献者、ib_fundamental 作者）

#### Docker Compose

```yaml
services:
  ib-gateway:
    image: ghcr.io/gnzsnz/ib-gateway:stable
    restart: unless-stopped
    env_file: .env
    ports:
      - "4003:4003"   # TWS API Paper
      - "4004:4004"   # TWS API Live
      - "6080:6080"   # noVNC
```

```bash
# .env
TWS_USERID=your_username
TWS_PASSWORD=your_password
TRADING_MODE=paper        # paper 或 live
VNC_SERVER_PASSWORD=changeme
AUTO_RESTART_TIME=11:59 PM
TWOFA_TIMEOUT_ACTION=restart
JAVA_HEAP_SIZE=1024       # MB，期权链建议 4096
ACCEPT_INCOMING_CONNECTION=accept
```

#### 连接方式

```python
from ib_async import IB
ib = IB()
ib.connect('127.0.0.1', 4003, clientId=1)  # Paper
# ib.connect('127.0.0.1', 4004, clientId=1)  # Live
```

#### 端口说明

| 宿主机 | 用途 |
|--------|------|
| 4003 | Paper Trading（socat 转发容器内 4002）|
| 4004 | Live Trading（socat 转发容器内 4001）|
| 6080 | noVNC 浏览器界面 |

#### Paper/Live 多容器分离

```yaml
services:
  ib-paper:
    image: ghcr.io/gnzsnz/ib-gateway:stable
    env_file: .env.paper
    ports:
      - "4003:4003"
      - "6080:6080"
  ib-live:
    image: ghcr.io/gnzsnz/ib-gateway:stable
    env_file: .env.live
    ports:
      - "4004:4004"
      - "6081:6080"
```

---

### extrange/ibkr-docker

**GitHub**: https://github.com/extrange/ibkr-docker  
**镜像**: `ghcr.io/extrange/ibkr`  

#### 特点

- **默认启动 TWS**（而非 IB Gateway），适合需要完整交易 GUI 的场景
- **单一 API 端口 8888**：容器内自动判断 trading mode，把正确的内部端口（4001/4002/7496/7497）转发到 8888
- `IBC_` 前缀环境变量可直接覆盖 IBC `config.ini` 任意字段，更灵活
- 需要设置 `ulimit nofile=10000`，否则启动失败

#### Docker Compose

```yaml
services:
  ibkr:
    image: ghcr.io/extrange/ibkr:latest
    ports:
      - "127.0.0.1:6080:6080"   # noVNC
      - "127.0.0.1:8888:8888"   # TWS API（统一端口）
    ulimits:
      nofile: 10000
    environment:
      USERNAME: ${USERNAME}
      PASSWORD: ${PASSWORD}
      # GATEWAY_OR_TWS: gateway  # 默认 tws，改为 gateway 则启动轻量版
      # TWOFA_TIMEOUT_ACTION: restart
      # IBC_TradingMode: 'paper'
      # IBC_ReadOnlyApi: 'yes'
      # TWS_SETTINGS_PATH: /settings
```

```bash
# .env
USERNAME=your_ibkr_username
PASSWORD='your_ibkr_password'  # 含 $、/、\ 时用单引号包裹
```

#### 连接方式

```python
from ib_async import IB
ib = IB()
ib.connect('127.0.0.1', 8888, clientId=1)  # paper/live 都用 8888
```

#### TWS 设置持久化（跨容器重启）

```yaml
environment:
  TWS_SETTINGS_PATH: /settings
volumes:
  - ./settings:/settings:rw
```

#### 注意事项

- 使用 TWS 时需手动在 TWS 界面开启 `Enable ActiveX and Socket Clients`（Gateway 则自动配置好）
- `IBC_` 变量中的布尔值必须用单引号包裹：`IBC_ReadOnlyApi: 'yes'`，否则 YAML 解析为 Python `True`

---

---

### UnusualAlpha/ib-gateway-docker

**GitHub**: https://github.com/UnusualAlpha/ib-gateway-docker  
**镜像**: `ghcr.io/unusualalpha/ib-gateway`  

#### 特点

- 组件与 gnzsnz 相同（IB Gateway + IBC + Xvfb + x11vnc + socat），但**无 noVNC**，VNC 需用独立 VNC 客户端连接
- 端口直接暴露 4001/4002（不通过 socat 二次映射），端口语义与原生 Gateway 一致
- VNC 默认关闭，仅当设置 `VNC_SERVER_PASSWORD` 时才启动
- 在自己的 GitHub Pages 上存档了历史版本的 IB Gateway 安装包，支持 pin 到指定版本重建镜像
- 安全提示明确：IB API 是未加密的裸 TCP，默认只绑定 127.0.0.1，跨机器访问需加 SSH tunnel 或 TLS

#### Docker Compose

```yaml
services:
  ib-gateway:
    image: ghcr.io/unusualalpha/ib-gateway:stable
    restart: always
    environment:
      TWS_USERID: ${TWS_USERID}
      TWS_PASSWORD: ${TWS_PASSWORD}
      TRADING_MODE: ${TRADING_MODE:-paper}
      READ_ONLY_API: "no"
      VNC_SERVER_PASSWORD: ${VNC_SERVER_PASSWORD:-}
    ports:
      - "127.0.0.1:4001:4001"   # Live
      - "127.0.0.1:4002:4002"   # Paper
      - "127.0.0.1:5900:5900"   # VNC（仅设置密码后生效）
```

```python
from ib_async import IB
ib = IB()
ib.connect('127.0.0.1', 4002, clientId=1)  # Paper
```

---

### heshiming/ibga

**GitHub**: https://github.com/heshiming/ibga  
**镜像**: `heshiming/ibga`  
**文档**: https://heshiming.github.io/ibga/

#### 特点

`ibga`（IB Gateway Automation）是与其他镜像**架构完全不同**的方案：不使用 IBC，而是自研 JAuto（JVMTI agent）+ xdotool 进行 GUI 自动化，直接识别 IB Gateway 界面元素并模拟键鼠输入。

最大亮点：**内置 TOTP 自动化**（oathtool 生成验证码），实现完全无人值守的 2FA 登录，不依赖 IBKR Mobile App 手动确认。

| 特性 | ibga | IBC 系镜像 |
|------|------|-----------|
| 底层实现 | JAuto + xdotool（自研）| IBC（Java）|
| TOTP 自动输入 | ✅ 内置（oathtool）| ⚠️ 需手机确认 |
| 每日自动重启 | ✅ | ✅ |
| Paper 确认对话框 | ✅ 自动处理 | ✅ |
| API 端口 | 4000（固定）| 4001/4002 |
| 社区规模 | 小（43 stars）| 大 |

#### Docker Compose

```yaml
services:
  ibga:
    image: heshiming/ibga
    restart: unless-stopped
    environment:
      - IB_USERNAME=your_username
      - IB_PASSWORD=your_password
      - IB_REGION=America            # America / Asia / Europe
      - IB_TIMEZONE=America/New_York
      - IB_LOGINTAB=IB API           # IB API / TWS
      - IB_LOGINTYPE=Live Trading    # Live Trading / Paper Trading
      - IB_LOGOFF=11:55 PM           # 每日登出时间
      - IB_LOGLEVEL=Error
    volumes:
      - ./run/program:/home/ibg
      - ./run/settings:/home/ibg_settings
    ports:
      - "4000:4000"     # TWS API
      - "15800:5800"    # noVNC
```

```python
from ib_async import IB
ib = IB()
ib.connect('127.0.0.1', 4000, clientId=1)
```

**适用场景**：需要全自动 TOTP 2FA 登录、不希望每次重启都手动确认手机通知的场景。代价是依赖自研 C 库，社区较小，出问题时排查资料少。

---

### 四镜像对比

| 维度 | gnzsnz | extrange | UnusualAlpha | ibga |
|------|--------|----------|--------------|------|
| 自动化实现 | IBC | IBC | IBC | JAuto + xdotool |
| 默认进程 | IB Gateway | TWS | IB Gateway | IB Gateway |
| API 端口 | 4003/4004 | 8888（统一）| 4001/4002（原生）| 4000 |
| noVNC | ✅ | ✅ | ❌（仅 VNC）| ✅ |
| TOTP 全自动 | ❌（需手机确认）| ❌（需手机确认）| ❌（需手机确认）| ✅ oathtool |
| ulimit 要求 | 无 | nofile=10000 | 无 | 无 |
| 维护活跃度 | 高 | 高 | 中 | 中 |

**选择建议：**
- 生产量化，追求稳定和社区支持 → **gnzsnz**
- 需要完整 TWS GUI 或偏好单端口 → **extrange**
- 偏好原生 4001/4002 端口语义、无需 noVNC → **UnusualAlpha**
- 需要 TOTP 全自动（无人值守 2FA）→ **ibga**（接受较小社区的代价）

---

## 其他实用工具

---

### ib_fundamental

**GitHub**: https://github.com/quantbelt/ib_fundamental  
**安装**: `pip install ib-fundamental`  
**维护者**: gnzsnz（同 ib-gateway-docker 作者）

#### 是什么

`ib_fundamental` 把 IBKR TWS API 的 `reqFundamentalData`（ticker 258）返回的 XML 解析为 pandas DataFrame，免去手动处理 XML 的麻烦。

**需要**: 对应 fundamentals 数据订阅（在 IBKR Account Management → Market Data Subscriptions 开通，价格以 IBKR 后台为准）。

#### 安装

```bash
pip install ib-fundamental
# 依赖 ib_async，需同时运行 TWS/Gateway
```

#### 用法

```python
import ib_async
from ib_fundamental import CompanyFinancials

ib = ib_async.IB()
ib.connect('127.0.0.1', 7497, clientId=1)

cf = CompanyFinancials('AAPL', ib)

# 年度资产负债表
df = cf.balance_annual
print(df)

# 季度收益
df = cf.income_quarter

# EPS（每股收益）
df = cf.eps_ttm       # 过去 12 个月
df = cf.eps_q         # 季度

# 现金流
df = cf.cashflow
df = cf.cashflow_quarter

# 股息
df = cf.dividends_ps_ttm

# 估值/分析师预测
df = cf.analyst_forecast

ib.disconnect()
```

#### 可用方法一览

`balance_annual`、`balance_quarter`、`cashflow`、`cashflow_quarter`、`income_annual`、`income_quarter`、`eps_q`、`eps_ttm`、`dividends_ps_q`、`dividends_ps_ttm`、`analyst_forecast`、`financial_ratios`

---

### ibkr-cli

**GitHub**: https://github.com/fatwang2/ibkr-cli  
**安装**: `pipx install ibkr-cli`  
**用途**: 轻量本地 CLI，profile 管理，安全预览再下单

#### 是什么

基于 `ib_async` + `Typer` + `Rich` 构建的本地命令行工具。设计原则：**预览优先**（`--preview` 估算，`--submit` 才真正下单），防止误操作。支持 JSON 输出，适合脚本化或 AI agent 调用。

#### 安装

```bash
pipx install ibkr-cli  # 隔离安装，推荐
# 或: pip install ibkr-cli
```

#### 常用命令

```bash
# 查看配置的 profile（默认: paper/live/gateway-paper/gateway-live）
ibkr profile list

# 连接测试
ibkr doctor --profile gateway-paper

# 账户 & 持仓
ibkr account summary --profile gateway-paper
ibkr positions --profile gateway-paper

# 行情
ibkr quote AAPL --profile gateway-paper
ibkr quote AAPL --watch --updates 5 --interval 2 --profile gateway-paper

# 历史 K 线
ibkr bars AAPL --duration "5 D" --bar-size "1 hour" --profile gateway-paper --json

# 期权链（需 Reuters Fundamentals 订阅）
ibkr options AAPL --profile gateway-paper

# 下单（必须先 preview，确认后再 submit）
ibkr buy AAPL 10 --preview --profile gateway-paper
ibkr buy AAPL 10 --submit --profile gateway-paper

# 查看 & 取消订单
ibkr orders open --profile gateway-paper
ibkr orders cancel 12345 --profile gateway-paper

# 更新
ibkr update
```

#### JSON 输出

```bash
ibkr quote AAPL --json --profile gateway-paper
ibkr positions --json --profile gateway-paper
ibkr buy AAPL 10 --preview --json --profile gateway-paper
```

---

### icli

**GitHub**: https://github.com/mattsta/icli  
**作者**: mattsta（ib_async 核心维护者之一）  
**用途**: 全功能交互式交易终端，面向快速交易和期权操作

#### 是什么

`icli` 是一个功能极为完整的 REPL 风格交易 CLI，主要面向主动交易者和期权交易者。特点是**快**——没有确认步骤，输入即执行。

#### 安装

```bash
git clone https://github.com/mattsta/icli
cd icli
poetry install
```

```bash
# 配置（.env.icli 或环境变量）
ICLI_IBKR_ACCOUNT_ID=U1234567
ICLI_IBKR_HOST=127.0.0.1
ICLI_IBKR_PORT=4001
```

```bash
poetry run icli
```

#### 核心功能

**批量行情订阅（模式展开语法）：**

```
add SPY240412{P,C}005{1,2,3}0000
# 展开为 6 个期权合约的实时报价

add SPX241{5..7}{P05135,C05150}000
# 范围展开
```

**下单语法：**

```
buy AAPL 100 AF            # 买 100 股，Adaptive Fast algo
buy AAPL $10_000 AF        # 按金额买（自动计算股数）
buy AAPL -100 AF           # 卖出（负数为 sell）
buy AAPL 100 AF @ 233.33   # 指定限价
buy AAPL 100 AF @ 233 + 10 # 自动附加止盈单（+$10）
buy AAPL 100 AF @ 233 - 10 # 自动附加止损单（-$10）
buy AAPL 100 AF @ 233 ± 10 # 同时附加止盈+止损（one-cancels-other）
```

**并发执行：**

```
buy META $15_000 AF&; buy MSFT $15_000 AF&; ls
# & 并发，; 顺序，ls 显示持仓
```

**批量买入（expand）：**

```
expand buy {META,MSFT,NVDA,AMD,AAPL} $15_000 MID
```

**一键清仓：**

```
evict * -1 0 MID    # 所有持仓以 midpoint 价格卖出
evict MSFT -1 0 AF  # 清空 MSFT
```

**条件单（ifthen）：**

```
if AAPL last > 300: buy AAPL 100 AF
# 每次 AAPL 行情更新时检查，满足条件即触发
```

**账户计算器（前缀语法）：**

```
(/ :BP3 AAPL)         # 用 1/3 可用资金能买多少 AAPL
(grow :AF 300)        # 可用资金增长 300% 后是多少
```

#### icli vs ibkr-cli 对比

| 维度 | icli | ibkr-cli |
|------|------|---------|
| 定位 | 主动交易 / 期权交易终端 | 简单 CLI 工具，脚本友好 |
| 确认步骤 | ❌ 无，输入即执行 | ✅ 需 --preview 后 --submit |
| 期权支持 | ✅ 完整（OCC 格式）| ✅ 基础 |
| JSON 输出 | ❌ | ✅ |
| AI agent 集成 | ❌ | ✅ 有 skill |
| 安装方式 | poetry（需克隆仓库）| pipx install |
| 适合人群 | 主动交易者，熟悉终端 | 开发者，脚本/自动化 |

---

### ibkr-mcp

**PyPI**: https://pypi.org/project/ibkr-mcp/  
**安装**: `pip install ibkr-mcp`  
**用途**: 让 Claude Desktop 等 AI 客户端直接操作 IBKR 账户

#### 是什么

`ibkr-mcp` 实现了 Model Context Protocol（MCP），让支持 MCP 的 AI 客户端（Claude Desktop、Cursor 等）可以通过自然语言查询账户、分析期权、评估风险。

#### 配置（Claude Desktop）

```json
{
  "mcpServers": {
    "ibkr-mcp": {
      "command": "uvx",
      "args": ["ibkr-mcp"],
      "env": {
        "IBKR_HOST": "127.0.0.1",
        "IBKR_PORT": "4001",
        "IBKR_ACCOUNT": "U1234567",
        "IBKR_MCP_MARKET_DATA_TYPE": "DELAYED"
      }
    }
  }
}
```

#### 可用 MCP 工具

| 工具 | 说明 |
|------|------|
| `get_account_summary` | 账户余额、可用资金 |
| `get_portfolio` | 持仓 + P&L |
| `get_greeks_summary` | 组合 Greeks（delta/gamma/theta/vega）|
| `get_option_chains` | 期权链快照 |
| `scan_option_signals` | 期权策略信号扫描 |
| `evaluate_portfolio_risk` | 风险评估（对比配置限额）|
| `generate_playbook_actions` | 自动生成调仓建议 |
| `get_historical_news` | 历史新闻查询 |

#### 风险规则配置（risk.yaml）

```yaml
limits:
  max_delta: 100
  max_theta: -500
  max_concentration: 0.25
roll_rules:
  min_dte: 7
  target_delta: 0.30
```

#### 自然语言查询示例

一旦接入 AI 客户端，可以直接问：
- "我的账户余额和购买力是多少？"
- "AAPL 下月到期的期权链是什么？"
- "评估我的组合风险并建议调仓"
- "找一下我的持仓里有哪些 covered call 机会"

---

## 工具组合选型

### TWS API 路径（个人量化，推荐）

```
策略代码（ib_async）
  ↓ TCP :4003
gnzsnz/ib-gateway（或 extrange/ibkr-docker）
  内含 IBC 自动登录 + Xvfb + noVNC
```

```yaml
services:
  ib-gateway:
    image: ghcr.io/gnzsnz/ib-gateway:stable
    env_file: .env
    ports:
      - "4003:4003"
      - "6080:6080"
```

### Web API 路径（云端/轻量）

```
策略代码（ibind）
  ↓ HTTPS :5000
ibeam（Selenium 自动登录 CP Gateway）
```

```yaml
services:
  ibeam:
    image: voyz/ibeam:latest
    env_file: ibeam.env
    ports:
      - "5000:5000"
```

### 选型矩阵

| 需求 | 工具组合 |
|------|---------|
| Python 量化，服务器无头 | ib_async + gnzsnz/ib-gateway |
| Python 量化，需要完整 TWS GUI | ib_async + extrange/ibkr-docker（默认 TWS）|
| Web API，快速原型 | requests + ibeam Docker |
| Web API，生产代码 | ibind + ibeam Docker |
| Web API，完全无头（无 CP Gateway）| ibind + OAuth 1.0a |
| 获取公司基本面数据 | ib_fundamental（需 Reuters 订阅）|
| 脚本化 / AI agent 调用 IBKR | ibkr-cli（JSON 输出）|
| 主动交易者，期权操作 | icli（全功能交互终端）|
| AI 客户端直接操作账户 | ibkr-mcp（Claude Desktop / Cursor）|
| 需要 tick 数据 / algo 订单 | **必须用 TWS API 路径**，Web API 不支持 |

### 维护状态提示

这些工具都属于社区项目，维护状态、镜像标签、环境变量和登录自动化能力会随 IBKR 登录界面与 API 版本变化。生产环境使用前应检查对应 GitHub 仓库的最新 release、issue 和镜像更新时间，并固定版本部署。
