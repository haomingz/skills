# 美股 API 与市场数据服务对比

美股自动化交易和量化研究涉及两类服务：**券商 API**（交易+数据一体）和**纯数据 API**（仅行情/指标，无法下单）。两者定位不同，选型前需先明确自己的核心需求。

| 分类 | 代表平台 | 特点 |
|------|---------|------|
| 券商 API | Schwab、IBKR、Alpaca | 账户持有者通过 API 下单，数据随账户附带；需开户 |
| 数据平台 | Finnhub、Polygon.io/Massive | 只提供行情/指标/基本面，不支持下单；邮箱注册即用 |
| 纯数据工具 | Alpha Vantage、Twelve Data、yfinance | REST 轮询为主，适合研究和回测；无需开户 |

---

## Contents
- 平台入口一览
- 实时行情数据对比（重点）
- 全功能横向对比表
- 纯数据 API 专区
- 选型建议
- 参考链接汇总

---

## 平台入口一览

| 平台 | 官网 | 开发者/API 文档 | Python 库 | 分类 | 需要证券账号 |
|------|------|----------------|-----------|------|------------|
| **Charles Schwab** | [schwab.com](https://www.schwab.com) | [developer.schwab.com](https://developer.schwab.com) | [schwab-py](https://github.com/alexgolec/schwab-py)（非官方）· [文档](https://schwab-py.readthedocs.io) | 券商 API | ✅ 必须 |
| **Interactive Brokers** | [interactivebrokers.com](https://www.interactivebrokers.com) | [TWS API 文档](https://interactivebrokers.github.io/tws-api/) · [Client Portal API](https://www.interactivebrokers.com/en/trading/ib-api.php) | [ib_insync](https://github.com/erdewit/ib_insync)（非官方）· [官方 ibapi](https://pypi.org/project/ibapi/) | 券商 API | ✅ 必须 |
| **Alpaca** | [alpaca.markets](https://alpaca.markets) | [docs.alpaca.markets](https://docs.alpaca.markets) | [alpaca-py](https://github.com/alpacahq/alpaca-py)（官方）| 券商 API | ⚠️ 模拟不需要/实盘需要 |
| **Finnhub** | [finnhub.io](https://finnhub.io) | [finnhub.io/docs/api](https://finnhub.io/docs/api) | [finnhub-python](https://github.com/Finnhub-Stock-API/finnhub-python)（官方）| 数据平台 | ❌ 邮箱注册即可 |
| **Polygon.io / Massive** | [polygon.io](https://polygon.io) / [massive.com](https://massive.com) | [polygon.io/docs](https://polygon.io/docs/stocks) | [polygon-api-client](https://github.com/polygon-io/client-python)（官方）| 数据平台 | ❌ 邮箱注册即可 |
| **Alpha Vantage** | [alphavantage.co](https://www.alphavantage.co) | [文档](https://www.alphavantage.co/documentation/) | [alpha_vantage](https://github.com/RomelTorres/alpha_vantage) | 纯数据工具 | ❌ 邮箱注册即可 |
| **Twelve Data** | [twelvedata.com](https://twelvedata.com) | [文档](https://twelvedata.com/docs) | [twelvedata-python](https://github.com/twelvedata/twelvedata-python) | 纯数据工具 | ❌ 邮箱注册即可 |
| **Yahoo Finance** | [finance.yahoo.com](https://finance.yahoo.com) | 非官方 | [yfinance](https://github.com/ranaroussi/yfinance) | 纯数据工具（非官方）| ❌ 无需注册 |

---

## 实时行情数据对比（重点）

> 各平台在实时数据上的策略差异极大，是选型最容易踩坑的地方。

### Charles Schwab

**注册要求**：必须持有 Schwab 证券账户，并在 developer.schwab.com 注册 App（审批 1-5 个工作日）。

| 数据类型 | 实时? | 费用 | 备注 |
|---------|-------|------|------|
| Level 1 快照报价（REST） | ✅ 实时 | 免费 | 账户持有者直接可用 |
| Level 1 流式报价（WebSocket） | ✅ 实时 | 免费 | 含股票/期权/期货/外汇 |
| Level 2 委托簿（NYSE/NASDAQ） | ✅ 实时 | 免费 | WebSocket |
| 期权 Greeks 流式（Delta/Gamma 等） | ✅ 实时 | 免费 | Level 1 期权流内含 |
| 历史 K 线 | ✅ | 免费 | 日线约 20 年；分钟线最近 10 天 |
| 历史期权数据 | ❌ 不支持 | — | — |

**结论**：账户持有者无需额外订阅即可获得全市场综合源（consolidated feed）实时行情，含 Level 2 委托簿。是散户券商 API 中数据门槛最低的之一。Refresh token 7 天强制刷新是主要运维成本。

参考：[Trader API 产品页](https://developer.schwab.com/products/trader-api--individual) · [Swagger 文档](https://developer.schwab.com/products/trader-api--individual/details/documentation/Retail%20Trader%20API%20Production)

---

### Interactive Brokers（IBKR）

**注册要求**：必须开设 IBKR 证券账户（个人账户在线开户，通常 1-3 个工作日审批）。

| 数据类型 | 实时? | 费用 | 备注 |
|---------|-------|------|------|
| US 股票/ETF（Cboe One + IEX） | ✅ 实时 | 免费 | 非全交易所汇总 |
| 其他品种（期权/期货等） | ⚠️ 延迟 15-20 分钟 | 免费（延迟版） | 免费层只有延迟数据 |
| NYSE/NASDAQ 综合实时（via API） | ✅ 实时 | **需付费订阅** | 非职业用户约 $1.5-$14/月/交易所 |
| Level 2 委托簿（via API） | ✅ 实时 | **需付费订阅** | NASDAQ TotalView 等需额外订阅 |
| 期货实时（CME/CBOT/NYMEX） | ✅ 实时 | **需付费订阅** | 约 $10-$30/月/交易所 |
| 历史 K 线 | ✅ | 需对应实时订阅 | 历史深度最全 |
| 历史期权数据 | ✅ | 需单独付费 | — |

**关键坑**：TWS 平台内展示的实时数据 ≠ API 可用数据。TWS 内某些数据是平台内协议免费，但通过 API 属于 off-platform 使用，需另行订阅。另外需要账户最低 $500 余额才能订阅行情，且 100 个并发行情线上限。

**结论**：全球覆盖最广，唯一支持期货/外汇/全球多市场下单的平台。但获取全市场综合实时数据需按交易所付费，轻量配置 $5-$50/月，专业配置可达 $200+/月。

参考：[市场数据定价](https://www.interactivebrokers.com/en/pricing/market-data-pricing.php) · [市场数据订阅指南](https://www.interactivebrokers.com/campus/ibkr-api-page/market-data-subscriptions/) · [TWS API 行情文档](https://interactivebrokers.github.io/tws-api/market_data.html)

---

### Alpaca

**注册要求**：纸面交易（Paper Trading）仅需邮箱注册；实盘交易需开设 Alpaca 证券账户（美国居民审批较快，国际用户需额外验证）。

| 数据类型 | 实时? | 费用 | 备注 |
|---------|-------|------|------|
| IEX 交易所实时数据 | ✅ 实时 | **免费** | 仅 IEX 一个交易所，约占市场 2-3% 成交量 |
| SIP 综合实时数据（全交易所） | ✅ 实时 | **Algo Trader Plus**（约 $99/月） | CTA + UTP 全市场聚合 |
| SIP 历史数据（15 分钟前） | ✅ | 免费 | 超过 15 分钟的历史 SIP 免费 |
| 15 分钟延迟 SIP 流 | ⚠️ 延迟 | 免费 | `v2/delayed_sip` 端点 |
| 期权实时数据 | ✅ 实时 | 需 Algo Trader Plus | 2024 年新增期权功能 |
| 加密货币实时 | ✅ 实时 | 免费 | — |

**IEX vs SIP 核心区别**：
- **IEX（免费）**：仅来自 Investors Exchange 一个交易所，市场占有率 ~2-3%，报出的买卖价不一定是全市场最优（NBBO）
- **SIP（付费）**：来自所有交易所的聚合数据（CTA + UTP），才是真正意义上的全市场 NBBO 实时行情

**结论**：官方 SDK + 免费 Paper Trading Sandbox，开发体验最佳，是入门首选。免费 IEX 适合策略验证；生产级策略需要 SIP 付费订阅（$99/月）。

参考：[市场数据 FAQ](https://alpaca.markets/docs/market-data-faq) · [实时数据文档](https://alpaca.markets/docs/real-time-stock-pricing-data) · [IEX vs SIP 解析](https://alpaca.markets/learn/understanding-stock-market-data)

---

### Finnhub

**注册要求**：邮箱注册即可，无需证券账户，免费 API Key 立即生效。

| 数据类型 | 实时? | 费用 | 备注 |
|---------|-------|------|------|
| 美股实时报价（REST 快照） | ✅ 实时 | 免费（60 次/分） | — |
| 美股实时流式（WebSocket） | ✅ 实时 | 免费（50 个标的） | 免费层最多同时订阅 50 个 |
| 美股实时流式（WebSocket） | ✅ 实时 | Basic $49.99/月 | 无上限标的数 |
| 全球股票（欧洲/亚洲等） | ⚠️ 延迟 | 免费 | 非美股市场延迟 15-60 分钟 |
| 基本面数据（财报/指标/EPS/PE） | ✅ | 免费 | — |
| 宏观经济指标（GDP/CPI 等） | ✅ | 免费 | — |
| 新闻情绪分析 | ✅ | 免费 | 公司新闻 + 情绪评分 |
| 加密货币实时 | ✅ 实时 | 免费 | WebSocket 支持 |
| 历史 K 线（1 分钟至月线） | ✅ | 免费 | — |
| Tick 级历史数据 | ✅ | 付费计划 | 免费层不含 |

**结论**：开放度最高的实时数据平台，无需证券账号，免费 WebSocket 支持 50 个标的，基本面 + 宏观数据免费丰富。适合数据驱动型应用（情绪分析、研究工具）以及不想绑定特定券商的独立数据需求。

参考：[API 文档](https://finnhub.io/docs/api) · [定价](https://finnhub.io/pricing) · [finnhub-python](https://github.com/Finnhub-Stock-API/finnhub-python) · [WebSocket 文档](https://finnhub.io/docs/api/websocket-trades)

---

### Polygon.io / Massive

**注册要求**：邮箱注册即可，无需证券账户。

> **品牌说明**：Polygon.io 于 2025 年 10 月 30 日更名为 Massive.com，API 端点 `api.polygon.io` 和旧 Python 包继续可用；新 Python 包为 `massive-com/client-python`。

| 数据类型 | 实时? | 费用 | 备注 |
|---------|-------|------|------|
| 美股报价（REST） | ⚠️ 延迟 15 分 | 免费（5 次/分） | 免费层只有延迟数据，限速极低 |
| 美股实时快照 + 流式（WebSocket） | ✅ 实时 | Developer $79/月 | SIP 全市场综合源 |
| Tick 级别历史数据 | ✅ | Starter $29/月 | 每秒级别精度，回测友好 |
| 期权链实时（含 Greeks） | ✅ 实时 | Developer $79/月 | — |
| 期权历史 Tick 数据 | ✅ | 付费计划 | 历史期权覆盖最广 |
| 加密货币 + 外汇实时 | ✅ 实时 | Developer $79/月 | — |
| 基本面数据 | ✅ | 付费计划 | — |

**结论**：专注纯数据的机构级平台，Tick 历史数据是所有平台中覆盖最广的，适合量化回测和高精度策略研发。免费层限制极大（5 次/分，15 分钟延迟），不适合生产使用；付费后质量达到机构标准。

参考：[API 文档](https://polygon.io/docs/stocks) · [定价](https://polygon.io/dashboard/subscriptions) · [Python 客户端](https://github.com/polygon-io/client-python) · [Massive 新官网](https://massive.com)

---

## 全功能横向对比表

| 维度 | **Schwab** | **IBKR** | **Alpaca** | **Finnhub** | **Polygon.io/Massive** |
|------|-----------|----------|-----------|-------------|------------------------|
| **分类** | 券商 API | 券商 API | 券商 API | 数据平台 | 数据平台 |
| **需要证券账号** | ✅ 必须 | ✅ 必须 | ⚠️ 实盘需要 | ❌ 邮箱注册 | ❌ 邮箱注册 |
| **API 类型** | REST + WebSocket | Socket(TWS) + REST | REST + WebSocket | REST + WebSocket | REST + WebSocket |
| **认证方式** | OAuth 2.0（三路） | 桌面客户端会话 | API Key | API Key | API Key |
| **官方 Python SDK** | ❌（有非官方 schwab-py）| ❌（ibapi 难用，有 ib_insync）| ✅ alpaca-py | ✅ finnhub-python | ✅ polygon-api-client |
| **沙盒/Paper Trading** | ❌ | ✅ | ✅ | ❌ | ❌ |
| **实时行情（免费）** | ✅ 全市场综合 | ⚠️ Cboe One+IEX 仅 | ⚠️ IEX 仅（2-3%）| ✅ WebSocket 50 标的 | ❌（15 分钟延迟）|
| **实时行情（付费入门）** | N/A（账户持有者免费）| 按交易所订阅 $5+/月 | SIP $99/月 | Basic $49.99/月 | Developer $79/月 |
| **免费 API 限速** | 120 次/分 | — | 200 次/分 | 60 次/分 | 5 次/分 |
| **Level 2 委托簿** | ✅ 免费 | ✅ 需付费 | ❌ | ❌ | ❌ |
| **期权 Greeks 实时流** | ✅ 免费 | ✅ 需付费 | ✅ 需付费 | ❌ | ✅ 付费计划 |
| **历史期权数据** | ❌ | ✅ 需付费 | ❌ | ❌ | ✅ 付费计划 |
| **Tick 历史数据** | ❌ | ✅ | ❌ | ❌ | ✅ 付费计划 |
| **基本面数据** | ❌ | ⚠️ 有限 | ❌ | ✅ 免费丰富 | ✅ 付费计划 |
| **股票下单** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **期权下单（多腿）** | ✅ 最多 4 腿 | ✅ 最多 6 腿 | ✅（2024+）| ❌ | ❌ |
| **期货/外汇下单** | ❌ 仅行情流 | ✅ | ❌ | ❌ | ❌ |
| **全球市场** | ❌ 美股 | ✅ 150+ 市场 | ❌ 美股 | ⚠️ 部分延迟 | ✅ 多市场 |
| **加密货币** | ❌ | ⚠️ 有限 | ✅ | ✅ 实时 | ✅ 实时 |
| **API 注册等待** | 1-5 工作日 | 开户 1-3 工作日 | 即时 | 即时 | 即时 |

---

## 纯数据 API 专区

以下工具**不提供交易功能**，专注行情数据、技术指标和基本面，无需证券账户，适合数据研究、策略研发、指标计算场景。

### Alpha Vantage

**注册**：邮箱注册，免费 API Key 立即生效（NASDAQ 官方授权数据）。

| 数据类型 | 实时? | 免费配额 | 备注 |
|---------|-------|---------|------|
| 美股实时报价（REST）| ✅ 实时 | 25 请求/天 | 免费层极低 |
| 历史日线/分钟线 | ✅ | 25 请求/天 | 最远可到 20 年 |
| 技术指标（80+ 种） | ✅ | 25 请求/天 | SMA/RSI/MACD/BBANDS 等内置 |
| 基本面（财报/盈利预测）| ✅ | 有限 | — |
| 外汇/加密货币 | ✅ | 25 请求/天 | — |
| WebSocket 实时流 | ❌ | — | 免费层无；企业版才有 |

**付费**：$50/月起，最高 1200 请求/分钟。官网：[alphavantage.co](https://www.alphavantage.co) · [文档](https://www.alphavantage.co/documentation/)

---

### Twelve Data

**注册**：邮箱注册，免费层 800 请求/天立即生效。

| 数据类型 | 实时? | 免费配额 | 备注 |
|---------|-------|---------|------|
| 美股实时报价（REST）| ✅ 实时 | 800 请求/天，8 请求/分 | 免费层余量合理 |
| 历史 K 线（日线至 1 分钟）| ✅ | 800 请求/天 | — |
| WebSocket 实时流 | ⚠️ 延迟 | 免费（仅延迟版）| 实时 WebSocket 需付费 |
| 技术指标（130+ 种）| ✅ | 800 请求/天 | 直接由 API 计算返回，无需自行实现 |
| 全球股票（50+ 国家）| ✅ | 按请求 | — |
| 加密货币/外汇 | ✅ | 800 请求/天 | — |

**付费**：Basic $8/月（5000 请求/天 + 实时 WebSocket）。官网：[twelvedata.com](https://twelvedata.com) · [文档](https://twelvedata.com/docs)

---

### Yahoo Finance / yfinance（非官方）

**注册**：无需注册，直接 `pip install yfinance` 使用。

| 数据类型 | 实时? | 费用 | 备注 |
|---------|-------|------|------|
| 美股报价 | ⚠️ 延迟 15 分 | 免费 | 非官方逆向接口 |
| 历史日线（最远 1960s）| ✅ | 免费 | 数据质量参差不齐 |
| 期权链 | ⚠️ 延迟/不完整 | 免费 | — |
| 基本面（财报/资产负债表）| ✅ | 免费 | — |
| WebSocket 实时流 | ❌ | — | — |

**警告**：依赖未公开私有 API，Yahoo 多次更改接口导致库失效，**不建议用于生产系统**，适合快速原型和一次性分析。

---

### 纯数据工具横向对比

| 维度 | **Alpha Vantage** | **Twelve Data** | **yfinance** | **Finnhub** | **Polygon.io/Massive** |
|------|------------------|-----------------|--------------|-------------|------------------------|
| **免费配额** | 25 请求/天 | 800 请求/天 | 无限制（不稳定）| 60 次/分 | 5 次/分（15 分延迟）|
| **实时数据（免费）** | ✅ REST | ✅ REST | ❌ 延迟 15 分 | ✅ REST + WS 50 标的 | ❌ |
| **WebSocket 实时** | ❌（企业版才有）| ⚠️ 付费 | ❌ | ✅ 免费 50 标的 | ✅ 付费 |
| **技术指标** | ✅ 80+ | ✅ 130+ | ❌ | ❌ | ❌ |
| **基本面数据** | ✅ 丰富 | ⚠️ 有限 | ✅ 丰富 | ✅ 丰富 | ⚠️ 付费 |
| **历史深度** | 20 年 | 20+ 年 | 60+ 年 | 25 年 | 15 年+ |
| **数据可靠性** | ✅ 高（NASDAQ 授权）| ✅ 高 | ⚠️ 低（非官方）| ✅ 高 | ✅ 机构级 |
| **付费入门价** | $50/月 | $8/月 | N/A | $49.99/月 | $29/月 |

---

## 选型建议

### 按需求场景

| 场景 | 推荐 | 原因 |
|------|------|------|
| 已有 Schwab 账户，做美股+期权自动化 | **Schwab** | 实时数据全免费（含 Level 2），期权多腿下单完善 |
| 初学者，先用 paper trading 验证策略 | **Alpaca** | 免费 Sandbox、官方 SDK、文档最友好 |
| 全球多市场 / 期货 / 外汇下单 | **IBKR** | 唯一覆盖全资产类别 |
| 无券商账号，需要免费实时 WebSocket | **Finnhub** | 邮箱注册，50 标的免费 WebSocket，基本面免费丰富 |
| 量化回测，需要高精度 Tick 历史数据 | **Polygon.io/Massive** | Tick 历史最全，机构级数据质量 |
| 技术指标直接由 API 计算（不想自己实现）| **Twelve Data** | 130+ 内置指标，$8/月起步 |
| 快速原型 / 学习，不需要生产稳定性 | **yfinance** | 零注册，免费，历史数据 60+ 年 |
| 需要免费基本面 + 宏观经济数据 | **Finnhub / Alpha Vantage** | 财报、EPS、GDP/CPI 等免费覆盖 |

### 实时数据质量速查

```
全市场综合实时（免费）:
  Schwab ✅  需证券账号
  Finnhub ✅  50 标的 WebSocket，邮箱注册

全市场综合实时（需付费）:
  Alpaca SIP ~$99/月
  IBKR 按交易所单独订阅
  Polygon.io Developer $79/月

仅单交易所实时（免费）:
  Alpaca IEX（~2-3% 市场份额）
  IBKR Cboe One+IEX

延迟数据（完全免费）:
  Yahoo Finance 延迟 15 分钟
  Polygon.io 延迟 15 分钟，限速 5 次/分

⚠️  IEX 覆盖率低，不适合依赖 NBBO 的生产级策略
⚠️  yfinance 使用非官方接口，不建议生产使用
```

---

## 参考链接汇总

### Charles Schwab
- 开发者门户：https://developer.schwab.com
- Swagger API 文档：https://developer.schwab.com/products/trader-api--individual/details/documentation/Retail%20Trader%20API%20Production
- OAuth 指南：https://developer.schwab.com/user-guides/get-started/authenticate-with-oauth
- schwab-py GitHub：https://github.com/alexgolec/schwab-py
- schwab-py 文档：https://schwab-py.readthedocs.io

### Interactive Brokers
- TWS API 文档：https://interactivebrokers.github.io/tws-api/
- Client Portal API：https://www.interactivebrokers.com/en/trading/ib-api.php
- 市场数据定价：https://www.interactivebrokers.com/en/pricing/market-data-pricing.php
- 市场数据订阅指南：https://www.interactivebrokers.com/campus/ibkr-api-page/market-data-subscriptions/
- ib_insync GitHub：https://github.com/erdewit/ib_insync

### Alpaca
- 文档首页：https://docs.alpaca.markets
- 市场数据 FAQ：https://alpaca.markets/docs/market-data-faq
- 实时数据文档：https://alpaca.markets/docs/real-time-stock-pricing-data
- IEX vs SIP 解析：https://alpaca.markets/learn/understanding-stock-market-data
- alpaca-py GitHub：https://github.com/alpacahq/alpaca-py

### Finnhub
- API 文档：https://finnhub.io/docs/api
- 定价页面：https://finnhub.io/pricing
- WebSocket 文档：https://finnhub.io/docs/api/websocket-trades
- finnhub-python GitHub：https://github.com/Finnhub-Stock-API/finnhub-python

### Polygon.io / Massive
- API 文档：https://polygon.io/docs/stocks
- 定价页面：https://polygon.io/dashboard/subscriptions
- Python 客户端 GitHub：https://github.com/polygon-io/client-python
- Massive 新官网：https://massive.com

### 纯数据工具
- Alpha Vantage 文档：https://www.alphavantage.co/documentation/
- Alpha Vantage 定价：https://www.alphavantage.co/premium/
- alpha_vantage Python 库：https://github.com/RomelTorres/alpha_vantage
- Twelve Data 文档：https://twelvedata.com/docs
- Twelve Data 定价：https://twelvedata.com/pricing
- twelvedata-python GitHub：https://github.com/twelvedata/twelvedata-python
- yfinance GitHub：https://github.com/ranaroussi/yfinance
