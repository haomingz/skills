# Schwab API 常用代码模板

## Contents
- 完整认证初始化
- 行情数据采集
- 期权策略下单
- 账户管理
- 实时流式监控
- 批量请求与限速

---

## 完整认证初始化

```python
import os
from schwab import auth

def get_client():
    return auth.easy_client(
        api_key=os.environ["SCHWAB_APP_KEY"],
        app_secret=os.environ["SCHWAB_APP_SECRET"],
        callback_url="https://127.0.0.1:8182",
        token_path=os.path.expanduser("~/.schwab_token.json"),
    )

def get_account_hash(c):
    resp = c.get_account_numbers()
    resp.raise_for_status()
    return resp.json()[0]["hashValue"]

c = get_client()
account_hash = get_account_hash(c)
```

---

## 行情数据采集

### 下载多只股票日线数据转 DataFrame

```python
import pandas as pd
import time

def get_daily_history(c, symbol: str) -> pd.DataFrame:
    resp = c.get_price_history_every_day(symbol)
    resp.raise_for_status()
    candles = resp.json().get("candles", [])
    if not candles:
        raise ValueError(f"No history returned for {symbol}")
    df = pd.DataFrame(candles)
    df["datetime"] = pd.to_datetime(df["datetime"], unit="ms")
    df.set_index("datetime", inplace=True)
    return df[["open", "high", "low", "close", "volume"]]

# 批量下载（加限速）
symbols = ["AAPL", "MSFT", "GOOG", "TSLA", "SPY"]
data = {}
for sym in symbols:
    data[sym] = get_daily_history(c, sym)
    time.sleep(0.5)  # 防止触发 429
```

### 实时批量报价

```python
def get_batch_quotes(c, symbols: list) -> dict:
    resp = c.get_quotes(symbols)
    resp.raise_for_status()
    quotes = resp.json()
    result = {}
    for sym, q in quotes.items():
        result[sym] = {
            "bid": q.get("bidPrice"),
            "ask": q.get("askPrice"),
            "last": q.get("lastPrice"),
            "volume": q.get("totalVolume"),
            "change_pct": q.get("netPercentChangeInDouble"),
        }
    return result

quotes = get_batch_quotes(c, ["AAPL", "NVDA", "TSLA"])
```

### 期权链解析

```python
import datetime
from schwab.client import Client

def get_option_chain_df(c, symbol: str, expiry: datetime.date = None) -> pd.DataFrame:
    kwargs = dict(
        symbol=symbol,
        contract_type=Client.Options.ContractType.ALL,
        include_underlying_quote=True,
    )
    if expiry:
        kwargs["from_date"] = expiry
        kwargs["to_date"] = expiry

    resp = c.get_option_chain(**kwargs)
    resp.raise_for_status()
    chain = resp.json()

    rows = []
    for contract_type, exp_map in [
        ("CALL", chain.get("callExpDateMap", {})),
        ("PUT", chain.get("putExpDateMap", {})),
    ]:
        for exp_date, strikes in exp_map.items():
            for strike, opts in strikes.items():
                for opt in opts:
                    rows.append({
                        "type": contract_type,
                        "symbol": opt["symbol"],
                        "expiry": exp_date.split(":")[0],
                        "strike": float(strike),
                        "bid": opt.get("bid"),
                        "ask": opt.get("ask"),
                        "last": opt.get("last"),
                        "volume": opt.get("totalVolume"),
                        "open_interest": opt.get("openInterest"),
                        "delta": opt.get("delta"),
                        "gamma": opt.get("gamma"),
                        "theta": opt.get("theta"),
                        "vega": opt.get("vega"),
                        "iv": opt.get("volatility"),
                        "dte": opt.get("daysToExpiration"),
                    })

    df = pd.DataFrame(rows)
    return df

chain_df = get_option_chain_df(c, "AAPL")
# 筛选30天内到期、Delta 在 0.3-0.4 的 Call
filtered = chain_df[
    (chain_df["type"] == "CALL") &
    (chain_df["dte"] <= 30) &
    (chain_df["delta"].between(0.3, 0.4))
]
```

---

## 期权策略下单

### 单腿期权（买入开仓）

```python
from schwab.orders.options import option_buy_to_open_limit, OptionSymbol
from schwab.utils import Utils
import datetime

# 构建期权符号
symbol = OptionSymbol("AAPL", datetime.date(2025, 12, 19), "C", "200").build()

# 限价买入 2 张合约，净权利金 $5.50
order = option_buy_to_open_limit(symbol, quantity=2, price=5.50)

resp = c.place_order(account_hash, order.build())
resp.raise_for_status()

# 提取订单 ID
order_id = Utils(c, account_hash).extract_order_id(resp)
print(f"Order placed: {order_id}")
```

### 牛市价差（Bull Call Spread）

