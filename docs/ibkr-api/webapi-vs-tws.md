# Web API vs TWS API 功能对比

IBKR 官方的定位：Web API 是"modern REST API，功能最广泛"，TWS API 是"交易导向，支持完整订单类型"。实际含义是：Web API 在账户管理、开户、资金方面更完整，但 TWS API 在**纯交易**和**市场数据**维度上仍有关键优势。

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
| 实时流式行情（WebSocket）| ✅ 持续订阅，无需轮询 | ✅ WebSocket，但依赖轮询触发 |
| **Tick-by-Tick 逐笔成交** | ✅ `reqTickByTickData()` | ❌ **不支持** |
| **实时 5 秒 Bar** | ✅ `reqRealTimeBars()` | ❌ **不支持** |
| Level 2 市场深度（委托簿）| ✅ 最多 3 个并发 | ✅（有限制）|
| 历史 K 线 | ✅ 最远 20 年+，多种粒度 | ✅ 但粒度/深度有限 |
| 历史 Tick 数据 | ✅ `reqHistoricalTicks()` | ❌ **不支持** |
| 市场扫描器（Streaming）| ✅ 订阅推送 | ✅ 仅轮询 |
| 基本面数据（WSH 日历/财报）| ✅ | ⚠️ 部分支持（Morningstar 已移除）|
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
| Combo/Spread 多腿复合单 | ✅ BAG 类型，6 条腿 | ⚠️ 有限支持 |
| 分配单（FA Block Allocation）| ✅ | ✅ |

**最关键差异**：所有 IBKR 算法订单（VWAP/TWAP/Adaptive Price/Arrival Price）只在 TWS API 上可用。Iceberg、Accumulate/Distribute 同样只有 TWS API。

---

### 3. 请求速率

| 指标 | TWS API | Web API（CP Gateway）| Web API（OAuth）|
|------|---------|---------------------|----------------|
| 全局速率上限 | 50 消息/秒（随账户 market data lines 扩展）| **10 请求/秒（硬限制）** | 50 请求/秒 |
| 超限后行为 | Error 100，3 次违规断线 | 429，IP 进 penalty box 15 分钟 | 429 |
| 历史数据并发 | 50 | 5（`/iserver/marketdata/history`）| 5 |
| 快照数据 | —（基于 market data lines）| 10 次/秒 | 10 次/秒 |
| 扫描器 | 适度 | 1 次/15 分钟（params），1 次/秒（run）| 同左 |

**最关键差异**：CP Gateway 的 10 req/s 硬上限是一条严格红线。高频数据采集（监控几十个标的）用 Web API Gateway 很快触达上限；TWS API 可以同时订阅数百条 streaming 行情线，只要在账户 market data lines 限制内。

---

### 4. 连接与 Session 管理

| 维度 | TWS API | Web API |
|------|---------|---------|
| 协议 | TCP Socket 长连接 | HTTPS 请求/WebSocket |
| Session 超时 | ❌ 无（只要 TWS/Gateway 在线）| ⚠️ **60 分钟无操作超时，需 tickle 保活** |
| 并发 brokerage session | 多个 clientId 可同时连接 | **每个用户名只能有 1 个 brokerage session** |
| Session 冲突 | 无 | 登录 TWS / Client Portal / Mobile 会**踢掉** API session |
| 重连难度 | 事件驱动（`disconnectedEvent`）| 需要重新走 session 初始化流程 |
| TWS 每日重启影响 | 每日约 23:45 UTC 断线需重连 | 每日约 01:00 local 短暂维护 |

**最关键差异**：Web API 的单 session 限制是生产系统的核心痛点。如果用户同时打开了 Client Portal 网页、手机 App 或 TWS 桌面，API session 会被踢掉，不会有任何警告，下单请求直接失败。TWS API 没有这个限制。

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
| 本地依赖 | 必须运行 TWS 或 IB Gateway | 必须运行 CP Gateway 或 ibeam Docker |
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
| 用户账号同时使用 TWS + API | **必须 TWS API**，Web API 会被踢 session |
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

TWS API 完全没有这个问题：多个 clientId 可以同时连接，互不干扰。
