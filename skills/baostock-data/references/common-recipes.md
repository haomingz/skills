## 目录
- 批量下载多只股票
- 按行业筛选并下载
- 获取沪深300成分股K线
- 构建多季度财务数据表
- 交易日历工具函数
- 完整技术指标计算（MA/MACD/KDJ/RSI/BOLL/CCI）
- 双均线策略回测框架
- 停牌数据过滤
- 静默登录（屏蔽 stdout）

---

## 批量下载多只股票

```python
import baostock as bs
import pandas as pd

bs.login()

codes = ["sh.600000", "sh.601398", "sz.000001"]
frames = []
for code in codes:
    rs = bs.query_history_k_data_plus(
        code,
        "date,code,close,volume,pctChg,turn",
        start_date="2024-01-01",
        end_date="2024-12-31",
        frequency="d",
        adjustflag="2"
    )
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    if rows:
        frames.append(pd.DataFrame(rows, columns=rs.fields))

df = pd.concat(frames, ignore_index=True)
df['close']  = pd.to_numeric(df['close'],  errors='coerce')
df['pctChg'] = pd.to_numeric(df['pctChg'], errors='coerce')
df['turn']   = pd.to_numeric(df['turn'],   errors='coerce')
bs.logout()
```

---

## 按行业筛选并下载

```python
import baostock as bs
import pandas as pd

bs.login()

# 获取全市场行业分类
rs = bs.query_stock_industry()
rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
df_ind = pd.DataFrame(rows, columns=rs.fields)

# 筛选指定行业（如"银行"）
target_codes = df_ind[df_ind['industry'] == '银行']['code'].tolist()
print(f"银行板块共 {len(target_codes)} 只股票")

# 批量下载K线
frames = []
for code in target_codes:
    rs = bs.query_history_k_data_plus(
        code, "date,code,close,pctChg",
        start_date="2024-01-01", end_date="2024-12-31",
        frequency="d", adjustflag="2"
    )
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    if rows:
        frames.append(pd.DataFrame(rows, columns=rs.fields))

df = pd.concat(frames, ignore_index=True)
bs.logout()
```

---

## 获取沪深300成分股K线

```python
import baostock as bs
import pandas as pd

bs.login()

rs = bs.query_hs300_stocks()
rows_idx = []
while (rs.error_code == '0') and rs.next():
    rows_idx.append(rs.get_row_data())
df_hs300 = pd.DataFrame(rows_idx, columns=rs.fields)

all_frames = []
for code in df_hs300['code'].tolist():
    rs_k = bs.query_history_k_data_plus(
        code, "date,code,close,pctChg",
        start_date="2024-06-01", end_date="2024-06-30",
        frequency="d", adjustflag="2"
    )
    rows = []
    while (rs_k.error_code == '0') and rs_k.next():
        rows.append(rs_k.get_row_data())
    if rows:
        all_frames.append(pd.DataFrame(rows, columns=rs_k.fields))

df = pd.concat(all_frames, ignore_index=True)
df['close']  = pd.to_numeric(df['close'],  errors='coerce')
df['pctChg'] = pd.to_numeric(df['pctChg'], errors='coerce')
bs.logout()
```

---

## 构建多季度财务数据表

```python
import baostock as bs
import pandas as pd

bs.login()

code = "sh.600000"
quarters = [(2022, 1), (2022, 2), (2022, 3), (2022, 4),
            (2023, 1), (2023, 2), (2023, 3), (2023, 4)]

rows = []
for year, q in quarters:
    rs = bs.query_profit_data(code=code, year=year, quarter=q)
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())

df = pd.DataFrame(rows, columns=rs.fields)
for col in ['roeAvg', 'npMargin', 'gpMargin', 'epsTTM']:
    df[col] = pd.to_numeric(df[col], errors='coerce')

bs.logout()
print(df[['statDate', 'roeAvg', 'npMargin', 'epsTTM']])
```

---

## 交易日历工具函数

```python
import baostock as bs
import pandas as pd

bs.login()

rs = bs.query_trade_dates(start_date="2024-01-01", end_date="2024-12-31")
rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
df_cal = pd.DataFrame(rows, columns=rs.fields)
trading_days = df_cal[df_cal['is_trading_day'] == '1']['calendar_date'].tolist()

def is_trading_day(d: str) -> bool:
    return d in trading_days

def prev_trading_day(d: str) -> str:
    idx = trading_days.index(d)
    return trading_days[idx - 1] if idx > 0 else None

def next_trading_day(d: str) -> str:
    idx = trading_days.index(d)
    return trading_days[idx + 1] if idx < len(trading_days) - 1 else None

bs.logout()
```

---

## 完整技术指标计算（MA/MACD/KDJ/RSI/BOLL/CCI）

