# Schwab API 认证与 Token 管理

## Contents
- 前置：注册开发者账号
- OAuth 完整流程（schwab-py）
- OAuth 完整流程（直接调用 requests）
- Token 生命周期与刷新策略
- 故障排查

---

## 前置：注册开发者账号

1. 访问 [developer.schwab.com](https://developer.schwab.com)，用 Schwab 账户登录
2. **Products** → 申请 **Accounts and Trading Production**（含完整功能）
3. 注册 App，callback URL 设为 `https://127.0.0.1:8182`（注意大小写和末尾斜杠，必须与代码完全一致）
4. Order Limit 设 120（最大值）
5. 等待审批（1-5 个工作日），获得 **App Key** 和 **App Secret**

---

## OAuth 流程（schwab-py 方式，推荐）

```python
from schwab import auth

# 首次运行：打开浏览器，用户完成 Schwab 登录后自动保存 token
c = auth.easy_client(
    api_key="YOUR_APP_KEY",
    app_secret="YOUR_APP_SECRET",
    callback_url="https://127.0.0.1:8182",
    token_path="/path/to/token.json",   # 持久化存储 token
)

# 异步版本（高性能场景）
c = auth.easy_client(..., asyncio=True)

# 无浏览器环境：手动复制粘贴 URL
c = auth.client_from_manual_flow(
    api_key, app_secret, callback_url, token_path
)

# 已有 token 文件，直接加载
c = auth.client_from_token_file(token_path, api_key, app_secret)
```

---

## OAuth 流程（直接调用 requests，无第三方库）

Schwab 无官方 Python SDK，`schwab-py` 本质是封装以下流程：

```python
import requests
from urllib.parse import urlparse, parse_qs
from base64 import b64encode

CLIENT_ID = "YOUR_APP_KEY"
CLIENT_SECRET = "YOUR_APP_SECRET"
REDIRECT_URI = "https://127.0.0.1:8182"

# Step 1：构造授权 URL，在浏览器中打开
auth_url = (
    f"https://api.schwabapi.com/v1/oauth/authorize"
    f"?response_type=code&client_id={CLIENT_ID}&redirect_uri={REDIRECT_URI}"
)
print("在浏览器中打开：", auth_url)

# Step 2：从回调 URL 提取 code，换取 token
redirected_url = input("粘贴浏览器跳转后的完整 URL：")
code = parse_qs(urlparse(redirected_url).query)["code"][0]

encoded = b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
resp = requests.post(
    "https://api.schwabapi.com/v1/oauth/token",
    headers={"Authorization": f"Basic {encoded}",
             "Content-Type": "application/x-www-form-urlencoded"},
    data={"grant_type": "authorization_code", "code": code,
          "redirect_uri": REDIRECT_URI},
)
resp.raise_for_status()
tokens = resp.json()
access_token = tokens["access_token"]   # 30 分钟有效
refresh_token = tokens["refresh_token"] # 7 天有效，必须保存

# Step 3：刷新 access_token（每 30 分钟）
def refresh_access_token(refresh_token):
    encoded = b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    resp = requests.post(
        "https://api.schwabapi.com/v1/oauth/token",
        headers={"Authorization": f"Basic {encoded}",
                 "Content-Type": "application/x-www-form-urlencoded"},
        data={"grant_type": "refresh_token", "refresh_token": refresh_token},
    )
    resp.raise_for_status()
    data = resp.json()
    return data["access_token"], data.get("refresh_token", refresh_token)

# 后续所有请求携带 token
headers = {"Authorization": f"Bearer {access_token}"}
resp = requests.get("https://api.schwabapi.com/marketdata/v1/quotes/AAPL",
                    headers=headers)
```

---

## Token 生命周期与刷新策略

| Token 类型 | 有效期 | 处理方式 |
|-----------|--------|---------|
| Access Token | 30 分钟 | schwab-py 自动刷新；直接调用需手动刷新 |
| Refresh Token | **7 天** | **必须手动触发**，过期需重新完整 OAuth 登录 |

**推荐策略：每 6 天刷新一次 refresh token**

```bash
# 使用 schwab-py 内置工具（安装后可用）
schwab-generate-token.py \
    --api_key $SCHWAB_APP_KEY \
    --app_secret $SCHWAB_APP_SECRET \
    --callback_url https://127.0.0.1:8182 \
    --token_path /path/to/token.json
```

```python
# 代码方式强制刷新（超过 6 天则触发登录流程）
c = auth.easy_client(
    ...,
    max_token_age=86400 * 6  # 6 天后强制刷新
)
```

**跨机器部署**：在有浏览器的机器生成 token，再将 `token.json` 传到服务器：

```bash
scp token.json user@server:/app/token.json
# 服务器上用 client_from_token_file() 加载
```

---

## 故障排查

| 错误 | 原因 | 解决 |
|------|------|------|
| 401 Unauthorized | access token 过期 | schwab-py 自动刷新；若仍报 401 检查系统时钟 |
| 401（重新登录也不行） | refresh token 过期（>7天未刷新） | 重新走完整 OAuth 登录流程 |
| 403 Forbidden | App 未审批，或期权等权限未开通 | 登录 developer.schwab.com 检查 App 状态 |
| redirect_uri_mismatch | callback URL 不匹配 | 代码与后台注册的 URL 必须完全一致（含末尾斜杠） |
| 429 Rate Limit | 超过 120 次/分钟 | 加 `time.sleep(0.5)` 或指数退避重试 |
| 下单被拒 | 余额不足 / 无期权权限 / 市场未开盘 | 检查账户权限、余额、`get_market_hours()` |
| 流式连接断开 | 网络中断或服务端超时 | 捕获异常后延迟重连（见 common-recipes.md） |
