# ThinkOrSwim（TOS）API 说明

## 结论先说

**ThinkorSwim 没有官方公开 API。**

TOS 是 Schwab 旗下的交易平台（前 TD Ameritrade 资产），它内部使用一个 WebSocket 协议（wsjson）与服务器通信。这个协议从未被官方文档化，但已被社区逆向工程。

**对于绝大多数自动化交易需求，推荐用 Schwab Trader REST API（即 `schwab-py` 封装的那个），而不是 TOS 的内部协议。**

---

## TOS 与 Schwab API 的关系

| 维度 | Schwab Trader API | TOS 内部 API |
|------|------------------|-------------|
| 官方状态 | ✅ 官方支持，有文档 | ❌ 未文档化，逆向工程 |
| 账户 | 相同账户 | 相同账户 |
| 稳定性 | 高，有 SLA | 低，随 TOS 客户端更新可能失效 |
| 语言支持 | 任意（REST） | Node.js（非官方库） |
| 推荐程度 | ✅ 首选 | ⚠️ 仅学习/实验 |

TOS 和 Schwab REST API 操作的是**完全相同的账户和持仓**。在 TOS 桌面端下单，通过 Schwab API 也能看到；反之亦然。

---

## TOS 内部 WebSocket API（wsjson 协议）

### 基本信息

- **协议**：WebSocket，消息格式为自定义 JSON
- **端点**：`wss://thinkorswim.schwabmeritrade.com/ws` （可能随版本变化）
- **认证**：使用 Schwab OAuth access token（与 REST API 相同）
- **状态**：非官方、未文档化、社区逆向工程

### 社区实现

唯一较为完整的实现：

**huskly/tos-wsjson-client**（TypeScript/Node.js）
- GitHub: `https://github.com/huskly/tos-wsjson-client`
- 语言：TypeScript，支持 Node.js 和浏览器

已支持的功能：
- 认证（Schwab OAuth token）
- 实时报价
- 历史图表（Price History）
- 账户持仓
- 下单 / 撤单
- 期权链 / 期权报价
- 市场深度（Level 2）
- 自选股列表
- 订单事件推送
- 创建 / 取消价格提醒

### Node.js 使用示例

```typescript
import { WsJsonClient } from "tos-wsjson-client";

const client = new WsJsonClient();

// 使用 Schwab OAuth access token 认证（与 REST API 相同的 token）
await client.authenticateWithAccessToken(accessToken, refreshToken);

// 实时报价
for await (const { body: quote } of client.quotes(["AAPL", "TSLA"])) {
  console.log(quote);
}

// 历史图表
const chartRequest = {
  symbol: "SPY",
  timeAggregation: "DAY",
  range: "YEAR1",
  includeExtendedHours: false,
};
for await (const { body: candle } of client.chart(chartRequest)) {
  console.log(candle);
}

// 账户持仓
const positions = await client.accountPositions("YOUR_ACCOUNT_ID");

// 下单
const order = {
  symbol: "AAPL",
  quantity: 1,
  orderType: "MARKET",
  instruction: "BUY",
  assetType: "EQUITY",
};
await client.placeOrder(order);
```

---

## TOS 专有功能（REST API 无法替代的部分）

这些功能**只有通过 TOS 平台**才能使用，无论是 REST API 还是 wsjson 协议都不能完全复制：

| 功能 | 说明 |
|------|------|
| **thinkScript** | TOS 专有策略脚本语言，用于创建自定义指标和扫描器 |
| **策略分析器** | 期权盈亏图、Greeks 可视化 |
| **backtesting** | TOS 内置的历史回测引擎 |
| **扫描器（Scanner）** | 基于 thinkScript 条件的市场扫描 |
| **概率分析** | 期权到期概率锥 |
| **400+ 内置技术指标** | RSI、MACD、布林带等（当然自己也能算） |

这些都是 TOS **平台功能**，不对外暴露 API。

---

## 什么时候考虑 TOS wsjson API？

**几乎不需要考虑**，除非：

1. **你已经在做 Node.js 项目**，不想引入 Python 依赖
2. **你想获取 TOS 特有的数据格式**，与 REST API 响应格式不同
3. **纯学习目的**，想理解 TOS 内部如何工作

**不推荐在生产交易系统中使用**，原因：
- TOS 客户端任何版本更新都可能导致协议变化
- 无官方支持，出问题无处求助
- 社区库维护不稳定

---

## 实际推荐路径

```
需要自动化交易 Schwab 账户？
    ↓
Python 项目 → schwab-py（官方 REST API 封装）
    ↓
非 Python 项目 → 直接调用 REST API（见 direct-api-calls.md）
    ↓
特别需要 TOS 特有数据格式且用 Node.js → tos-wsjson-client（有风险，实验性）
    ↓
需要 thinkScript / 策略分析器 / 回测 → 只能手动在 TOS 桌面端操作，无 API
```
