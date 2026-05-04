# Schwab API 参考手册

## Contents
- REST API 端点概览
- 行情数据 API
- 账户与交易 API
- 订单类型参考
- 期权符号格式
- 流式数据服务
- 速率限制

---

## REST API 端点概览

所有 REST 请求基础 URL：`https://api.schwabmeritrade.com/trader/v1`

schwab-py 封装后对应方法：

| 功能分类 | schwab-py 方法 | HTTP 端点 |
|---------|---------------|-----------|
| 账户列表（哈希） | `get_account_numbers()` | GET /accounts/accountNumbers |
| 账户详情 | `get_account(hash)` | GET /accounts/{accountHash} |
| 所有账户 | `get_accounts()` | GET /accounts |
| 下单 | `place_order(hash, spec)` | POST /accounts/{accountHash}/orders |
| 查询订单 | `get_orders_for_account(hash)` | GET /accounts/{accountHash}/orders |
| 查询单个订单 | `get_order(order_id, hash)` | GET /accounts/{accountHash}/orders/{orderId} |
| 取消订单 | `cancel_order(order_id, hash)` | DELETE /accounts/{accountHash}/orders/{orderId} |
| 预览订单 | `preview_order(hash, spec)` | POST /accounts/{accountHash}/previewOrder |
| 历史交易 | `get_transactions(hash)` | GET /accounts/{accountHash}/transactions |
| 实时报价 | `get_quote(symbol)` | GET /quotes/{symbol} |
| 批量报价 | `get_quotes(symbols)` | GET /quotes |
| 期权链 | `get_option_chain(symbol)` | GET /chains |
| 期权到期日 | `get_option_expiration_chain(symbol)` | GET /expirationchain |
| 历史行情 | `get_price_history(symbol, ...)` | GET /pricehistory |
| 标的搜索 | `search_instruments(symbols)` | GET /instruments |
| 标的详情 | `get_instrument_by_cusip(cusip)` | GET /instruments/{cusip} |
| 市场时间 | `get_market_hours(markets)` | GET /markets |
| 市场列表 | `get_market_hours_for_single_market(market)` | GET /markets/{market} |
| 行情移动榜 | `get_movers(index, ...)` | GET /movers/{symbolId} |

---

## 行情数据 API

### 历史 K 线

```python
# 日线（自动取最大历史深度，约20年）
resp = c.get_price_history_every_day("AAPL")

# 分钟线（最近10天）
resp = c.get_price_history_every_minute("TSLA")

# 自定义参数
from schwab.client import Client
import datetime

resp = c.get_price_history(
    "SPY",
    period_type=Client.PriceHistory.PeriodType.YEAR,
    period=Client.PriceHistory.Period.ONE_YEAR,
    frequency_type=Client.PriceHistory.FrequencyType.DAILY,
    frequency=Client.PriceHistory.Frequency.EVERY_DAY,
    start_datetime=datetime.datetime(2024, 1, 1),
    end_datetime=datetime.datetime(2024, 12, 31),
    need_extended_hours_data=False,
    need_previous_close=True
)

data = resp.json()
# data["candles"] 列表，每条含：
#   datetime (毫秒时间戳), open, high, low, close, volume
```

**PeriodType 选项**：DAY, MONTH, YEAR, YTD

**FrequencyType 选项**：MINUTE, DAILY, WEEKLY, MONTHLY

历史行情限制：
- 分钟线：最近 10 交易日
- 日线/周线：最多 20 年历史
- **不支持期权、期货、外汇历史 K 线**

### 实时报价

```python
# 单标的
resp = c.get_quote("AAPL")
data = resp.json()["AAPL"]
# 包含：bidPrice, askPrice, lastPrice, totalVolume, highPrice, lowPrice 等

# 多标的（批量，效率更高）
resp = c.get_quotes(["AAPL", "MSFT", "TSLA", "SPY"])
quotes = resp.json()
# 键为股票代码，值为报价对象
```

### 期权链

```python
from schwab.client import Client
import datetime

resp = c.get_option_chain(
    "AAPL",
    contract_type=Client.Options.ContractType.CALL,  # CALL / PUT / ALL
    strike_count=10,               # 价内外各5个行权价
    include_underlying_quote=True,
    strategy=Client.Options.Strategy.SINGLE,
    from_date=datetime.date(2025, 6, 1),
    to_date=datetime.date(2025, 12, 31),
)
chain = resp.json()

# 遍历 Call 链
for exp_date, strikes in chain["callExpDateMap"].items():
    for strike, options in strikes.items():
        for opt in options:
            print(opt["symbol"], opt["bid"], opt["ask"], opt["delta"], opt["openInterest"])
```

