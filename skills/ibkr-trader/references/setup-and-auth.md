# IBKR 连接配置与认证

## Contents
- API 类型选择
- TWS / IB Gateway 安装与配置
- 端口与连接参数
- IBC 自动登录（TWS/Gateway）
- ibeam Docker（Web API Gateway）
- 连接模式与重连逻辑
- 常见连接问题排查

---

## API 类型选择

| API | 协议 | Python 库 | 适用场景 |
|-----|------|-----------|---------|
| **TWS API** | TCP Socket | `ib_async` / `ibapi` | 功能最全，实时数据+完整订单类型+期货/外汇 |
| **Web API（CP API）** | REST + WebSocket | `requests` / `ibwebapiclient` | 轻量 HTTP，无需 socket，适合简单账户查询 |
| **FIX API** | FIX 协议 | 机构专用 | 超高频，需申请开通 |

**大多数场景使用 TWS API + ib_async。** Web API 适合部署在无桌面环境但可以运行 Docker 的云服务器（配合 ibeam）。

---

## TWS / IB Gateway 安装与配置

### 下载

- IB Gateway（推荐用于 API）：https://www.interactivebrokers.com/en/trading/ib-api.php
  - Stable 版本：每隔数月更新，更稳定
  - Latest 版本：每周更新，包含最新特性
- Trader Workstation（TWS）：有图形界面，便于调试，但更耗资源

**推荐使用 IB Gateway**：相比 TWS 占用约 40% 更少资源，无图形界面干扰。

### TWS API 设置（TWS）

`Edit → Global Configuration → API → Settings`

| 设置项 | 值 | 说明 |
|--------|-----|------|
| Enable ActiveX and Socket Clients | ✅ 开启 | 必须，否则无法连接 |
| Socket port | `7496`（实盘）/ `7497`（Paper） | 与 `ib.connect()` 端口一致 |
| Read Only API | ❌ 关闭 | 下单时必须关闭 |
| Download open orders on connection | ✅ 开启 | 连接时同步历史订单 |
| Master Client ID | 可选 | 指定后该 clientId 可收到所有订单更新 |
| Create API message log file | ✅ 调试时开启 | 记录所有 API 消息 |

### IB Gateway 设置

`Configure → API → Settings`（同上；Gateway 默认已启用 socket）

### 内存设置（批量数据必须）

`Configure → Settings → Memory Allocation`

设置为 **4096 MB** 最小值，拉取大量期权链时防止 Gateway 崩溃。

---

## 端口与连接参数

| 环境 | 应用 | 端口 |
|------|------|------|
| 实盘账户 | TWS | 7496 |
| Paper（纸面交易） | TWS | 7497 |
| 实盘账户 | IB Gateway | 4001 |
| Paper（纸面交易） | IB Gateway | 4002 |

```python
from ib_async import IB

ib = IB()

# Paper TWS（最常用于开发测试）
ib.connect('127.0.0.1', 7497, clientId=1)

# Paper Gateway
# ib.connect('127.0.0.1', 4002, clientId=1)

# 实盘 Gateway（谨慎）
# ib.connect('127.0.0.1', 4001, clientId=1)
```

**clientId 规则**：
- 同一 TWS 实例内必须唯一（0-999）
- 多进程/多脚本同时运行时，每个用不同的 clientId
- clientId=0 是特殊的 master client

---

## IBC 自动登录（TWS/Gateway 无头运行）

