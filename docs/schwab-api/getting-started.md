# Schwab API 入门与认证

## Contents
- 开发者账号注册
- App 注册与配置
- OAuth 认证流程详解
- Token 管理策略
- 常见故障排查

---

## 开发者账号注册

### 第一步：创建开发者账号

访问 [developer.schwab.com](https://developer.schwab.com)，先创建并登录 **Schwab Developer** 账号。开发者门户账号与 Schwab 经纪账户登录不是同一个概念；后面的 OAuth 授权流程才会跳转到 Schwab 经纪账户登录页，让你选择要授权给 App 的账户。

### 第二步：申请 API 产品

进入 **Products** 页面，选择：

| 产品 | 说明 | 推荐 |
|------|------|------|
| **Accounts and Trading Production** | 账户、持仓、订单、下单/改单/撤单；社区经验显示它通常覆盖 `schwab-py` 的主要功能 | ✅ 交易功能必选 |
| **Market Data Production** | 行情、历史价格、期权链、movers 等市场数据接口 | ✅ 需要行情时也添加 |

建议同时添加两个产品，覆盖所有使用场景。

### 第三步：注册 App

填写 App 信息：

| 字段 | 推荐设置 | 说明 |
|------|----------|------|
| App Name | 任意名称 | 仅内部标识 |
| Callback URL | `https://127.0.0.1:8182` | **关键**：必须与代码完全一致，包括是否有末尾斜杠 |
| Order Limit | 120 | 每分钟最大订单相关请求数（下单、改单、撤单），建议设最大值 |

> **注意**：callback URL 大小写敏感，多一个斜杠都会导致认证失败。

提交后通常会进入 **Approved - Pending** 状态；这个名字有点迷惑，实际还不能用。等状态变为 **Ready For Use** 后，才能在 Dashboard 查看并使用 **App Key** 和 **App Secret**。审核通常需要几天，具体以 Schwab 后台状态为准。

---

## OAuth 认证流程详解

Schwab 使用标准 **OAuth 2.0 Authorization Code Flow**：

```
用户 → App → Schwab 登录页 → 回调 URL (含 code) → 换取 token
```

### 首次认证（浏览器交互）

```python
from schwab import auth

c = auth.easy_client(
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET",
    callback_url="https://127.0.0.1:8182",
    token_path="/path/to/token.json"
)
```

首次运行：
1. 自动打开浏览器跳转到 Schwab 登录页
2. 用 Schwab 账户登录
3. 授权后浏览器跳转到 `https://127.0.0.1:8182/?code=...`
4. `schwab-py` 捕获 code，换取 token 并存入 `token.json`

后续运行：直接读取 `token.json`，自动刷新 access token。

### 非交互式认证（适合服务器/容器环境）

```python
from schwab import auth

# 手动复制粘贴 URL 的方式
c = auth.client_from_manual_flow(
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET",
    callback_url="https://127.0.0.1:8182",
    token_path="/path/to/token.json"
)
# 会打印一个 URL，在浏览器访问后，将重定向后的完整 URL 粘贴回终端
```

### 从已有 token 文件直接加载

```python
c = auth.client_from_token_file(
    token_path="/path/to/token.json",
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET"
)
```

---

## Token 管理策略

### Token 生命周期

```
Access Token ──── 30 分钟 ──→ 过期（schwab-py 自动刷新）
Refresh Token ─── 7 天 ───→ 过期（必须手动重新登录 OAuth）
```

### 重新生成 token（推荐：每 6 天手动做一次）

`schwab-py` 会自动用 refresh token 刷新 30 分钟有效的 access token，但 **7 天 refresh token 不能通过刷新延长**。接近 7 天时，需要重新走一次 OAuth 登录，生成新的 token 文件。

使用 `schwab-py` 内置工具重新生成 token：

```bash
# 安装后可直接使用此命令行工具
schwab-generate-token.py \
    --api_key YOUR_APP_KEY \
    --app_secret YOUR_APP_SECRET \
    --callback_url https://127.0.0.1:8182 \
    --token_file /path/to/token.json
```

或在 Python 中让 `easy_client()` 在 token 文件过旧时主动重新走登录流程：

```python
from schwab import auth

# easy_client 会自动刷新 access token；token 文件超过 max_token_age 后会重新走 OAuth 登录流程
c = auth.easy_client(
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET",
    callback_url="https://127.0.0.1:8182",
    token_path="/path/to/token.json",
    max_token_age=86400 * 6  # 6天后强制刷新
)
```

### 定时提醒或半自动重新生成（Linux/Mac）

下面这种方式仍然需要浏览器登录或人工复制回调 URL，不适合无人值守服务器。更稳妥的做法是把它当作每周提醒，在有浏览器的机器上重新生成 token。

```bash
# 每6天凌晨2点尝试重新生成 token（仍需要交互式 OAuth）
0 2 */6 * * /path/to/venv/bin/schwab-generate-token.py \
    --api_key $SCHWAB_KEY \
    --app_secret $SCHWAB_SECRET \
    --callback_url https://127.0.0.1:8182 \
    --token_file /path/to/token.json
```

### 从不同机器管理 Token

在有浏览器的机器上生成 token，再将 `token.json` 传到服务器：

```bash
# 在本地生成
schwab-generate-token.py --token_file ./token.json ...

# 传到服务器
scp token.json user@server:/app/token.json

# 服务器上直接加载
c = auth.client_from_token_file("./token.json", api_key, app_secret)
```

---

## 常见故障排查

### 401 Unauthorized

**原因**：Access token 过期（30 分钟），或 refresh token 过期（7 天）。

**处理**：
- Access token：`schwab-py` 应自动处理；若仍报 401，检查系统时钟是否同步
- Refresh token：重新执行完整 OAuth 登录流程，重新生成 `token.json`

### 403 Forbidden

**原因**：App 未获批准，或申请的功能未开通。

**处理**：登录 developer.schwab.com 检查 App 状态是否为 **Ready For Use**；期权交易需要 Schwab 账户单独开通期权权限。

### Callback URL 不匹配

**症状**：`redirect_uri_mismatch` 错误。

**处理**：代码中的 `callback_url` 必须与 Schwab 后台注册完全一致，包括：
- 末尾是否有斜杠：`https://127.0.0.1:8182` vs `https://127.0.0.1:8182/`
- 端口号
- http vs https

### 429 Rate Limit Exceeded

**原因**：超过非下单请求限速，或超过 App 中配置的订单相关请求上限（Order Limit，最高 120 次/分钟）。

**处理**：

```python
import time

def safe_request(func, *args, **kwargs):
    while True:
        resp = func(*args, **kwargs)
        if resp.status_code == 429:
            time.sleep(1)
            continue
        resp.raise_for_status()
        return resp
```

### 下单被拒（Order Rejected）

排查顺序：
1. 账户余额是否足够
2. 期权交易权限是否开通（Level 1-4）
3. 市场是否开盘（例如 `c.get_market_hours([Client.MarketHours.Market.EQUITY])` 查询）
4. 期权符号格式是否正确（用 `get_option_chain()` 验证）
5. 订单参数（数量、价格）是否合法

### 流式连接断开

```python
async def stream_with_reconnect():
    while True:
        try:
            await stream_client.login()
            # 注册 handlers...
            # 订阅...
            while True:
                await stream_client.handle_message()
        except Exception as e:
            print(f"Stream disconnected: {e}, reconnecting in 5s...")
            await asyncio.sleep(5)
```
