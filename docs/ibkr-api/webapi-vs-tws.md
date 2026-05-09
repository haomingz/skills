# Web API vs TWS API 功能对比

IBKR 正在把 Client Portal Web API、Digital Account Management 和 Flex Web Service 归到统一的 **Web API** 伞下；旧的 CP Gateway/OAuth 1.0a 路径仍继续可用。实际选型上，Web API 在账户管理、开户、资金和标准 HTTP 集成方面更合适，但 TWS API 在**纯交易**和**市场数据**维度上仍有关键优势。

---

## 一句话结论

| 需求 | 选择 |
|------|------|
| 个人量化交易、实时数据、完整订单类型 | **TWS API** |
| 云端 Web 应用、开户/资金管理、FA 机构后台 | **Web API** |
| 超高频、机构级低延迟 | FIX API |

---

## 完整功能对比

### 1. 市场数据

| 功能 | TWS API | Web API |
|------|---------|---------|
| 实时快照（Level 1） | ✅ | ✅（最多 100 conids/次）|
| 实时流式行情 | ✅ 持续订阅，无需轮询 | ✅ WebSocket/REST 均有，但核心 snapshot 端点仍按请求限速 |
| **Tick-by-Tick 逐笔成交** | ✅ `reqTickByTickData()` | ❌ **不支持** |
| **实时 5 秒 Bar** | ✅ `reqRealTimeBars()` | ❌ **不支持** |
| Level 2 市场深度（委托簿）| ✅ 最多 3 个并发 | ✅（有限制）|
| 历史 K 线 | ✅ 最远 20 年+，多种粒度 | ✅ 但粒度/深度有限 |
| 历史 Tick 数据 | ✅ `reqHistoricalTicks()` | ❌ **不支持** |
| 市场扫描器（Streaming）| ✅ 订阅推送 | ✅ 仅轮询 |
| 基本面/日历/新闻 | ✅ | ⚠️ 端点覆盖不同，需按具体数据集核对 |
| 新闻（流式）| ✅ | ⚠️ 有限 |
| 期权隐含波动率/历史波动率 | ✅ | ⚠️ 部分支持 |

**最关键差异**：TWS API 支持 tick-by-tick 逐笔和 5 秒实时 bar；Web API 完全没有这两个。需要高精度入场信号或微结构数据的策略必须用 TWS API。

---

### 2. 订单类型

官方原话：Web API = "Broad Selection of Order Types"，TWS API = "**Access to IBKR's entire suite of Order Types**"。

| 订单类型 | TWS API | Web API |
|---------|---------|---------|
| 市价 / 限价 / 止损 | ✅ | ✅ |
| 跟踪止损（TRAIL / TRAIL LIMIT）| ✅ | ✅（2022 年后加入）|
| Bracket 组合单 | ✅ | ✅ |
| 收盘市价/限价（MOC/LOC）| ✅ | ✅ |
| **IB Algorithmic Orders（IBALGO）** | ✅ VWAP/TWAP/Adaptive/Arrival Price 等 | ❌ **不支持** |
| **Accumulate/Distribute Algo** | ✅ | ❌ **不支持** |
| **Price-Pegged 订单（REL/MID）** | ✅ | ⚠️ 部分支持 |
| **Iceberg / Reserve 订单** | ✅ | ❌ **不支持** |
| One-Cancels-All（OCA）| ✅ | ⚠️ 有限 |
| 期货市价保护单（MKT PRT）| ✅ | ❌ |
| Combo/Spread 多腿复合单 | ✅ BAG/Combo 支持，腿数受交易所和产品限制 | ⚠️ 有限支持 |
| 分配单（FA Block Allocation）| ✅ | ✅ |

**最关键差异**：所有 IBKR 算法订单（VWAP/TWAP/Adaptive Price/Arrival Price）只在 TWS API 上可用。Iceberg、Accumulate/Distribute 同样只有 TWS API。

