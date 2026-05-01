## 目录
- Parquet 本地存储（全市场日线）
- QPS 限速与重试装饰器
- 增量更新模式
- 全市场批量下载（multiprocessing）
- 分钟线增量追加（HDF5）
- DuckDB 快速查询

---

## Parquet 本地存储（全市场日线）

一次性拉全量历史日线存为 parquet，后续秒级加载；全市场约 4000 只股票压缩后约 1.3 GB。

```python
import baostock as bs
import pandas as pd
from pathlib import Path

bs.login()

# 1. 获取全部股票代码
rs = bs.query_all_stock(day="2024-12-31")
rows = []
while (rs.error_code == '0') and rs.next():
    rows.append(rs.get_row_data())
all_stocks = pd.DataFrame(rows, columns=rs.fields)
# 只保留 A 股（排除指数）
codes = all_stocks[all_stocks['code'].str.match(r'(sh\.6|sz\.0|sz\.3|sh\.68|bj\.)')]
codes = codes['code'].tolist()

# 2. 批量下载（日线，前复权）
frames = []
for i, code in enumerate(codes):
    rs = bs.query_history_k_data_plus(
        code,
        "date,code,open,high,low,close,volume,amount,pctChg,turn,peTTM,pbMRQ",
        start_date="2010-01-01", end_date="2024-12-31",
        frequency="d", adjustflag="2"
    )
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    if rows:
        frames.append(pd.DataFrame(rows, columns=rs.fields))
    if (i + 1) % 100 == 0:
        print(f"进度: {i+1}/{len(codes)}")

df = pd.concat(frames, ignore_index=True)

# 3. 转换类型
num_cols = ['open', 'high', 'low', 'close', 'volume', 'amount', 'pctChg', 'turn', 'peTTM', 'pbMRQ']
for col in num_cols:
    df[col] = pd.to_numeric(df[col], errors='coerce')
df['date'] = pd.to_datetime(df['date'])

# 4. 保存 parquet（按日期分区加速查询）
Path("data").mkdir(exist_ok=True)
df.to_parquet("data/a_share_daily.parquet", index=False, compression='snappy')
print(f"保存完成，共 {len(df):,} 条记录")

bs.logout()

# 后续加载（秒级）
# df = pd.read_parquet("data/a_share_daily.parquet")
```

---

## QPS 限速与重试装饰器

分钟线 QPS 约 20 次/秒，批量查询时需限速。

```python
import baostock as bs
import pandas as pd
import time
import functools

def with_retry(max_retries=3, delay=1.0):
    """查询失败后自动重登录并重试。"""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    result = func(*args, **kwargs)
                    if result is not None and not result.empty:
                        return result
                    if attempt < max_retries - 1:
                        time.sleep(delay)
                except Exception as e:
                    print(f"第 {attempt+1} 次尝试失败: {e}")
                    bs.logout()
                    bs.login()
                    time.sleep(delay)
            return pd.DataFrame()
        return wrapper
    return decorator

@with_retry(max_retries=3)
def fetch_kline(code, start_date, end_date, frequency="d", adjustflag="2"):
    rs = bs.query_history_k_data_plus(
        code,
        "date,code,open,high,low,close,volume,amount,pctChg",
        start_date=start_date, end_date=end_date,
        frequency=frequency, adjustflag=adjustflag
    )
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    if not rows:
        return pd.DataFrame()
    df = pd.DataFrame(rows, columns=rs.fields)
    time.sleep(0.05)   # 限速：50ms per request ≤ 20 QPS
    return df

# 使用示例
bs.login()
codes = ["sh.600000", "sz.000001", "sh.601318"]
frames = [fetch_kline(c, "2024-01-01", "2024-12-31") for c in codes]
df = pd.concat([f for f in frames if not f.empty], ignore_index=True)
bs.logout()
```

---

## 增量更新模式

只拉取本地最新日期之后的数据，避免重复下载全量。

