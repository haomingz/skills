# 直接调用 Schwab 官方 REST API（不使用第三方库）

不依赖 `schwab-py`，用 `requests` 直接调用官方端点。适合：学习 API 原理、轻量脚本、非 Python 环境移植参考。

## API 基础 URL

```
认证端点:  https://api.schwabapi.com/v1/oauth/
市场数据:  https://api.schwabapi.com/marketdata/v1/
交易账户:  https://api.schwabapi.com/trader/v1/
```

## Contents
- OAuth 完整流程（手动实现）
- Token 刷新
- 行情数据调用示例
- 下单示例
- 与 schwab-py 的选择建议

---

## OAuth 完整流程（手动实现）

Schwab 使用标准 OAuth 2.0 Authorization Code Flow，需要三步：

### 第一步：构造授权 URL，让用户登录

```python
import requests
from urllib.parse import urlparse, parse_qs, urlencode
from base64 import b64encode

CLIENT_ID = "YOUR_APP_KEY"
CLIENT_SECRET = "YOUR_APP_SECRET"
REDIRECT_URI = "https://127.0.0.1:8182"

AUTH_BASE = "https://api.schwabapi.com/v1/oauth/authorize"
TOKEN_URL = "https://api.schwabapi.com/v1/oauth/token"

# 构造登录 URL（在浏览器中打开）
auth_params = {
    "response_type": "code",
    "client_id": CLIENT_ID,
    "redirect_uri": REDIRECT_URI,
}
auth_url = f"{AUTH_BASE}?{urlencode(auth_params)}"
print("请在浏览器中打开此 URL 并完成登录：")
print(auth_url)
```

### 第二步：从回调 URL 提取 code，换取 token

```python
# 用户登录后，浏览器跳转到类似：
# https://127.0.0.1:8182/?code=XXXX&session=YYYY
redirected_url = input("粘贴浏览器跳转后的完整 URL：")

# 提取 authorization code
parsed = urlparse(redirected_url)
code = parse_qs(parsed.query)["code"][0]

# 用 code 换取 access_token + refresh_token
credentials = f"{CLIENT_ID}:{CLIENT_SECRET}"
encoded = b64encode(credentials.encode()).decode()

resp = requests.post(
    TOKEN_URL,
    headers={
        "Authorization": f"Basic {encoded}",
        "Content-Type": "application/x-www-form-urlencoded",
    },
    data={
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
    },
)
resp.raise_for_status()
tokens = resp.json()

access_token = tokens["access_token"]    # 30 分钟有效
refresh_token = tokens["refresh_token"]  # 7 天有效，务必保存
print(f"Access token 获取成功，expires_in={tokens['expires_in']}s")
```

### 第三步：用 refresh_token 刷新 access_token

```python
def refresh_access_token(client_id, client_secret, refresh_token):
    credentials = f"{client_id}:{client_secret}"
    encoded = b64encode(credentials.encode()).decode()

    resp = requests.post(
        "https://api.schwabapi.com/v1/oauth/token",
        headers={
            "Authorization": f"Basic {encoded}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
        },
    )
    resp.raise_for_status()
    new_tokens = resp.json()
    return new_tokens["access_token"], new_tokens.get("refresh_token", refresh_token)

# access token 快过期时调用
access_token, refresh_token = refresh_access_token(CLIENT_ID, CLIENT_SECRET, refresh_token)
```

---

## 行情数据调用示例

所有请求只需在 Header 里带 `Authorization: Bearer <access_token>`：

```python
def get_headers(access_token):
    return {"Authorization": f"Bearer {access_token}"}

# 单标的实时报价
resp = requests.get(
    "https://api.schwabapi.com/marketdata/v1/AAPL/quotes",
    headers=get_headers(access_token),
)
resp.raise_for_status()
print(resp.json())

# 多标的报价
resp = requests.get(
    "https://api.schwabapi.com/marketdata/v1/quotes",
    headers=get_headers(access_token),
    params={"symbols": "AAPL,MSFT,TSLA"},
)
resp.raise_for_status()
quotes = resp.json()

# 历史 K 线
resp = requests.get(
    "https://api.schwabapi.com/marketdata/v1/pricehistory",
    headers=get_headers(access_token),
    params={
        "symbol": "AAPL",
        "periodType": "year",
        "period": 1,
        "frequencyType": "daily",
        "frequency": 1,
        "needExtendedHoursData": False,
    },
)
resp.raise_for_status()
candles = resp.json()["candles"]

# 期权链
resp = requests.get(
    "https://api.schwabapi.com/marketdata/v1/chains",
    headers=get_headers(access_token),
    params={
        "symbol": "AAPL",
        "contractType": "ALL",
        "strikeCount": 10,
        "includeUnderlyingQuote": True,
    },
)
resp.raise_for_status()
chain = resp.json()
```

---

## 账户与下单示例