---

## 账户与交易 API

### 账户查询

```python
from schwab.client import Client

# 账户余额（不含持仓）
resp = c.get_account(account_hash)
acct = resp.json()["securitiesAccount"]
print(acct["currentBalances"]["liquidationValue"])

# 账户余额 + 持仓
resp = c.get_account(
    account_hash,
    fields=[Client.Account.Fields.POSITIONS]
)
positions = resp.json()["securitiesAccount"]["positions"]

# 账户余额 + 持仓 + 委托
resp = c.get_account(
    account_hash,
    fields=[Client.Account.Fields.POSITIONS, Client.Account.Fields.ORDERS]
)
```

### 查询订单

```python
import datetime

# 当日所有订单
resp = c.get_orders_for_account(
    account_hash,
    from_entered_datetime=datetime.datetime.now().replace(hour=0, minute=0),
    to_entered_datetime=datetime.datetime.now(),
)
orders = resp.json()

# 按状态筛选
resp = c.get_orders_for_account(
    account_hash,
    status=Client.Order.Status.FILLED,
    from_entered_datetime=datetime.datetime(2025, 1, 1),
    to_entered_datetime=datetime.datetime(2025, 12, 31),
    max_results=50,
)
```

### 取消订单

```python
resp = c.cancel_order(order_id, account_hash)
resp.raise_for_status()
# 204 No Content = 取消成功
```

---

## 订单类型参考

### 股票订单模板

```python
from schwab.orders.equities import (
    equity_buy_market,       # 市价买入
    equity_buy_limit,        # 限价买入
    equity_sell_market,      # 市价卖出
    equity_sell_limit,       # 限价卖出
    equity_sell_short_market,  # 市价卖空
    equity_sell_short_limit,   # 限价卖空
    equity_buy_to_cover_market,  # 市价回补
    equity_buy_to_cover_limit,   # 限价回补
)
```

### 期权订单模板

```python
from schwab.orders.options import (
    option_buy_to_open_market,   # 买入开仓（市价）
    option_buy_to_open_limit,    # 买入开仓（限价）
    option_sell_to_open_market,  # 卖出开仓（市价）
    option_sell_to_open_limit,   # 卖出开仓（限价）
    option_buy_to_close_market,  # 买入平仓（市价）
    option_buy_to_close_limit,   # 买入平仓（限价）
    option_sell_to_close_market, # 卖出平仓（市价）
    option_sell_to_close_limit,  # 卖出平仓（限价）

    # 价差策略（Vertical Spreads）
    bull_call_vertical_open,   # 牛市看涨价差-开仓
    bull_call_vertical_close,  # 牛市看涨价差-平仓
    bear_call_vertical_open,   # 熊市看涨价差-开仓
    bear_call_vertical_close,  # 熊市看涨价差-平仓
    bull_put_vertical_open,    # 牛市看跌价差-开仓
    bull_put_vertical_close,   # 牛市看跌价差-平仓
    bear_put_vertical_open,    # 熊市看跌价差-开仓
    bear_put_vertical_close,   # 熊市看跌价差-平仓
)
```

### OrderBuilder 订单类型枚举

```python
from schwab.orders.common import (
    OrderType,    # MARKET, LIMIT, STOP, STOP_LIMIT, MARKET_ON_CLOSE, TRAILING_STOP, TRAILING_STOP_LIMIT
    Session,      # NORMAL, AM (盘前), PM (盘后), SEAMLESS (全天连续)
    Duration,     # DAY, GOOD_TILL_CANCEL, FILL_OR_KILL
    Destination,  # INET, ECN_ARCA, CBOE, AMEX, PHLX, ISE, BOX, NYSE, NASDAQ, BATS, C2, AUTO
)
```

### 组合订单策略

```python
from schwab.orders.common import one_cancels_other, first_triggers_second

# OCO：一个成交取消另一个
oco_order = one_cancels_other(
    equity_sell_limit("AAPL", 10, 200.0),  # 限价止盈
    equity_sell_market("AAPL", 10)          # 市价止损（实际需用 STOP）
)
c.place_order(account_hash, oco_order.build())

# 触发后下单（例：买入成交后自动挂止损）
trigger_order = first_triggers_second(
    equity_buy_limit("AAPL", 10, 180.0),
    equity_sell_limit("AAPL", 10, 200.0)
        .set_duration(Duration.GOOD_TILL_CANCEL)
)
c.place_order(account_hash, trigger_order.build())
```

---

## 期权符号格式

Schwab 期权符号格式：`[UNDERLYING 6位左对齐][YYMMDD][P/C][价格编码]`