---

### 3. 请求速率

| 指标 | TWS API | Web API |
|------|---------|---------|
| 全局速率上限 | 50 消息/秒（Error 100）| **10 请求/秒/用户名** |
| 超限后行为 | Error 100，可能断开客户端 | 429，违规 IP 可能进入约 10 分钟 penalty box |
| 历史数据并发 | 50 | 5（`/iserver/marketdata/history`）|
| 快照数据 | 基于 market data lines | `/iserver/marketdata/snapshot` 10 次/秒 |
| 扫描器 | 流式/请求式 | `params` 1 次/15 分钟，`run` 1 次/秒 |

**最关键差异**：Web API 的 10 req/s/用户名是严格红线。高频数据采集（监控几十个标的）用 Web API 很快触达上限；TWS API 更适合持续 streaming，但仍受账户 market data lines 限制（默认 100 条，可按权益、佣金或 booster 扩展）。

---

### 4. 连接与 Session 管理

| 维度 | TWS API | Web API |
|------|---------|---------|
| 协议 | TCP Socket 长连接 | HTTPS 请求/WebSocket |
| Session 超时 | TWS/Gateway 在线时 API socket 可持续；仍会受每日维护/重启影响 | 会无操作超时，需定期 `/tickle` 保活 |
| 并发连接 | 多个 `clientId` 可同时连接同一个 TWS/Gateway；该登录进程本身占用一个用户名 session | 每个用户名只能有 1 个 brokerage session；部分只读端点可不建立 brokerage session |
| Session 冲突 | TWS/Gateway 也可能遇到 competing session；IBC 可配置如何响应 | 登录 TWS / Client Portal / Mobile 可能使 Web API brokerage session 失效 |
| 重连难度 | 事件驱动（`disconnectedEvent`）| 需要重新走 session 初始化流程 |
| TWS 每日重启影响 | 每日约 23:45 UTC 断线需重连 | 每日约 01:00 local 短暂维护 |

**最关键差异**：Web API 的单 brokerage session 限制是生产系统的核心痛点。如果同一用户名同时打开 Client Portal、手机 App、TWS 或 CP Gateway，session 可能竞争并导致交易端点失败。TWS API 不能消除用户名级竞争，但把多个策略脚本集中连接到同一个 TWS/Gateway 进程后，脚本之间可以用不同 `clientId` 共存。

---

## 多 Session 问题深度解析

### 两套 API 的根本差异

**TWS API** 的连接是纯 TCP socket，由 IB Gateway / TWS 进程管理：

- 多个策略脚本可以用不同 `clientId` 同时连接同一个 Gateway，互不干扰
- 移动端 IBKR App、TWS、IB Gateway 仍可能竞争同一用户名的 brokerage session
- IBC 可通过 `ExistingSessionDetectedAction` 配置遇到已有 session 时的行为（例如覆盖、等待或退出）；是否自动覆盖应按账户风控决定

**Web API** 的连接建立在 IBKR 的 "brokerage session" 之上：

- 每个 IBKR 用户名同一时刻只允许一个活跃的 brokerage session
- 移动 App、Client Portal 网页、CP Gateway 三者共用同一个 brokerage session 池
- 任何一方发起新的 brokerage session，其他方的 session 即刻失效
- 失效可能表现为 `competing` 状态、403、503、空结果或交易端点失败；需要应用层显式检测 `/iserver/auth/status`

### 实际冲突场景

```
场景一：移动端看行情踢掉 API（最常见）
  手机打开 IBKR App（自动建立 brokerage session）
    → CP Gateway 的 brokerage session 失效
      → /iserver/accounts 返回空，下单返回 503
        → 策略无声停止，直到手动重新认证

场景二：忘记登出 Client Portal 网页
  浏览器访问 Client Portal 页面
    → 建立新 brokerage session
      → Gateway session 被踢

场景三：Gateway 重启后与移动 App 竞争
  Gateway 每日自动重启，重新建立 brokerage session
    → 若此时手机也在线，双方互相踢，陷入认证死循环
```

