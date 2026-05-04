# Schwab API 常用代码模板

## Contents
- 初始化与账户哈希
- 行情采集（日线/报价/期权链）
- 股票下单
- 期权策略下单（单腿/价差/OCO）
- 账户查询（余额/持仓/订单）
- 实时流式监控
- 批量请求与限速

---

## 初始化与账户哈希

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

## 行情采集

### 多标的日线转 DataFrame

```python
import pandas as pd
import time

def get_daily_history(c, symbol: str) -> pd.DataFrame:
    resp = c.get_price_history_every_day(symbol)
    resp.raise_for_status()
    candles = resp.json().get("candles", [])
    if not candles:
        raise ValueError(f"No history for {symbol}")
    df = pd.DataFrame(candles)
    df["datetime"] = pd.to_datetime(df["datetime"], unit="ms")
    return df.set_index("datetime")[["open", "high", "low", "close", "volume"]]

# 批量下载（限速）
data = {}
for sym in ["AAPL", "MSFT", "SPY"]:
    data[sym] = get_daily_history(c, sym)
    time.sleep(0.5)
```

### 批量实时报价

```python
def get_batch_quotes(c, symbols: list) -> dict:
    resp = c.get_quotes(symbols)
    resp.raise_for_status()
    return {
        sym: {
            "bid": q.get("bidPrice"),
            "ask": q.get("askPrice"),
            "last": q.get("lastPrice"),
            "volume": q.get("totalVolume"),
            "change_pct": q.get("netPercentChangeInDouble"),
        }
        for sym, q in resp.json().items()
    }
```

### 期权链解析为 DataFrame

```python
import datetime
from schwab.client import Client

def get_option_chain_df(c, symbol: str) -> pd.DataFrame:
    resp = c.get_option_chain(
        symbol,
        contract_type=Client.Options.ContractType.ALL,
        include_underlying_quote=True,
    )
    resp.raise_for_status()
    chain = resp.json()
    rows = []
    for ctype, exp_map in [("CALL", chain.get("callExpDateMap", {})),
                            ("PUT",  chain.get("putExpDateMap", {}))]:
        for exp_date, strikes in exp_map.items():
            for strike, opts in strikes.items():
                for opt in opts:
                    rows.append({
                        "type": ctype,
                        "symbol": opt["symbol"],
                        "expiry": exp_date.split(":")[0],
                        "strike": float(strike),
                        "bid": opt.get("bid"), "ask": opt.get("ask"),
                        "volume": opt.get("totalVolume"),
                        "oi": opt.get("openInterest"),
                        "delta": opt.get("delta"), "gamma": opt.get("gamma"),
                        "theta": opt.get("theta"), "vega": opt.get("vega"),
                        "iv": opt.get("volatility"),
                        "dte": opt.get("daysToExpiration"),
                    })
    return pd.DataFrame(rows)
```

---

## 股票下单

```python
from schwab.orders.equities import equity_buy_market, equity_buy_limit, equity_sell_limit
from schwab.orders.common import Duration, Session
from schwab.utils import Utils

# 市价买入
resp = c.place_order(account_hash, equity_buy_market("AAPL", 1).build())
resp.raise_for_status()
order_id = Utils(c, account_hash).extract_order_id(resp)

# 限价买入 GTC
resp = c.place_order(
    account_hash,
    equity_buy_limit("GOOG", 10, 175.0)
        .set_duration(Duration.GOOD_TILL_CANCEL)
        .set_session(Session.SEAMLESS)
        .build()
)
resp.raise_for_status()

# 取消订单
c.cancel_order(order_id, account_hash).raise_for_status()
```

---

## 期权策略下单

### 单腿买入开仓

```python
from schwab.orders.options import option_buy_to_open_limit, OptionSymbol
import datetime

sym = OptionSymbol("AAPL", datetime.date(2025, 12, 19), "C", "200").build()
resp = c.place_order(account_hash, option_buy_to_open_limit(sym, 1, 5.50).build())
resp.raise_for_status()
```

### 牛市价差（Bull Call Spread）

```python
from schwab.orders.options import bull_call_vertical_open

expiry = datetime.date(2025, 12, 19)
long_call = OptionSymbol("SPY", expiry, "C", "550").build()
short_call = OptionSymbol("SPY", expiry, "C", "560").build()

resp = c.place_order(
    account_hash,
    bull_call_vertical_open(long_call, short_call, quantity=1, net_debit=5.0).build()
)
resp.raise_for_status()
```

### OCO 止盈止损

