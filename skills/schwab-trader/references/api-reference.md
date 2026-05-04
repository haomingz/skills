# Schwab API 端点参考

## Contents
- REST 端点总览
- 行情数据参数
- 订单类型与模板
- 期权符号格式
- 流式服务列表
- 速率限制

---

## REST 端点总览

基础 URL：
- 市场数据：`https://api.schwabapi.com/marketdata/v1/`
- 交易账户：`https://api.schwabapi.com/trader/v1/`

| 功能 | schwab-py 方法 | 直接调用路径 |
|------|---------------|------------|
| 获取账户哈希 | `get_account_numbers()` | GET `/accounts/accountNumbers` |
| 账户详情 | `get_account(hash, fields=[...])` | GET `/accounts/{hash}?fields=positions` |
| 所有账户 | `get_accounts()` | GET `/accounts` |
| 下单 | `place_order(hash, spec)` | POST `/accounts/{hash}/orders` |
| 查订单 | `get_orders_for_account(hash, ...)` | GET `/accounts/{hash}/orders` |
| 取消订单 | `cancel_order(order_id, hash)` | DELETE `/accounts/{hash}/orders/{id}` |
| 预览订单 | `preview_order(hash, spec)` | POST `/accounts/{hash}/previewOrder` |
| 历史交易 | `get_transactions(hash)` | GET `/accounts/{hash}/transactions` |
| 实时报价（单） | `get_quote(symbol)` | GET `/quotes/{symbol}` |
| 实时报价（批量） | `get_quotes(symbols)` | GET `/quotes?symbols=A,B,C` |
| 历史 K 线 | `get_price_history(symbol, ...)` | GET `/pricehistory` |
| 期权链 | `get_option_chain(symbol, ...)` | GET `/chains` |
| 期权到期日 | `get_option_expiration_chain(symbol)` | GET `/expirationchain` |
| 市场时间 | `get_market_hours(markets)` | GET `/markets` |
| 标的搜索 | `search_instruments(symbols)` | GET `/instruments` |
| 涨跌榜 | `get_movers(index)` | GET `/movers/{index}` |

---

## 行情数据参数

### 历史 K 线（`get_price_history`）

```python
from schwab.client import Client
import datetime

resp = c.get_price_history(
    "AAPL",
    period_type=Client.PriceHistory.PeriodType.YEAR,     # DAY/MONTH/YEAR/YTD
    period=Client.PriceHistory.Period.ONE_YEAR,           # 对应 period_type 的枚举
    frequency_type=Client.PriceHistory.FrequencyType.DAILY,  # MINUTE/DAILY/WEEKLY/MONTHLY
    frequency=Client.PriceHistory.Frequency.EVERY_DAY,
    start_datetime=datetime.datetime(2024, 1, 1),
    end_datetime=datetime.datetime(2024, 12, 31),
    need_extended_hours_data=False,
    need_previous_close=True,
)
# resp.json()["candles"]: [{datetime(ms), open, high, low, close, volume}, ...]
```

快捷方法（推荐日常使用）：
- `get_price_history_every_day(symbol)` → 日线，约 20 年历史
- `get_price_history_every_minute(symbol)` → 分钟线，最近 10 交易日

限制：不支持期权/期货历史 K 线。

### 期权链参数

```python
from schwab.client import Client
import datetime

resp = c.get_option_chain(
    "AAPL",
    contract_type=Client.Options.ContractType.ALL,  # CALL/PUT/ALL
    strike_count=10,                                 # 价内外各N个行权价
    include_underlying_quote=True,
    strategy=Client.Options.Strategy.SINGLE,         # SINGLE/ANALYTICAL/COVERED/VERTICAL...
    from_date=datetime.date(2025, 6, 1),
    to_date=datetime.date(2025, 12, 31),
)
# resp.json()["callExpDateMap"]["2025-12-19:30"]["200.0"][0] 包含 Greeks
```

期权链返回字段包含：`symbol`, `bid`, `ask`, `last`, `delta`, `gamma`, `theta`, `vega`, `rho`, `volatility`, `openInterest`, `daysToExpiration`, `totalVolume`。

---

## 订单类型与模板

### 股票模板（`schwab.orders.equities`）

```python
from schwab.orders.equities import (
    equity_buy_market,        # 市价买入
    equity_buy_limit,         # 限价买入
    equity_sell_market,       # 市价卖出
    equity_sell_limit,        # 限价卖出
    equity_sell_short_market, # 市价卖空
    equity_sell_short_limit,  # 限价卖空
    equity_buy_to_cover_market, equity_buy_to_cover_limit,  # 回补
)
```

### 期权模板（`schwab.orders.options`）

```python
from schwab.orders.options import (
    option_buy_to_open_limit,    # 买入开仓（限价）
    option_buy_to_open_market,   # 买入开仓（市价）
    option_sell_to_open_limit,   # 卖出开仓（限价）
    option_sell_to_close_limit,  # 卖出平仓（限价）
    option_buy_to_close_limit,   # 买入平仓（限价）
    # 垂直价差
    bull_call_vertical_open, bull_call_vertical_close,
    bear_call_vertical_open, bear_call_vertical_close,
    bull_put_vertical_open, bull_put_vertical_close,
    bear_put_vertical_open, bear_put_vertical_close,
)
```

### 修饰符枚举（`schwab.orders.common`）

