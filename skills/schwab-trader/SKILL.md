---
name: schwab-trader
description: 此技能用于通过 Charles Schwab Trader API 进行美股交易操作，包括 OAuth 认证、行情数据获取、下单交易（股票/期权）、账户查询和实时流式数据订阅。支持 schwab-py 封装库或直接调用官方 REST API。适用于用户提到 Schwab API、schwab-py、Charles Schwab 自动化交易、美股 API 下单、期权链查询、实时行情流式订阅、get_price_history、place_order、thinkorswim API 的场景。
---

# Schwab Trader API 调用

Schwab 提供标准 REST API（`api.schwabapi.com`），**无官方 Python SDK**。

| 调用方式 | 优点 | 适用场景 |
|---------|------|---------|
| `schwab-py`（非官方库） | 自动处理 OAuth 与 token 刷新，代码简洁 | Python 项目首选 |
| 直接 `requests` | 无依赖，逻辑完全透明，可移植任意语言 | 学习原理、非 Python 环境、轻量脚本 |

两种方式调用完全相同的官方端点，区别仅在于 OAuth 处理。认证流程和直接调用示例见 `references/auth-and-tokens.md`。

**不适用于**：thinkorswim 专有功能（thinkScript、策略分析器、内置回测无 API）、期货/外汇下单（暂未开放）、历史期权定价、沙盒测试（Schwab 无沙盒环境）。

**关于 ThinkOrSwim API**：TOS 有未文档化的内部 WebSocket 协议（wsjson），被社区逆向工程，仅有 Node.js 实现。用 Schwab REST API 可操作与 TOS 完全相同的账户持仓，大多数自动化场景 REST API 已足够。

## 安装与注册

```bash
pip install schwab-py
```

注册：在 developer.schwab.com 申请 App，选 **Accounts and Trading Production**，callback URL 设为 `https://127.0.0.1:8182`，等待审批（1-5 工作日）得到 App Key 和 App Secret。详见 `references/auth-and-tokens.md`。

## 工作流

**复制此 checklist 追踪进度：**

```
Schwab API 进度:
- [ ] 步骤 1: 初始化认证客户端
- [ ] 步骤 2: 获取账户哈希
- [ ] 步骤 3: 选择任务类型（行情 / 交易 / 流式）
- [ ] 步骤 4: 调用 API，检查响应
- [ ] 步骤 5: 处理数据
- [ ] 步骤 6: 运行质量检查
```

**步骤 1: 初始化认证客户端**

```python
from schwab import auth

c = auth.easy_client(
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET",
    callback_url="https://127.0.0.1:8182",
    token_path="/path/to/token.json",
)
# 首次运行打开浏览器完成 OAuth；后续自动读取 token.json 并刷新
```

**步骤 2: 获取账户哈希**

API 不接受裸账号，必须先获取哈希：

```python
resp = c.get_account_numbers()
resp.raise_for_status()
account_hash = resp.json()[0]["hashValue"]
```

**步骤 3: 选择任务类型**

| 需求 | 方法 |
|------|------|
| 日线 / 分钟历史行情 | `c.get_price_history_every_day()` / `c.get_price_history_every_minute()` |
| 实时快照报价 | `c.get_quotes(["AAPL", "MSFT"])` |
| 期权链（含 Greeks） | `c.get_option_chain(symbol)` |
| 账户余额 / 持仓 | `c.get_account(account_hash, fields=[...])` |
| 下单 | `c.place_order(account_hash, order_spec)` |
| 实时流式行情 | `StreamClient` + WebSocket（步骤 4c） |
| 市场交易时间 | `c.get_market_hours(markets)` |

**步骤 4a: 行情数据**

```python
# 日线历史（~20年）
resp = c.get_price_history_every_day("AAPL")
resp.raise_for_status()
candles = resp.json()["candles"]  # [{open, high, low, close, volume, datetime(ms)}, ...]

# 批量实时报价
resp = c.get_quotes(["AAPL", "MSFT", "SPY"])
resp.raise_for_status()
quotes = resp.json()  # 键=标的代码，值含 bidPrice/askPrice/lastPrice/totalVolume

# 期权链
resp = c.get_option_chain("AAPL")
resp.raise_for_status()
chain = resp.json()  # chain["callExpDateMap"]["2025-12-19:30"]["200.0"][0] 含 Greeks
```

完整参数和期权链解析见 `references/api-reference.md`。

**步骤 4b: 下单交易**