### TWS API 的同场景表现

同一账号同时使用移动 App + IB Gateway（TWS API 路径）时：

- 移动 App 打开 IBKR 会触发 brokerage session 竞争，Gateway 可能短暂被踢
- IBC 配置 `ExistingSessionDetectedAction=primaryoverride` 后，可在检测到已有 session 时尝试覆盖并继续登录；这能降低人工干预，但不等于交易系统无需处理重连和权限恢复
- 竞争过程中可能出现 Error 10197（"No market data during competing live session"）或行情短暂不可用；策略仍应处理行情恢复和重新订阅

### 结论：应用层兜不住，只有两条路

**Web API 的 brokerage session 由 IBKR 服务端控制，应用层无法从根本上规避同一用户名的竞争。** `/logout` + `/reauthenticate` 的恢复脚本、定时重启 ibeam 容器等手段可以缓解，但如果另一个客户端持续占用同一用户名，交易端点仍会反复失效。

真正有效的只有两条路：

#### 路径一：改用 TWS API + IB Gateway（推荐）

IB Gateway 与 CP Gateway 的关键区别在于：TWS API 允许多个策略脚本共用一个 Gateway 登录进程；IBC 还可以配置遇到已有 session 时的处理动作：

- 手机用 IBKR App 触发 session 竞争 → Gateway/IBC 按配置处理 → 策略脚本仍需处理短暂断线、行情重订阅和订单状态核对
- 多个策略脚本用不同 `clientId` 可同时连接同一个 Gateway
- 夺回过程中偶发 Error 10197（行情权限短暂受限，非断连）：Gateway 恢复后自动消失

IB Gateway 每天约 23:45 UTC 自动重启断线约 1–5 分钟，需要自动重连逻辑覆盖（见 `references/common-recipes.md` 自动重连章节）。

#### 路径二：Web API + 专用 API 子账号

IBKR 个人账号可以在 **Account Management → Settings → Users & Access Rights → Add User** 添加额外登录用户。每个用户名有完全独立的 brokerage session：

```
主用户 myaccount      → 手机 IBKR App / Client Portal 日常使用
子用户 myaccount_api  → CP Gateway / ibeam 专用，永远不在移动端登录
```

这样两个用户名各自维护独立的 session，互不干扰。代价是需要维护两套登录凭据；市场数据订阅、交易权限按用户名生效；子账号登录 CP Gateway 后依然需要定期 tickle 保活。

### 推荐决策

```
同时使用移动 App + API 策略？

  首选 → TWS API（IB Gateway + ib_async）
         可让多个策略脚本共用一个 Gateway 登录进程
         IBC 可配置 session 竞争时的处理动作
         仍需处理每日维护/重启、行情重订阅和订单状态核对

  次选 → Web API + 创建专用 API 子账号（Users & Access Rights）
         两套用户名各走各的 session，彻底隔离

  不可行 → 同一账号同时跑 Web API + 移动 App
           CP Gateway 无法从根本上避免同一用户名的 brokerage session 竞争
```

---

### 5. 合约覆盖

| 资产类别 | TWS API | Web API |
|---------|---------|---------|
| 美股 / ETF | ✅ | ✅ |
| 期权（美式/欧式）| ✅ | ✅ |
| 期货 | ✅ | ✅（但部分 algo 类型不支持）|
| 期货期权（FOP）| ✅ | ⚠️ 有限 |
| 外汇（Spot Forex）| ✅ | ✅ |
| CFD | ✅ | ✅ |
| 债券 | ✅ | ⚠️ 有限 |
| 共同基金 | ✅ | ⚠️ 有限 |
| 加密货币 | ⚠️ 有限（ZEROHASH/PAXOS）| ⚠️ 有限 |
| 全球股票（150+ 市场）| ✅ | ✅ |
| Combo / Spread | ✅ BAG 完整支持 | ⚠️ 有限 |