```python
from schwab.orders.common import (
    OrderType,   # MARKET/LIMIT/STOP/STOP_LIMIT/TRAILING_STOP/MARKET_ON_CLOSE
    Session,     # NORMAL/AM（盘前）/PM（盘后）/SEAMLESS（全天）
    Duration,    # DAY/GOOD_TILL_CANCEL/FILL_OR_KILL
    one_cancels_other,      # OCO 组合
    first_triggers_second,  # 触发后下单
)
```

### 下单 JSON 结构（直接调用时）

```python
# 市价股票买入
{
    "orderType": "MARKET",
    "session": "NORMAL",
    "duration": "DAY",
    "orderStrategyType": "SINGLE",
    "orderLegCollection": [{
        "instruction": "BUY",           # BUY/SELL/SELL_SHORT/BUY_TO_COVER
        "quantity": 1,
        "instrument": {"symbol": "AAPL", "assetType": "EQUITY"}
    }]
}

# 限价期权买入开仓
{
    "orderType": "LIMIT",
    "price": 5.50,
    "session": "NORMAL",
    "duration": "DAY",
    "orderStrategyType": "SINGLE",
    "orderLegCollection": [{
        "instruction": "BUY_TO_OPEN",   # BUY_TO_OPEN/SELL_TO_OPEN/BUY_TO_CLOSE/SELL_TO_CLOSE
        "quantity": 1,
        "instrument": {
            "symbol": "AAPL  251219C00200000",
            "assetType": "OPTION"
        }
    }]
}
```

---

## 期权符号格式

OCC 标准格式：`[UNDERLYING 6位左对齐][YYMMDD][P/C][8位价格编码]`

```
AAPL  251219C00200000  →  AAPL 2025-12-19 200 Call
SPXW  241220C05040000  →  SPXW 2024-12-20 5040 Call（行权价>1000前补1个0）
SPY   241220P00500000  →  SPY 2024-12-20 500 Put
```

价格编码规则：行权价 × 1000，共8位，不足前补0（行权价<1000补2个0，≥1000补1个0）。

```python
from schwab.orders.options import OptionSymbol
import datetime

# 自动生成
sym = OptionSymbol("AAPL", datetime.date(2025, 12, 19), "C", "200").build()

# 推荐：从期权链直接取真实符号（避免格式错误）
chain = c.get_option_chain("AAPL").json()
real_sym = chain["callExpDateMap"]["2025-12-19:30"]["200.0"][0]["symbol"]
```

---

## 流式服务列表

已确认可用（`StreamClient`）：

| 服务 | 订阅方法 | 取消方法 | 增加标的 |
|------|---------|---------|---------|
| 股票分钟 OHLCV | `chart_equity_subs(symbols)` | `chart_equity_unsubs` | `chart_equity_add` |
| 期货分钟 OHLCV | `chart_futures_subs(symbols)` | `chart_futures_unsubs` | `chart_futures_add` |
| Level1 股票报价 | `level_one_equity_subs(symbols)` | `level_one_equity_unsubs` | `level_one_equity_add` |
| Level1 期权报价 | `level_one_option_subs(symbols)` | — | `level_one_option_add` |
| Level1 期货报价 | `level_one_futures_subs(symbols)` | — | `level_one_futures_add` |
| Level1 外汇报价 | `level_one_forex_subs(symbols)` | — | `level_one_forex_add` |
| Level2 NYSE 委托簿 | `nyse_book_subs(symbols)` | `nyse_book_unsubs` | `nyse_book_add` |
| Level2 NASDAQ 委托簿 | `nasdaq_book_subs(symbols)` | `nasdaq_book_unsubs` | `nasdaq_book_add` |
| Level2 期权委托簿 | `options_book_subs(symbols)` | `options_book_unsubs` | `options_book_add` |
| 涨跌榜 | `screener_equity_subs(symbols)` | — | `screener_equity_add` |
| 账户活动 | `account_activity_sub()` | `account_activity_unsubs` | — |

**Screener 符号格式**：`{PREFIX}_{SORTFIELD}_{FREQUENCY}`
- PREFIX: `NYSE/NASDAQ/EQUITY_ALL/$DJI/$SPX.X/OPTION_ALL` 等
- SORTFIELD: `VOLUME/TRADES/PERCENT_CHANGE_UP/PERCENT_CHANGE_DOWN`
- FREQUENCY: `0`（全天）/ `1/5/10/30/60`（分钟）

Level1 股票主要字段：`BID_PRICE`, `ASK_PRICE`, `LAST_PRICE`, `TOTAL_VOLUME`, `HIGH_PRICE`, `LOW_PRICE`, `NET_CHANGE`, `NET_CHANGE_PERCENT`, `MARK`, `DELTA`（期权），`OPEN_INTEREST`（期权）

---

## 速率限制

| 类型 | 限制 | 超限响应 |
|------|------|---------|
| 全局 API | 120 次/分钟（应用级） | HTTP 429 |
| 下单 | 0-120 次/分钟（注册时配置） | HTTP 429 |

```python
import time

def request_with_retry(func, *args, retries=3, **kwargs):
    for i in range(retries):
        resp = func(*args, **kwargs)
        if resp.status_code == 429:
            time.sleep(2 ** i)
            continue
        resp.raise_for_status()
        return resp
    raise RuntimeError("Max retries exceeded")
```