```python
import baostock as bs
import pandas as pd
from pathlib import Path
import datetime

PARQUET_PATH = "data/a_share_daily.parquet"

def get_last_date(code: str, parquet_path: str) -> str:
    """获取本地已有该股票的最新日期，没有则返回默认起始日。"""
    if not Path(parquet_path).exists():
        return "2010-01-01"
    df = pd.read_parquet(parquet_path, filters=[('code', '=', code)])
    if df.empty:
        return "2010-01-01"
    return df['date'].max().strftime('%Y-%m-%d')

def incremental_update(codes: list, parquet_path: str):
    bs.login()
    today = datetime.date.today().strftime('%Y-%m-%d')
    new_frames = []

    for code in codes:
        last_date = get_last_date(code, parquet_path)
        if last_date >= today:
            continue  # 已是最新，跳过

        rs = bs.query_history_k_data_plus(
            code,
            "date,code,open,high,low,close,volume,amount,pctChg",
            start_date=last_date, end_date=today,
            frequency="d", adjustflag="2"
        )
        rows = []
        while (rs.error_code == '0') and rs.next():
            rows.append(rs.get_row_data())
        if rows:
            new_frames.append(pd.DataFrame(rows, columns=rs.fields))

    bs.logout()

    if not new_frames:
        print("无新数据")
        return

    new_df = pd.concat(new_frames, ignore_index=True)
    for col in ['open', 'high', 'low', 'close', 'volume', 'pctChg']:
        new_df[col] = pd.to_numeric(new_df[col], errors='coerce')
    new_df['date'] = pd.to_datetime(new_df['date'])

    if Path(parquet_path).exists():
        old_df = pd.read_parquet(parquet_path)
        combined = pd.concat([old_df, new_df], ignore_index=True)
        combined = combined.drop_duplicates(subset=['date', 'code'])
    else:
        combined = new_df

    combined.to_parquet(parquet_path, index=False, compression='snappy')
    print(f"更新完成，新增 {len(new_df):,} 条")
```

---

## 全市场批量下载（multiprocessing）

BaoStock 非线程安全，多进程下载可显著提速。

```python
import baostock as bs
import pandas as pd
from multiprocessing import Pool

def fetch_one(args):
    """每个子进程独立建立 BaoStock 连接。"""
    code, start_date, end_date = args
    bs.login()
    rs = bs.query_history_k_data_plus(
        code,
        "date,code,open,high,low,close,volume,amount,pctChg",
        start_date=start_date, end_date=end_date,
        frequency="d", adjustflag="2"
    )
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    bs.logout()
    return pd.DataFrame(rows, columns=rs.fields) if rows else pd.DataFrame()

if __name__ == '__main__':
    # 主进程获取代码列表
    bs.login()
    rs = bs.query_all_stock(day="2024-12-31")
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    df_all = pd.DataFrame(rows, columns=rs.fields)
    codes = df_all[df_all['code'].str.match(r'(sh\.6|sz\.0|sz\.3)')]['code'].tolist()
    bs.logout()

    args = [(code, "2020-01-01", "2024-12-31") for code in codes]
    with Pool(processes=8) as pool:
        results = pool.map(fetch_one, args)

    df = pd.concat([r for r in results if not r.empty], ignore_index=True)
    df.to_parquet("data/batch_daily.parquet", index=False)
    print(f"完成，共 {len(df):,} 条")
```

---

## 分钟线增量追加（HDF5）

分钟线数据量大，适合用 HDF5 按日期分片存储。

```python
import baostock as bs
import pandas as pd
from pathlib import Path

HDF_PATH = "data/minute_5.h5"

def fetch_minute(code: str, start_date: str, end_date: str, frequency: str = "5"):
    bs.login()
    rs = bs.query_history_k_data_plus(
        code,
        "date,time,code,open,high,low,close,volume,amount,adjustflag",
        start_date=start_date, end_date=end_date,
        frequency=frequency, adjustflag="3"
    )
    rows = []
    while (rs.error_code == '0') and rs.next():
        rows.append(rs.get_row_data())
    bs.logout()

    if not rows:
        return pd.DataFrame()

    df = pd.DataFrame(rows, columns=rs.fields)
    # 转换时间格式：YYYYMMDDHHMMSSsss → datetime
    df['datetime'] = pd.to_datetime(df['time'].str[:14], format='%Y%m%d%H%M%S')
    for col in ['open', 'high', 'low', 'close', 'volume', 'amount']:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    return df

def append_to_hdf(df: pd.DataFrame, code: str, hdf_path: str):
    key = f"/{code.replace('.', '_')}"
    df.to_hdf(hdf_path, key=key, mode='a', format='table',
              data_columns=['datetime'], append=True)

# 使用示例
df_5min = fetch_minute("sz.000001", "2024-12-01", "2024-12-31")
if not df_5min.empty:
    append_to_hdf(df_5min, "sz.000001", HDF_PATH)
    print(f"追加 {len(df_5min)} 条分钟线")
```

---

## DuckDB 快速查询

将 parquet 文件加载到 DuckDB，支持毫秒级 SQL 查询。

```python
import duckdb
import pandas as pd

# pip install duckdb

con = duckdb.connect()

# 直接查询 parquet（无需加载到内存）
result = con.execute("""
    SELECT code, date, close, pctChg
    FROM 'data/a_share_daily.parquet'
    WHERE code = 'sh.600000'
      AND date >= '2024-01-01'
    ORDER BY date
""").df()

# 全市场某日涨幅 Top10
top10 = con.execute("""
    SELECT code, date, close, CAST(pctChg AS DOUBLE) AS pctChg
    FROM 'data/a_share_daily.parquet'
    WHERE date = '2024-06-28'
      AND volume != '0'
    ORDER BY CAST(pctChg AS DOUBLE) DESC
    LIMIT 10
""").df()
print(top10)

con.close()
```