---

### 6. 账户与报告（Web API 独有）

这一维度 **Web API 反超 TWS API**：

| 功能 | TWS API | Web API |
|------|---------|---------|
| 实时账户余额/持仓 | ✅ | ✅ |
| P&L 实时流 | ✅ | ✅ |
| **开户（数字化注册）** | ❌ | ✅ **独有** |
| **资金划转（入金/出金）** | ❌ | ✅ **独有**（Enterprise）|
| **账户维护（地址/税务等）** | ❌ | ✅ **独有** |
| Flex 查询（历史报表）| 有限 | ✅ |
| Portfolio Analyst | ❌ | ✅ |
| 历史交易记录 | ✅ | ✅ |
| **Real-Time Drop Copy** | ❌ | ✅ **独有** |
| FA 子账户管理 | ✅（有限）| ✅（更完整）|

---

### 7. 开发体验

| 维度 | TWS API | Web API |
|------|---------|---------|
| 语言支持 | Python/Java/C++/C#/VB.NET（官方）| 任意语言（标准 HTTP）|
| 推荐 Python 库 | `ib_async`（第三方）| `requests`（标准库）|
| 本地依赖 | 必须运行 TWS 或 IB Gateway | CP Gateway/ibeam，或已获批并配置好的 OAuth 直连 |
| 调试工具 | TWS 图形界面可视化确认 | Postman / curl 直接调试 |
| 代码架构 | 异步回调（ibapi）或同步封装（ib_async）| 同步 REST（简单）+ WebSocket（流式）|
| 并发性能 | 高（单连接处理百条 streaming）| 低（10 req/s 限制，REST 顺序执行）|
| 文档成熟度 | 更成熟，社区资源丰富 | 更新较快，部分文档仍为 beta |

---

## 总结：各场景选哪个

| 场景 | 结论 |
|------|------|
| 量化策略需要实时 tick 或 5 秒 bar | **必须 TWS API**，Web API 没有 |
| 需要 VWAP/TWAP/Adaptive 等算法订单 | **必须 TWS API**，Web API 没有 |
| 同时监控 50+ 标的实时行情 | **推荐 TWS API**，Web API 10 req/s 容易触顶 |
| 策略频繁下单（>10 次/秒）| **推荐 TWS API**，Web API Gateway 硬限 10/s |
| 同时使用移动 App + API 策略 | **推荐 TWS API**，多个脚本可共用同一 Gateway；仍需处理用户名 session 竞争 |
| Cloud 服务器，不想运行 Java 桌面进程 | Web API + ibeam Docker |
| 需要开户 / 资金划转 / 报表 API | **必须 Web API** |
| 轻量查询持仓/余额/当日订单 | Web API 够用 |
| FA 机构管理多个子账户 | 两者均可，Web API 更完整 |
| 非 Python 环境（Go/JS/Rust）| Web API 更容易集成 |

## 一个常被忽视的陷阱

Web API 的单 session 限制在实际生产中频繁造成问题：

```
用户在手机打开 IBKR App
  → 建立新 brokerage session
    → 当前 API session 被踢掉
      → 后续下单请求返回 403/session error
        → 策略无声地停止工作
```

TWS API 同样有 session 竞争，但多个策略脚本可以通过不同 `clientId` 同时连接同一个 Gateway，脚本之间互不干扰。IBC 的 `ExistingSessionDetectedAction=primaryoverride` 可降低人工处理 session 冲突的频率，但生产策略仍应实现重连、行情重订阅和订单状态核对。

关于多 session 冲突的完整分析（包括 TWS API vs Web API 的底层机制差异、创建专用 API 子账号的方法、以及各类社区解法），参见上方 [多 Session 问题深度解析](#多-session-问题深度解析)。