```python
from schwab.orders.options import bull_call_vertical_open, OptionSymbol
import datetime

expiry = datetime.date(2025, 12, 19)
long_call = OptionSymbol("SPY", expiry, "C", "550").build()
short_call = OptionSymbol("SPY", expiry, "C", "560").build()

# 净权利金（debit）= 最多愿意支付的价格
order = bull_call_vertical_open(long_call, short_call, quantity=1, net_debit=5.00)
resp = c.place_order(account_hash, order.build())
resp.raise_for_status()
```

### 铁鹰（Iron Condor）—— 使用 OrderBuilder 手动构建

```python
from schwab.orders.common import (
    OrderBuilder, OrderType, Duration, Session, ComplexOrderStrategyType
)
from schwab import orders

# 铁鹰 = 牛市价差（put side）+ 熊市价差（call side）
# 需要手动构建 OrderBuilder（schwab-py 暂无铁鹰模板）

expiry = datetime.date(2025, 12, 19)

put_long = OptionSymbol("SPY", expiry, "P", "520").build()
put_short = OptionSymbol("SPY", expiry, "P", "530").build()
call_short = OptionSymbol("SPY", expiry, "C", "560").build()
call_long = OptionSymbol("SPY", expiry, "C", "570").build()

iron_condor = (
    orders.common.OrderBuilder()
    .set_order_type(OrderType.NET_CREDIT)
    .set_price(2.00)  # 期望收到的净权利金
    .set_duration(Duration.DAY)
    .set_session(Session.NORMAL)
    .set_complex_order_strategy_type(ComplexOrderStrategyType.IRON_CONDOR)
    .add_option_leg(orders.common.OptionInstruction.SELL_TO_OPEN, put_short, 1)
    .add_option_leg(orders.common.OptionInstruction.BUY_TO_OPEN, put_long, 1)
    .add_option_leg(orders.common.OptionInstruction.SELL_TO_OPEN, call_short, 1)
    .add_option_leg(orders.common.OptionInstruction.BUY_TO_OPEN, call_long, 1)
)
resp = c.place_order(account_hash, iron_condor.build())
resp.raise_for_status()
```

### OCO 止盈止损

```python
from schwab.orders.equities import equity_sell_limit
from schwab.orders.common import one_cancels_other, OrderType, Duration

# 买入后设置 OCO：触及 $200 止盈 或 $170 止损
take_profit = equity_sell_limit("AAPL", 10, 200.0).set_duration(Duration.GOOD_TILL_CANCEL)
stop_loss = (
    orders.common.OrderBuilder()
    .set_order_type(OrderType.STOP)
    .set_stop_price(170.0)
    .set_duration(Duration.GOOD_TILL_CANCEL)
    .add_equity_leg(orders.common.EquityInstruction.SELL, "AAPL", 10)
)

oco = one_cancels_other(take_profit, stop_loss)
resp = c.place_order(account_hash, oco.build())
resp.raise_for_status()
```

---

## 账户管理

### 查询所有持仓

```python
from schwab.client import Client

def get_positions(c, account_hash: str) -> list:
    resp = c.get_account(account_hash, fields=[Client.Account.Fields.POSITIONS])
    resp.raise_for_status()
    acct = resp.json()["securitiesAccount"]
    positions = acct.get("positions", [])
    result = []
    for pos in positions:
        inst = pos["instrument"]
        result.append({
            "symbol": inst.get("symbol"),
            "asset_type": inst.get("assetType"),
            "quantity": pos.get("longQuantity", 0) - pos.get("shortQuantity", 0),
            "avg_price": pos.get("averagePrice"),
            "market_value": pos.get("marketValue"),
            "unrealized_pnl": pos.get("currentDayProfitLoss"),
        })
    return result

positions = get_positions(c, account_hash)
```

### 查询当日未成交订单

```python
import datetime

def get_open_orders(c, account_hash: str) -> list:
    today = datetime.datetime.now()
    start = today.replace(hour=0, minute=0, second=0, microsecond=0)
    resp = c.get_orders_for_account(
        account_hash,
        from_entered_datetime=start,
        to_entered_datetime=today,
        status=Client.Order.Status.WORKING,
    )
    resp.raise_for_status()
    return resp.json()

open_orders = get_open_orders(c, account_hash)
for order in open_orders:
    print(order["orderId"], order["status"], order["orderLegCollection"][0]["instrument"]["symbol"])
```

### 撤销所有未成交订单

```python
def cancel_all_open_orders(c, account_hash: str):
    open_orders = get_open_orders(c, account_hash)
    cancelled = []
    for order in open_orders:
        order_id = order["orderId"]
        resp = c.cancel_order(order_id, account_hash)
        if resp.status_code == 200:
            cancelled.append(order_id)
        time.sleep(0.3)
    return cancelled
```

---

## 实时流式监控

### 多标的 Level 1 行情 + 账户活动监控