```python
import baostock as bs
import pandas as pd
import numpy as np

bs.login()

rs = bs.query_history_k_data_plus(
    "sz.000001",
    "date,open,high,low,close,volume",
    start_date="2023-01-01", end_date="2024-12-31",
    frequency="d", adjustflag="2"
)
rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
df = pd.DataFrame(rows, columns=rs.fields)
for col in ['open', 'high', 'low', 'close', 'volume']:
    df[col] = pd.to_numeric(df[col], errors='coerce')
df['date'] = pd.to_datetime(df['date'])
df = df.dropna(subset=['close']).reset_index(drop=True)

bs.logout()

# ── 均线系统 ──────────────────────────────
for n in [5, 10, 20, 30, 60, 120, 250]:
    df[f'ma{n}'] = df['close'].rolling(n).mean()

# ── MACD（DIF/DEA/柱状线）────────────────
ema12 = df['close'].ewm(span=12, adjust=False).mean()
ema26 = df['close'].ewm(span=26, adjust=False).mean()
df['macd_dif'] = ema12 - ema26
df['macd_dea'] = df['macd_dif'].ewm(span=9, adjust=False).mean()
df['macd']     = 2 * (df['macd_dif'] - df['macd_dea'])

# ── KDJ（9日随机指标）────────────────────
low9  = df['low'].rolling(9).min()
high9 = df['high'].rolling(9).max()
rsv   = (df['close'] - low9) / (high9 - low9).replace(0, np.nan) * 100
df['kdj_k'] = rsv.ewm(com=2, adjust=False).mean()
df['kdj_d'] = df['kdj_k'].ewm(com=2, adjust=False).mean()
df['kdj_j'] = 3 * df['kdj_k'] - 2 * df['kdj_d']

# ── RSI（6/12/24日）──────────────────────
def calc_rsi(series, period):
    delta = series.diff()
    gain  = delta.clip(lower=0).ewm(com=period - 1, adjust=False).mean()
    loss  = (-delta.clip(upper=0)).ewm(com=period - 1, adjust=False).mean()
    return 100 - 100 / (1 + gain / loss.replace(0, np.nan))

df['rsi_6']  = calc_rsi(df['close'], 6)
df['rsi_12'] = calc_rsi(df['close'], 12)
df['rsi_24'] = calc_rsi(df['close'], 24)

# ── 布林带（20日，2倍标准差）──────────────
df['boll_middle'] = df['close'].rolling(20).mean()
std20 = df['close'].rolling(20).std()
df['boll_upper'] = df['boll_middle'] + 2 * std20
df['boll_lower'] = df['boll_middle'] - 2 * std20

# ── CCI（14日商品通道指标）───────────────
tp = (df['high'] + df['low'] + df['close']) / 3
ma_tp = tp.rolling(14).mean()
md    = tp.rolling(14).apply(lambda x: np.abs(x - x.mean()).mean(), raw=True)
df['cci'] = (tp - ma_tp) / (0.015 * md.replace(0, np.nan))

print(df[['date', 'close', 'ma20', 'macd_dif', 'kdj_k', 'rsi_12', 'boll_upper', 'cci']].tail())
```

---

## 双均线策略回测框架

```python
import baostock as bs
import pandas as pd

bs.login()

rs = bs.query_history_k_data_plus(
    "sz.000001", "date,open,close",
    start_date="2023-01-01", end_date="2023-12-31",
    frequency="d", adjustflag="2"
)
rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
df = pd.DataFrame(rows, columns=rs.fields)
for col in ['open', 'close']:
    df[col] = pd.to_numeric(df[col], errors='coerce')

df['MA5']  = df['close'].rolling(5).mean()
df['MA20'] = df['close'].rolling(20).mean()

initial_cash = 100_000
cash, shares = initial_cash, 0
trades = []

for i in range(20, len(df)):
    # 金叉买入
    if df['MA5'].iloc[i] > df['MA20'].iloc[i] and df['MA5'].iloc[i-1] <= df['MA20'].iloc[i-1]:
        if cash > 0:
            price  = df['close'].iloc[i]
            shares = int(cash / price / 100) * 100   # 整手
            cash  -= shares * price
            trades.append({'date': df['date'].iloc[i], 'action': '买入', 'price': price, 'shares': shares})
    # 死叉卖出
    elif df['MA5'].iloc[i] < df['MA20'].iloc[i] and df['MA5'].iloc[i-1] >= df['MA20'].iloc[i-1]:
        if shares > 0:
            price = df['close'].iloc[i]
            cash += shares * price
            trades.append({'date': df['date'].iloc[i], 'action': '卖出', 'price': price, 'shares': shares})
            shares = 0

final_value  = cash + shares * df['close'].iloc[-1]
total_return = (final_value - initial_cash) / initial_cash * 100
print(f"总收益率: {total_return:.2f}%，交易次数: {len(trades)}")

bs.logout()
```

---

## 停牌数据过滤

```python
# 方式1：过滤停牌行（volume 为字符串 '0'）
df = df[df['volume'] != '0']

# 方式2：过滤停牌状态字段
df = df[df['tradestatus'] == '1']

# 方式3：过滤后重置索引
df = df[df['volume'] != '0'].reset_index(drop=True)
```

---

## 静默登录（屏蔽 stdout 输出）

```python
import baostock as bs
import os, contextlib

with open(os.devnull, 'w') as devnull:
    with contextlib.redirect_stdout(devnull):
        lg = bs.login()

assert lg.error_code == '0', f"登录失败: {lg.error_msg}"

# ... 查询代码 ...

with open(os.devnull, 'w') as devnull:
    with contextlib.redirect_stdout(devnull):
        bs.logout()
```
