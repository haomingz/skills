# Schwab API 文档索引

Charles Schwab Trader API 学习与使用指南。

## 文档目录

| 文档 | 内容 |
|------|------|
| [../broker-comparison.md](../broker-comparison.md) | API 历史背景、与 IBKR/Alpaca/Finnhub/Polygon 对比、纯数据 API（Alpha Vantage/Twelve Data/yfinance）、选型建议 |
| [getting-started.md](getting-started.md) | 开发者注册、OAuth 认证流程、token 刷新策略、故障排查 |
| [api-reference.md](api-reference.md) | 所有 REST 端点、流式服务、订单类型、期权符号格式、限速规格 |
| [common-recipes.md](common-recipes.md) | 完整可运行代码：行情采集、期权下单、流式监控、账户管理 |
| [direct-api-calls.md](direct-api-calls.md) | 不使用第三方库、直接用 requests 调用官方 REST API |
| [thinkorswim-api.md](thinkorswim-api.md) | TOS 内部 WebSocket 协议（非官方逆向工程）说明 |

## 快速定位

- **第一次用 Schwab API** → [getting-started.md](getting-started.md)
- **想了解各券商 API 和市场数据服务的横向对比** → [broker-comparison.md](../broker-comparison.md)
- **查某个 API 端点怎么用** → [api-reference.md](api-reference.md)
- **要可以直接复制的代码** → [common-recipes.md](common-recipes.md)
- **不想用 schwab-py，直接裸调 HTTP** → [direct-api-calls.md](direct-api-calls.md)
- **想了解 ThinkorSwim 内部 API** → [thinkorswim-api.md](thinkorswim-api.md)

## 核心结论速查

### Schwab 有官方 Python SDK 吗？

**没有。** Schwab 只提供 REST API + Swagger 文档（在 developer.schwab.com）。没有官方 Python SDK。

两种选择：

| 方式 | 优点 | 适合场景 |
|------|------|---------|
| `schwab-py`（非官方库） | 自动处理 OAuth、token 刷新，代码简洁 | Python 项目首选 |
| 直接用 `requests` | 无依赖，逻辑完全透明，跨语言通用 | 学习理解 API、非 Python 环境、轻量脚本 |

两者都是调用**相同的官方 REST API**，只是 OAuth 的处理方式不同。

### ThinkorSwim 有 API 吗？

**有，但不官方。** TOS 内部使用一个 WebSocket（wsjson）协议，被社区逆向工程。详见 [thinkorswim-api.md](thinkorswim-api.md)。

用 Schwab Trader API（REST）可以访问和交易 **与 TOS 相同的账户和持仓**，对大多数自动化交易场景而言已足够。

## 官方资源

- 开发者门户：https://developer.schwab.com
- Swagger API 文档：https://developer.schwab.com/products/trader-api--individual/details/documentation/Retail%20Trader%20API%20Production
- schwab-py 文档：https://schwab-py.readthedocs.io
- schwab-py GitHub：https://github.com/alexgolec/schwab-py
