# IBKR API 文档索引

Interactive Brokers TWS API 与 Web API 学习与使用指南。

## 文档目录

| 文档 | 内容 |
|------|------|
| [../broker-comparison.md](../broker-comparison.md) | IBKR 与 Schwab/Alpaca/Finnhub/Polygon 横向对比、市场数据订阅费用、选型建议 |
| [getting-started.md](getting-started.md) | 安装配置、连接参数、IBC 自动登录、ibeam Docker、ib_async 快速上手 |
| [api-reference.md](api-reference.md) | 合约类型、订单类型、关键 API 方法、历史数据限制、错误代码 |
| [direct-ibapi.md](direct-ibapi.md) | 不使用 ib_async：官方 ibapi 回调架构详解 + Web API + requests 直接调用 |
| [webapi-vs-tws.md](webapi-vs-tws.md) | Web API vs TWS API 完整功能对比：市场数据、订单类型、速率限制、session 限制、选型建议 |
| [third-party-tools.md](third-party-tools.md) | ib_async、IBC、ibeam、ibind、gnzsnz/ib-gateway vs extrange/ibkr-docker 对比、ib_fundamental、ibkr-cli、icli、ibkr-mcp 详解 |

## 快速定位

- **第一次用 IBKR API** → [getting-started.md](getting-started.md)
- **TWS vs Web API 如何选** → [getting-started.md#api-类型选择](getting-started.md)
- **想了解与其他券商 API 的对比** → [broker-comparison.md](../broker-comparison.md)
- **查合约类型或订单类型的参数** → [api-reference.md](api-reference.md)
- **要可以直接复制的代码** → `skills/ibkr-trader/references/common-recipes.md`
- **不想用 ib_async，用官方 ibapi 或裸 HTTP 调用** → [direct-ibapi.md](direct-ibapi.md)
- **ib_async / IBC / ibeam / ibind / Docker 镜像怎么用** → [third-party-tools.md](third-party-tools.md)

## 核心结论速查

### IBKR 有官方 Python API 包吗？

官方提供 `ibapi`（原生回调架构，繁琐）。**推荐使用 `ib_async`**，是 `ib_insync` 的维护分支，提供简洁的同步写法，无需手动管理回调。

```bash
pip install ib_async
```

### TWS API vs Web API 如何选？

| 场景 | 选择 |
|------|------|
| Python 自动化交易、行情、账户 | **TWS API + ib_async**（功能最全） |
| 云端无桌面环境，只需 REST 访问 | **Web API + ibeam Docker** |
| 只需简单账户查询（非高频）| Web API 足够 |

### 实时行情费用提示

IBKR 对 US-listed stocks/ETFs 提供免费的 Cboe One + IEX 非综合实时数据；NYSE/NASDAQ 全市场综合数据、期货、期权实时数据通常需要按市场另行订阅。详见 [broker-comparison.md](../broker-comparison.md)。

## 官方资源

- IBKR Campus API 文档：https://www.interactivebrokers.com/campus/ibkr-api-page/
- TWS API GitHub：https://github.com/InteractiveBrokers/tws-api
- ib_async GitHub：https://github.com/ib-api-reloaded/ib_async
- ib_async 文档：https://ib-api-reloaded.github.io/ib_async/
- IBC（自动登录）：https://github.com/IbcAlpha/IBC
- ibeam（Web API Docker）：https://github.com/Voyz/ibeam
- 市场数据订阅定价：https://www.interactivebrokers.com/en/pricing/market-data-pricing.php