[IBC](https://github.com/IbcAlpha/IBC) 自动化 TWS/Gateway 的登录流程，实现定时重启和无人值守运行。

**适用场景**：服务器上运行 TWS API，需要每日自动重启并重新认证。

### 安装

```bash
# Linux/macOS
wget https://github.com/ibcalpha/ibc/releases/latest/download/IBCLinux-3.x.x.zip
unzip IBCLinux-3.x.x.zip -d ~/ibc

# Windows（用对应 Windows 版本 ZIP）
```

### 配置（config.ini 关键项）

```ini
IbLoginId=your_username
IbPassword=your_password
TradingMode=paper        # 或 live
FIX=no
ReadonlyLogin=no
AcceptIncomingConnectionAction=accept
SendTWSLogsToAgent=no
# 自动处理系统重启
ExistingSessionDetectedAction=secondary
# 每日自动重启时间（UTC）
IbAutoClosedown=no
ClosedownAt=                         # 留空=不自动关闭
```

### 注意事项

- IBC 只适用于 **offline（非自动更新）版本** 的 TWS/Gateway
- 需要 2FA 时，IBC 支持配合 IBKR Mobile 完成（可配置重试窗口）
- 不支持硬件 token 认证方式

---

## ibeam Docker（Web API Gateway 无头认证）

[ibeam](https://github.com/Voyz/ibeam) 专门用于 **Client Portal Web API Gateway** 的无头认证，基于 Selenium + 虚拟显示。

**适用场景**：使用 Web API（REST）而非 TWS API，部署在没有桌面的 Linux 服务器/容器环境。

### Docker Compose

```yaml
services:
  ibeam:
    image: voyz/ibeam
    container_name: ibeam
    env_file:
      - env.list
    ports:
      - 5000:5000   # API 端口
      - 5001:5001
    network_mode: bridge   # clientportal.gw IP 白名单要求
    restart: 'no'          # 防止超出最大失败次数后循环重启
```

`env.list` 文件：

```
IBEAM_ACCOUNT=your_account123
IBEAM_PASSWORD=your_password123
```

启动后验证：

```bash
curl -X GET "https://localhost:5000/v1/api/one/user" -k
```

### ibeam 安全提示

- 凭据以明文存储在环境变量中，存在安全风险
- **强烈建议先用 Paper Account 凭据测试**
- 生产环境可使用 Docker Swarm Secrets 减少凭据暴露面

---

## 连接模式与重连逻辑

### 基本连接（同步）

```python
from ib_async import IB

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)
```

### 带超时的连接检查

```python
import time

def connect_with_retry(host='127.0.0.1', port=7497, client_id=1, max_retries=5):
    ib = IB()
    for attempt in range(max_retries):
        try:
            ib.connect(host, port, clientId=client_id)
            print(f"Connected on attempt {attempt + 1}")
            return ib
        except ConnectionRefusedError:
            print(f"Connection refused, retry {attempt + 1}/{max_retries} in {2**attempt}s")
            time.sleep(2 ** attempt)
    raise RuntimeError("Failed to connect after retries")

ib = connect_with_retry()
```

### 断连事件处理

```python
def on_disconnected():
    print("Disconnected from TWS/Gateway")
    # 可在此触发重连逻辑

ib.disconnectedEvent += on_disconnected
```

### 异步连接（Jupyter/asyncio 环境）

```python
from ib_async import IB, util

util.startLoop()  # 仅在 Jupyter Notebook 中需要

ib = IB()
ib.connect('127.0.0.1', 7497, clientId=1)
```

---

## 常见连接问题排查

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| `ConnectionRefusedError` | TWS/Gateway 未运行或 API 未启用 | 确认应用已启动且 Enable Socket Clients 已勾选 |
| Error 507 "Bad Message Length" | clientId 已被使用，或 TWS 锁定 | 换一个 clientId；检查 TWS 是否锁屏 |
| Error 502 "Couldn't connect to TWS" | 端口不匹配 | 确认 connect() 端口与 API Settings 端口一致 |
| 请求无响应 | 连接时未等待 2104/2106 通知 | 连接后 `ib.sleep(2)` 再发请求 |
| 行情数据全为 0 | 超出市场数据线上限（默认 100 条） | `Ctrl+Alt+=` 查看当前使用量；取消不用的订阅 |
| 历史数据 Error 162 | Pacing violation（请求过于频繁） | 相同合约请求间隔 > 15 秒；10 分钟内 < 60 次 |
| Error 200 "No security definition" | 合约未 qualify 或参数错误 | 先调用 `qualifyContracts()`；检查 exchange/currency |