```python
from schwab.streaming import StreamClient
from schwab import auth
import asyncio, json, os

async def run_streaming_monitor(c, account_id: int, symbols: list):
    stream = StreamClient(c, account_id=account_id)

    def on_quote(msg):
        for item in msg.get("content", []):
            print(f"[QUOTE] {item['key']} bid={item.get('BID_PRICE')} "
                  f"ask={item.get('ASK_PRICE')} last={item.get('LAST_PRICE')}")

    def on_account_activity(msg):
        for item in msg.get("content", []):
            print(f"[ACCOUNT] {item.get('MESSAGE_TYPE')}: {item.get('MESSAGE_DATA')}")

    def on_chart(msg):
        for item in msg.get("content", []):
            print(f"[CHART] {item['key']} O={item.get('OPEN_PRICE')} "
                  f"H={item.get('HIGH_PRICE')} L={item.get('LOW_PRICE')} "
                  f"C={item.get('CLOSE_PRICE')} V={item.get('VOLUME')}")

    await stream.login()

    # 注册 handler（必须在 subs 之前）
    stream.add_level_one_equity_handler(on_quote)
    stream.add_chart_equity_handler(on_chart)
    stream.add_account_activity_handler(on_account_activity)

    # 订阅
    await stream.level_one_equity_subs(symbols)
    await stream.chart_equity_subs(symbols)
    await stream.account_activity_sub()

    while True:
        await stream.handle_message()

# 使用
asyncio.run(run_streaming_monitor(c, account_id=1234567890, symbols=["AAPL", "TSLA"]))
```

### 期权 Level 1 流式监控

```python
async def monitor_option_quotes(c, account_id: int, option_symbols: list):
    stream = StreamClient(c, account_id=account_id)

    def on_option_quote(msg):
        for item in msg.get("content", []):
            print(
                f"[OPT] {item['key'][:20]:20s} "
                f"bid={item.get('BID_PRICE', 0):6.2f} "
                f"ask={item.get('ASK_PRICE', 0):6.2f} "
                f"Δ={item.get('DELTA', 0):+.3f} "
                f"IV={item.get('VOLATILITY', 0):.1%}"
            )

    await stream.login()
    stream.add_level_one_option_handler(on_option_quote)
    await stream.level_one_option_subs(option_symbols)

    while True:
        await stream.handle_message()
```

### 带重连的健壮流式客户端

```python
async def resilient_stream(c, account_id, symbols, max_retries=None):
    attempt = 0
    while max_retries is None or attempt < max_retries:
        try:
            stream = StreamClient(c, account_id=account_id)
            await stream.login()

            def on_quote(msg):
                for item in msg.get("content", []):
                    print(item)

            stream.add_level_one_equity_handler(on_quote)
            await stream.level_one_equity_subs(symbols)

            attempt = 0  # 成功连接后重置
            while True:
                await stream.handle_message()

        except Exception as e:
            attempt += 1
            wait = min(2 ** attempt, 60)
            print(f"Stream error (attempt {attempt}): {e}. Reconnecting in {wait}s...")
            await asyncio.sleep(wait)
```

---

## 批量请求与限速

### 带 429 自动重试的请求封装

```python
import time
import httpx

def safe_get(func, *args, retries=3, base_wait=1.0, **kwargs):
    for attempt in range(retries):
        resp = func(*args, **kwargs)
        if resp.status_code == 429:
            wait = base_wait * (2 ** attempt)
            print(f"Rate limited. Waiting {wait:.1f}s (attempt {attempt+1}/{retries})")
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return resp
    raise RuntimeError("Max retries exceeded after rate limiting")

# 使用
resp = safe_get(c.get_quote, "AAPL")
data = resp.json()
```

### 批量历史行情下载（含进度和错误处理）

```python
import time
from pathlib import Path
import json

def download_histories(c, symbols: list, output_dir: str = "./data"):
    Path(output_dir).mkdir(exist_ok=True)
    results = {}
    errors = {}

    for i, sym in enumerate(symbols):
        try:
            resp = safe_get(c.get_price_history_every_day, sym)
            data = resp.json()
            candles = data.get("candles", [])

            output_file = Path(output_dir) / f"{sym}.json"
            with open(output_file, "w") as f:
                json.dump(candles, f)

            results[sym] = len(candles)
            print(f"[{i+1}/{len(symbols)}] {sym}: {len(candles)} candles")

        except Exception as e:
            errors[sym] = str(e)
            print(f"[{i+1}/{len(symbols)}] {sym}: ERROR - {e}")

        time.sleep(0.5)  # 保守限速

    print(f"\nDone: {len(results)} success, {len(errors)} errors")
    if errors:
        print("Errors:", errors)
    return results, errors

results, errors = download_histories(c, ["AAPL", "MSFT", "GOOG"])
```