```
QQQ   240420P00500000  → QQQ 2024-04-20 500 Put
SPXW  240420C05040000  → SPX Weekly 2024-04-20 5040 Call（行权价>1000前补1个0）
AAPL  251219C00200000  → AAPL 2025-12-19 200 Call
```

**价格编码规则**：
- 行权价 < 1000：乘以1000，前面补两个0，共8位
- 行权价 ≥ 1000：乘以1000，前面补一个0，共8位

使用 `OptionSymbol` 自动生成：

```python
from schwab.orders.options import OptionSymbol
import datetime

sym = OptionSymbol(
    underlying_symbol="AAPL",
    expiration_date=datetime.date(2025, 12, 19),
    contract_type="C",          # "C" / "CALL" / "P" / "PUT"
    strike_price_as_string="200"
).build()
# 输出：'AAPL  251219C00200000'
```

**获取真实交易期权符号**（推荐）：

```python
chain = c.get_option_chain("AAPL").json()
# 从 callExpDateMap / putExpDateMap 中提取真实符号
for exp, strikes in chain["callExpDateMap"].items():
    for strike, opts in strikes.items():
        real_symbol = opts[0]["symbol"]  # 使用这个，不要自己拼
```

---

## 流式数据服务

### 已确认可用的流式服务

| 服务 | 订阅方法 | 数据内容 |
|------|---------|---------|
| 股票分钟 OHLCV | `chart_equity_subs(symbols)` | 分钟级 K 线 |
| 期货分钟 OHLCV | `chart_futures_subs(symbols)` | 期货分钟 K 线 |
| Level 1 股票报价 | `level_one_equity_subs(symbols)` | Bid/Ask/Last/Volume/Greeks 等51个字段 |
| Level 1 期权报价 | `level_one_option_subs(symbols)` | Delta/Gamma/Theta/Vega 等56个字段 |
| Level 1 期货报价 | `level_one_futures_subs(symbols)` | 期货 Bid/Ask/OI 等41个字段 |
| Level 1 外汇报价 | `level_one_forex_subs(symbols)` | 外汇 Bid/Ask 等30个字段 |
| Level 2 NYSE 委托簿 | `nyse_book_subs(symbols)` | 股票委托簿快照 |
| Level 2 NASDAQ 委托簿 | `nasdaq_book_subs(symbols)` | 股票委托簿快照 |
| Level 2 期权委托簿 | `options_book_subs(symbols)` | 期权委托簿快照 |
| 涨跌榜 | `screener_equity_subs(symbols)` | Volume/涨跌幅排名 |
| 账户活动 | `account_activity_sub()` | 下单/成交/状态变化事件 |

### 流式数据格式（Level 1 股票示例）

```json
{
  "service": "LEVELONE_EQUITIES",
  "timestamp": 1715908546054,
  "command": "SUBS",
  "content": [{
    "key": "AAPL",
    "BID_PRICE": 189.50,
    "ASK_PRICE": 189.52,
    "LAST_PRICE": 189.51,
    "TOTAL_VOLUME": 12345678,
    "HIGH_PRICE": 190.00,
    "LOW_PRICE": 188.00,
    "NET_CHANGE": 1.23,
    "NET_CHANGE_PERCENT": 0.65,
    "MARK": 189.51
  }]
}
```

### Screener 符号格式

```
{PREFIX}_{SORTFIELD}_{FREQUENCY}

前缀（PREFIX）:
  指数: $COMPX, $DJI, $SPX.X, INDEX_ALL
  交易所: NYSE, NASDAQ, OTCBB, EQUITY_ALL
  期权: OPTION_PUT, OPTION_CALL, OPTION_ALL

排序（SORTFIELD）:
  VOLUME, TRADES, PERCENT_CHANGE_UP, PERCENT_CHANGE_DOWN, AVERAGE_PERCENT_VOLUME

频率（FREQUENCY）:
  0（全天）, 1, 5, 10, 30, 60（分钟）

示例: "NYSE_PERCENT_CHANGE_UP_5"  → NYSE 5分钟内涨幅最大的10个标的
```

---

## 速率限制

| 限制类型 | 限制值 | 超限响应 |
|---------|--------|---------|
| 全局 API 请求 | 120 次/分钟（应用级） | HTTP 429 |
| 下单请求 | 0-120 次/分钟（注册时设定） | HTTP 429 |
| 历史行情并发 | 建议 < 2 次/秒 | 可能返回 503 |

超限重试模式：

```python
import time

def request_with_retry(func, *args, retries=3, **kwargs):
    for attempt in range(retries):
        resp = func(*args, **kwargs)
        if resp.status_code == 429:
            wait = 2 ** attempt
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return resp
    raise RuntimeError("Max retries exceeded")
```
