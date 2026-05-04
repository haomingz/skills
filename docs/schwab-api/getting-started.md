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

访问 [developer.schwab.com](https://developer.schwab.com)，点击 **Login** 使用你的 Schwab 经纪账户凭证登录（不是新建账号，直接使用现有账户登录）。

### 第二步：申请 API 产品

进入 **Products** 页面，选择：

| 产品 | 说明 | 推荐 |
|------|------|------|
| **Accounts and Trading Production** | 完整功能：下单、账户数据、市场数据 | ✅ 推荐选这个 |
| Market Data Production | 仅市场数据，不含交易功能 | 可单选 |

建议同时添加两个产品，覆盖所有使用场景。

### 第三步：注册 App

填写 App 信息：

| 字段 | 推荐设置 | 说明 |
|------|----------|------|
| App Name | 任意名称 | 仅内部标识 |
| Callback URL | `https://127.0.0.1:8182` | **关键**：必须与代码完全一致，包括末尾斜杠 |
| Order Limit | 120 | 每分钟最大下单次数，建议设最大值 |

> **注意**：callback URL 大小写敏感，多一个斜杠都会导致认证失败。

提交后进入 **pending 状态**，Schwab 审核通常需要 1-5 个工作日。审核通过后可在 Dashboard 查看 **App Key** 和 **App Secret**。

---

## OAuth 认证流程详解

Schwab 使用标准 **三路 OAuth 2.0 Authorization Code Flow**：

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

### 自动刷新脚本（推荐：每 6 天执行一次）

使用 schwab-py 内置工具刷新 token：

```bash
# 安装后可直接使用此命令行工具
schwab-generate-token.py \
    --api_key YOUR_APP_KEY \
    --app_secret YOUR_APP_SECRET \
    --callback_url https://127.0.0.1:8182 \
    --token_path /path/to/token.json
```

或在 Python 中触发刷新：

```python
from schwab import auth

# easy_client 会自动检测 token 是否过期，过期则重新走登录流程
c = auth.easy_client(
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET",
    callback_url="https://127.0.0.1:8182",
    token_path="/path/to/token.json",
    max_token_age=86400 * 6  # 6天后强制刷新
)
```

### Cron 定时刷新（Linux/Mac）

```bash
# 每6天凌晨2点刷新 token（需要无头浏览器或手动流程）
0 2 */6 * * /path/to/venv/bin/schwab-generate-token.py \
    --api_key $SCHWAB_KEY \
    --app_secret $SCHWAB_SECRET \
    --callback_url https://127.0.0.1:8182 \
    --token_path /path/to/token.json
```

### 从不同机器管理 Token

在有浏览器的机器上生成 token，再将 `token.json` 传到服务器：

```bash
# 在本地生成
schwab-generate-token.py --token_path ./token.json ...

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

**处理**：登录 developer.schwab.com 检查 App 状态是否为 Approved；期权交易需要 Schwab 账户单独开通期权权限。

### Callback URL 不匹配

**症状**：`redirect_uri_mismatch` 错误。

**处理**：代码中的 `callback_url` 必须与 Schwab 后台注册完全一致，包括：
- 末尾是否有斜杠：`https://127.0.0.1:8182` vs `https://127.0.0.1:8182/`
- 端口号
- http vs https

### 429 Rate Limit Exceeded

**原因**：超过 120 次/分钟的应用级限制。

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
3. 市场是否开盘（`c.get_market_hours()` 查询）
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