```python
TRADER_BASE = "https://api.schwabapi.com/trader/v1"

# 获取账户哈希（必须先做这步）
resp = requests.get(
    f"{TRADER_BASE}/accounts/accountNumbers",
    headers=get_headers(access_token),
)
resp.raise_for_status()
account_hash = resp.json()[0]["hashValue"]

# 账户余额和持仓
resp = requests.get(
    f"{TRADER_BASE}/accounts/{account_hash}",
    headers=get_headers(access_token),
    params={"fields": "positions"},
)
resp.raise_for_status()
account = resp.json()

# 下单（市价买入 AAPL 1 股）
order_body = {
    "orderType": "MARKET",
    "session": "NORMAL",
    "duration": "DAY",
    "orderStrategyType": "SINGLE",
    "orderLegCollection": [
        {
            "instruction": "BUY",
            "quantity": 1,
            "instrument": {
                "symbol": "AAPL",
                "assetType": "EQUITY",
            },
        }
    ],
}
resp = requests.post(
    f"{TRADER_BASE}/accounts/{account_hash}/orders",
    headers={**get_headers(access_token), "Content-Type": "application/json"},
    json=order_body,
)
resp.raise_for_status()
# 201 Created = 成功，Location header 包含订单 ID
order_id = resp.headers.get("Location", "").split("/")[-1]
print(f"Order placed, ID: {order_id}")

# 下单（限价期权买入开仓）
option_order = {
    "orderType": "LIMIT",
    "price": 5.50,
    "session": "NORMAL",
    "duration": "DAY",
    "orderStrategyType": "SINGLE",
    "orderLegCollection": [
        {
            "instruction": "BUY_TO_OPEN",
            "quantity": 1,
            "instrument": {
                "symbol": "AAPL  251219C00200000",  # OCC 格式期权符号
                "assetType": "OPTION",
            },
        }
    ],
}
resp = requests.post(
    f"{TRADER_BASE}/accounts/{account_hash}/orders",
    headers={**get_headers(access_token), "Content-Type": "application/json"},
    json=option_order,
)
resp.raise_for_status()

# 取消订单
resp = requests.delete(
    f"{TRADER_BASE}/accounts/{account_hash}/orders/{order_id}",
    headers=get_headers(access_token),
)
# 200 = 取消成功
```

---

## 完整端点列表（直接调用路径）

### Market Data API（`/marketdata/v1/`）

| 端点 | 方法 | 说明 |
|------|------|------|
| `/{symbol}/quotes` | GET | 单标的实时报价 |
| `/quotes` | GET | 批量报价（`?symbols=A,B,C`） |
| `/pricehistory` | GET | 历史 K 线（`?symbol=AAPL&periodType=year`） |
| `/chains` | GET | 期权链 |
| `/expirationchain` | GET | 期权到期日列表 |
| `/markets` | GET | 市场交易时间 |
| `/markets/{market}` | GET | 单市场交易时间 |
| `/movers/{index}` | GET | 市场涨跌榜 |
| `/instruments` | GET | 标的搜索 |
| `/instruments/{cusip}` | GET | 按 CUSIP 查标的 |

### Trader API（`/trader/v1/`）

| 端点 | 方法 | 说明 |
|------|------|------|
| `/accounts/accountNumbers` | GET | 获取账户哈希（必须先调） |
| `/accounts` | GET | 所有账户余额/持仓 |
| `/accounts/{hash}` | GET | 单账户详情（`?fields=positions` 含持仓） |
| `/accounts/{hash}/orders` | GET | 账户订单列表 |
| `/accounts/{hash}/orders` | POST | 下单 |
| `/accounts/{hash}/orders/{id}` | GET | 查单个订单 |
| `/accounts/{hash}/orders/{id}` | PUT | 改单（替换） |
| `/accounts/{hash}/orders/{id}` | DELETE | 撤单 |
| `/accounts/{hash}/previewOrder` | POST | 订单预览（不实际下单） |
| `/accounts/{hash}/transactions` | GET | 历史交易记录 |
| `/accounts/{hash}/transactions/{id}` | GET | 单笔交易详情 |
| `/orders` | GET | 所有关联账户的订单 |

---

## 与 schwab-py 的选择建议

| 情况 | 推荐方式 |
|------|---------|
| Python 项目，想快速上手 | `schwab-py`：一行 `easy_client()` 搞定 OAuth |
| 学习 API 工作原理 | 直接 `requests`：每一步都可见 |
| 非 Python 环境（Go/JavaScript/Rust） | 直接 HTTP：参考本文档移植 OAuth 逻辑 |
| 生产环境 Python 服务 | `schwab-py`：内置 token 自动刷新，减少出错 |
| 只需要行情，不需要交易 | 直接 `requests`：3 行代码就够 |

**核心原理相同**：两种方式都是调用 `api.schwabapi.com` 的同一套 REST API。`schwab-py` 的价值在于正确处理 OAuth 的复杂边界情况（token 并发刷新、回调服务器、错误重试）。对于简单脚本，直接调用更透明；对于持续运行的应用，`schwab-py` 更可靠。