```python
from schwab.orders.equities import equity_buy_market, equity_buy_limit
from schwab.orders.options import option_buy_to_open_limit, bull_call_vertical_open, OptionSymbol
from schwab.orders.common import Duration, one_cancels_other
import datetime

# 市价买入股票
c.place_order(account_hash, equity_buy_market("AAPL", 1).build()).raise_for_status()

# 限价买入 GTC
c.place_order(
    account_hash,
    equity_buy_limit("GOOG", 10, 175.0).set_duration(Duration.GOOD_TILL_CANCEL).build()
).raise_for_status()

# 期权买入开仓（必须先从 get_option_chain() 取真实符号，或用 OptionSymbol 构建）
sym = OptionSymbol("AAPL", datetime.date(2025, 12, 19), "C", "200").build()
c.place_order(account_hash, option_buy_to_open_limit(sym, 1, 5.50).build()).raise_for_status()

# 牛市价差
long_c = OptionSymbol("SPY", datetime.date(2025, 12, 19), "C", "550").build()
short_c = OptionSymbol("SPY", datetime.date(2025, 12, 19), "C", "560").build()
c.place_order(account_hash, bull_call_vertical_open(long_c, short_c, 1, 5.0).build()).raise_for_status()
```

完整订单类型、OCO、触发订单见 `references/common-recipes.md`。

**步骤 4c: 实时流式数据（WebSocket）**

```python
from schwab.streaming import StreamClient
import asyncio, json

stream_client = StreamClient(c, account_id=YOUR_ACCOUNT_ID)

async def stream_quotes():
    await stream_client.login()
    # 必须先注册 handler，再订阅
    stream_client.add_level_one_equity_handler(
        lambda msg: print(json.dumps(msg, indent=2))
    )
    await stream_client.level_one_equity_subs(["AAPL", "TSLA"])
    while True:
        await stream_client.handle_message()

asyncio.run(stream_quotes())
```

可用流式服务：Level1（股票/期权/期货/外汇）、Level2 委托簿（NYSE/NASDAQ）、分钟 OHLCV、Screener 涨跌榜、账户活动。完整列表和字段见 `references/api-reference.md`。

**步骤 5: 账户数据处理**

```python
from schwab.client import Client
from schwab.utils import Utils

# 持仓
resp = c.get_account(account_hash, fields=[Client.Account.Fields.POSITIONS])
resp.raise_for_status()
positions = resp.json()["securitiesAccount"].get("positions", [])

# 提取下单后的订单 ID
order_id = Utils(c, account_hash).extract_order_id(resp)

# 取消订单
c.cancel_order(order_id, account_hash).raise_for_status()
```

**步骤 6: 质量检查**

遇到错误时排查顺序：

1. **401** → access token 过期（schwab-py 自动处理）；若仍报 401 检查系统时钟
2. **401 + 重新登录仍失败** → refresh token 超 7 天过期，需重新走完整 OAuth 登录
3. **403** → App 未审批或期权权限未开通
4. **429** → 超 120 次/分钟，加 `time.sleep(0.5)` 或指数退避
5. **下单被拒** → 检查账户余额、期权交易权限级别、市场是否开盘

## Token 生命周期

| Token | 有效期 | 处理 |
|-------|--------|------|
| Access Token | 30 分钟 | schwab-py 自动刷新 |
| Refresh Token | **7 天** | **必须手动刷新**，建议每 6 天触发一次 |

## 常见陷阱

- 期权符号格式严格（OCC 标准），推荐从 `get_option_chain()` 直接取，不要手拼
- 流式客户端必须先 `add_xxx_handler()`，再调用 `xxx_subs()`，顺序颠倒会丢消息
- 每个 token 文件只能对应一个 Client 实例，多实例会导致 OAuth 状态冲突
- 历史 K 线不支持期权和期货（只有行情流）
- 期货和外汇目前只有流式行情，REST 下单暂不支持

## 质量检查

- [ ] `easy_client` 创建成功，`token.json` 存在且可写
- [ ] 已调用 `get_account_numbers()` 获取 `hashValue`，未直接使用裸账号
- [ ] 所有 REST 响应调用 `resp.raise_for_status()`
- [ ] 下单前确认账户余额和期权权限
- [ ] 期权符号来自 `OptionSymbol` 或 `get_option_chain()`，未手动拼接
- [ ] 流式 handler 在 `subs` 调用之前注册
- [ ] 批量请求加入 `time.sleep(0.5)` 或限速重试逻辑
- [ ] Refresh token 有 7 天内刷新机制

## 参考资料（按需加载）

- `references/auth-and-tokens.md` - OAuth 完整流程（schwab-py 和直接 requests 两种）、token 刷新策略、故障排查
- `references/api-reference.md` - 所有端点、行情参数、订单类型枚举、期权符号格式、流式服务列表
- `references/common-recipes.md` - 完整代码：行情采集、期权策略下单、账户查询、流式监控、批量限速