```python
from schwab.orders.common import one_cancels_other, Duration

oco = one_cancels_other(
    equity_sell_limit("AAPL", 10, 200.0).set_duration(Duration.GOOD_TILL_CANCEL),
    equity_sell_limit("AAPL", 10, 170.0).set_duration(Duration.GOOD_TILL_CANCEL),
)
c.place_order(account_hash, oco.build()).raise_for_status()
```

### 触发后下单（买入后自动挂止盈）

```python
from schwab.orders.common import first_triggers_second

trigger = first_triggers_second(
    equity_buy_limit("AAPL", 10, 180.0),
    equity_sell_limit("AAPL", 10, 200.0).set_duration(Duration.GOOD_TILL_CANCEL),
)
c.place_order(account_hash, trigger.build()).raise_for_status()
```

---

## 账户查询

### 持仓

```python
from schwab.client import Client

def get_positions(c, account_hash):
    resp = c.get_account(account_hash, fields=[Client.Account.Fields.POSITIONS])
    resp.raise_for_status()
    positions = resp.json()["securitiesAccount"].get("positions", [])
    return [{
        "symbol": p["instrument"].get("symbol"),
        "asset_type": p["instrument"].get("assetType"),
        "qty": p.get("longQuantity", 0) - p.get("shortQuantity", 0),
        "avg_price": p.get("averagePrice"),
        "market_value": p.get("marketValue"),
        "pnl": p.get("currentDayProfitLoss"),
    } for p in positions]
```

### 当日订单（按状态筛选）

```python
import datetime

def get_orders(c, account_hash, status=None):
    today = datetime.datetime.now()
    resp = c.get_orders_for_account(
        account_hash,
        from_entered_datetime=today.replace(hour=0, minute=0, second=0),
        to_entered_datetime=today,
        status=status,  # None=全部, Client.Order.Status.WORKING=未成交
    )
    resp.raise_for_status()
    return resp.json()
```

---

## 实时流式监控

### Level1 股票 + 账户活动

```python
from schwab.streaming import StreamClient
import asyncio, json

async def run_monitor(c, account_id, symbols):
    stream = StreamClient(c, account_id=account_id)

    def on_quote(msg):
        for item in msg.get("content", []):
            print(f"{item['key']:6s} bid={item.get('BID_PRICE')} ask={item.get('ASK_PRICE')}")

    def on_activity(msg):
        for item in msg.get("content", []):
            print(f"[ACCT] {item.get('MESSAGE_TYPE')}: {item.get('MESSAGE_DATA')}")

    await stream.login()
    # 必须先注册 handler，再订阅
    stream.add_level_one_equity_handler(on_quote)
    stream.add_account_activity_handler(on_activity)
    await stream.level_one_equity_subs(symbols)
    await stream.account_activity_sub()

    while True:
        await stream.handle_message()

asyncio.run(run_monitor(c, account_id=1234567890, symbols=["AAPL", "TSLA"]))
```

### 带自动重连的健壮流式客户端

```python
async def resilient_stream(c, account_id, symbols):
    attempt = 0
    while True:
        try:
            stream = StreamClient(c, account_id=account_id)
            await stream.login()
            stream.add_level_one_equity_handler(lambda msg: print(msg))
            await stream.level_one_equity_subs(symbols)
            attempt = 0
            while True:
                await stream.handle_message()
        except Exception as e:
            attempt += 1
            wait = min(2 ** attempt, 60)
            print(f"Disconnected: {e}. Reconnect in {wait}s...")
            await asyncio.sleep(wait)
```

---

## 批量请求与限速

```python
import time

def safe_request(func, *args, retries=3, **kwargs):
    for i in range(retries):
        resp = func(*args, **kwargs)
        if resp.status_code == 429:
            time.sleep(2 ** i)
            continue
        resp.raise_for_status()
        return resp
    raise RuntimeError("Rate limit retries exhausted")

# 批量历史下载
from pathlib import Path
import json

def download_histories(c, symbols, output_dir="./data"):
    Path(output_dir).mkdir(exist_ok=True)
    for i, sym in enumerate(symbols):
        try:
            resp = safe_request(c.get_price_history_every_day, sym)
            candles = resp.json().get("candles", [])
            (Path(output_dir) / f"{sym}.json").write_text(json.dumps(candles))
            print(f"[{i+1}/{len(symbols)}] {sym}: {len(candles)} candles")
        except Exception as e:
            print(f"[{i+1}/{len(symbols)}] {sym}: ERROR {e}")
        time.sleep(0.5)
```
