> 官方文档：`http://baostock.com/baostock/index.php/Python_API文档`
> BaoStock 接口较稳定，但部分字段（如财务公式）需以官方文档为准。

## Contents
- K 线行情 API
- 证券基本信息 API
- 季频财务数据 API
- 季频公司报告 API
- 除权除息与复权因子 API
- 板块与指数成分 API
- 宏观经济 API

---

## K 线行情 API

### `query_history_k_data_plus(code, fields, start_date, end_date, frequency, adjustflag)`

获取历史 K 线数据（日/周/月/分钟），是最核心的接口。

| 参数 | 必填 | 说明 |
|------|------|------|
| `code` | 是 | `sh.XXXXXX` 或 `sz.XXXXXX` 或 `bj.XXXXXX` |
| `fields` | 是 | 逗号分隔的字段名（日线与分钟线不同） |
| `start_date` | 否 | `"YYYY-MM-DD"`，默认 `"2015-01-01"` |
| `end_date` | 否 | `"YYYY-MM-DD"`，默认最近交易日 |
| `frequency` | 否 | `d`/`w`/`m`/`5`/`15`/`30`/`60`，默认 `d` |
| `adjustflag` | 否 | `"1"`=后复权，`"2"`=前复权，`"3"`=不复权（默认）|

**日线字段**（含停牌证券）：

| 字段 | 描述 | 算法/备注 |
|------|------|-----------|
| `date` | 交易日期 | `YYYY-MM-DD` |
| `code` | 证券代码 | |
| `open` | 开盘价 | 精度：4位小数，元 |
| `high` | 最高价 | |
| `low` | 最低价 | |
| `close` | 收盘价 | |
| `preclose` | 前收盘价 | 除权除息日会调整，非前一日实际收盘价 |
| `volume` | 成交数量 | 单位：股 |
| `amount` | 成交金额 | 单位：元 |
| `adjustflag` | 复权状态 | 1=后复权 2=前复权 3=不复权 |
| `turn` | 换手率 | 成交量/流通股本×100%；停牌日为空字符串 |
| `tradestatus` | 交易状态 | 1=正常 0=停牌 |
| `pctChg` | 涨跌幅(%) | (收盘价-前收盘价)/前收盘价×100% |
| `peTTM` | 滚动市盈率 | 股价×总股本/归母净利润TTM |
| `pbMRQ` | 市净率 | 总市值/(最近归属母公司股东权益-其他权益工具) |
| `psTTM` | 滚动市销率 | 股价×总股本/营业总收入TTM |
| `pcfNcfTTM` | 滚动市现率 | 股价×总股本/现金及等价物净增加额TTM |
| `isST` | 是否ST | 1=是，0=否 |

**分钟线字段**（5/15/30/60分钟，不含指数）：

| 字段 | 描述 |
|------|------|
| `date` | 日期 |
| `time` | 时间，格式 `YYYYMMDDHHMMSSsss`（17位） |
| `code` | 证券代码 |
| `open`/`high`/`low`/`close` | 价格 |
| `volume` | 区间累计成交数量 |
| `amount` | 区间累计成交金额 |
| `adjustflag` | 复权状态 |

**周/月线字段**：`date, code, open, high, low, close, volume, amount, adjustflag, turn, pctChg`

> 停牌处理：停牌日日线的开/高/低/收均为前一交易日收盘价，成交量、成交额为 0，换手率为空字符串。

---

## 证券基本信息 API

### `query_all_stock(day="")`

获取指定交易日所有证券代码及交易状态。

- `day`：`"YYYY-MM-DD"`，为空默认今天；非交易日返回空 DataFrame
- 返回字段：`code`（证券代码）、`tradeStatus`（1=正常，0=停牌）、`code_name`（证券名称）

### `query_stock_basic(code="", code_name="")`

获取证券基本资料，支持模糊名称查询。两个参数均可为空（返回全部股票）。

| 返回字段 | 描述 |
|----------|------|
| `code` | 证券代码 |
| `code_name` | 证券名称 |
| `ipoDate` | 上市日期 |
| `outDate` | 退市日期（未退市为空） |
| `type` | 1=股票 2=指数 3=其它 4=可转债 5=ETF |
| `status` | 1=上市 0=退市 |

### `query_trade_dates(start_date, end_date)`

查询交易日历。

| 返回字段 | 描述 |
|----------|------|
| `calendar_date` | 日期 |
| `is_trading_day` | 1=交易日，0=非交易日 |

筛选交易日：`df[df['is_trading_day'] == '1']`

### `query_stock_industry(code="", date="")`

行业分类（申万一级），每周一更新。

| 返回字段 | 描述 |
|----------|------|
| `updateDate` | 更新日期 |
| `code` | 证券代码 |
| `code_name` | 证券名称 |
| `industry` | 所属行业（如"银行"） |
| `industryClassification` | 行业分类标准（如"申万一级行业"） |

---

## 季频财务数据 API

所有季频接口参数格式相同：

```python
rs = bs.query_profit_data(code="sh.600000", year=2024, quarter=3)
```

- `code`：必填
- `year`：整数，默认当前年
- `quarter`：1/2/3/4，默认当前季度；数据自 2007 年起

通用返回字段：`code`（证券代码）、`pubDate`（财报发布日期）、`statDate`（财报统计截止日，如 2024-06-30）

### `query_profit_data` — 盈利能力

| 字段 | 描述 | 算法 |
|------|------|------|
| `roeAvg` | 净资产收益率(平均)(%) | 归母净利润/[(期初+期末归母权益)/2]×100% |
| `npMargin` | 销售净利率(%) | 净利润/营业收入×100% |
| `gpMargin` | 销售毛利率(%) | (营收-营业成本)/营收×100% |
| `netProfit` | 净利润(元) | |
| `epsTTM` | 每股收益(TTM) | 归母净利润TTM/最新总股本 |
| `MBRevenue` | 主营营业收入(元) | |
| `totalShare` | 总股本 | |
| `liqaShare` | 流通股本 | |

### `query_operation_data` — 营运能力

| 字段 | 描述 | 算法 |
|------|------|------|
| `NRTurnRatio` | 应收账款周转率(次) | 营收/[(期初+期末应收票据及账款净额)/2] |
| `NRTurnDays` | 应收账款周转天数(天) | 季报天数/应收账款周转率 |
| `INVTurnRatio` | 存货周转率(次) | 营业成本/[(期初+期末存货净额)/2] |
| `INVTurnDays` | 存货周转天数(天) | 季报天数/存货周转率 |
| `CATurnRatio` | 流动资产周转率(次) | 营业总收入/[(期初+期末流动资产)/2] |
| `AssetTurnRatio` | 总资产周转率 | 营业总收入/[(期初+期末总资产)/2] |

### `query_growth_data` — 成长能力

| 字段 | 描述 |
|------|------|
| `YOYEquity` | 净资产同比增长率(%) |
| `YOYAsset` | 总资产同比增长率(%) |
| `YOYNI` | 净利润同比增长率(%) |
| `YOYEPSBasic` | 基本每股收益同比增长率(%) |
| `YOYPNI` | 归母净利润同比增长率(%) |

### `query_balance_data` — 偿债能力

| 字段 | 描述 | 算法 |
|------|------|------|
| `currentRatio` | 流动比率 | 流动资产/流动负债 |
| `quickRatio` | 速动比率 | (流动资产-存货)/流动负债 |
| `cashRatio` | 现金比率 | (货币资金+交易性金融资产)/流动负债 |
| `YOYLiability` | 总负债同比增长率(%) | |
| `liabilityToAsset` | 资产负债率 | 负债总额/资产总额 |
| `assetToEquity` | 权益乘数 | 1/(1-资产负债率) |

### `query_cash_flow_data` — 现金流量

| 字段 | 描述 |
|------|------|
| `CAToAsset` | 流动资产/总资产 |
| `NCAToAsset` | 非流动资产/总资产 |
| `tangibleAssetToAsset` | 有形资产/总资产 |
| `ebitToInterest` | 已获利息倍数（息税前利润/利息费用） |
| `CFOToOR` | 经营现金流净额/营业收入 |
| `CFOToNP` | 经营现金流净额/净利润 |
| `CFOToGr` | 经营现金流净额/营业总收入 |

### `query_dupont_data` — 杜邦指标

| 字段 | 描述 |
|------|------|
| `dupontROE` | 净资产收益率 |
| `dupontAssetStoEquity` | 权益乘数（财务杠杆） |
| `dupontAssetTurn` | 总资产周转率 |
| `dupontPnitoni` | 归母净利润/净利润（母公司控股比例） |
| `dupontNitogr` | 净利润/营业总收入（销售获利率） |
| `dupontTaxBurden` | 净利润/利润总额（税负水平） |
| `dupontIntburden` | 利润总额/息税前利润（利息负担） |
| `dupontEbittogr` | 息税前利润/营业总收入（经营利润率） |

---

## 季频公司报告 API

### `query_performance_express_report(code, start_date, end_date)` — 业绩快报

按发布日期范围查询，提供 2006 年起数据。

| 返回字段 | 描述 |
|----------|------|
| `performanceExpPubDate` | 披露日期 |
| `performanceExpStatDate` | 统计日期 |
| `performanceExpUpdateDate` | 最新披露日期 |
| `performanceExpressTotalAsset` | 总资产 |
| `performanceExpressNetAsset` | 净资产 |
| `performanceExpressEPSChgPct` | 每股收益增长率 |
| `performanceExpressROEWa` | ROE（加权） |
| `performanceExpressEPSDiluted` | EPS（摊薄） |
| `performanceExpressGRYOY` | 营业总收入同比 |
| `performanceExpressOPYOY` | 营业利润同比 |

### `query_forecast_report(code, start_date, end_date)` — 业绩预告

按发布日期范围查询，提供 2003 年起数据。

| 返回字段 | 描述 |
|----------|------|
| `profitForcastExpPubDate` | 预告发布日期 |
| `profitForcastExpStatDate` | 预告统计日期 |
| `profitForcastType` | 类型（略增/略减/扭亏/首亏/续盈/续亏/不确定等） |
| `profitForcastAbstract` | 预告摘要 |
| `profitForcastChgPctUp` | 预告净利润增长上限(%) |
| `profitForcastChgPctDwn` | 预告净利润增长下限(%) |

---

## 除权除息与复权因子 API

### `query_dividend_data(code, year, yearType="report")`

- `year`：字符串，如 `"2024"`，必填
- `yearType`：`"report"`=预案公告年份（默认），`"operate"`=除权除息年份

| 返回字段 | 描述 |
|----------|------|
| `dividPreNoticeDate` | 预批露公告日 |
| `dividPlanAnnounceDate` | 预案公告日 |
| `dividOperateDate` | 除权除息日期 |
| `dividPayDate` | 派息日 |
| `dividCashPsBeforeTax` | 每股股利（税前） |
| `dividCashPsAfterTax` | 每股股利（税后） |
| `dividStocksPs` | 每股红股 |
| `dividReserveToStockPs` | 每股转增资本 |

### `query_adjust_factor(code, start_date, end_date)`

返回每次除权除息日的复权因子（涨跌幅复权法）。

| 返回字段 | 描述 | 算法 |
|----------|------|------|
| `dividOperateDate` | 除权除息日期 | |
| `foreAdjustFactor` | 前复权因子 | 除权日前一交易日收盘价/除权日前收盘价 |
| `backAdjustFactor` | 后复权因子 | 除权日前收盘价/除权日前一交易日收盘价 |
| `adjustFactor` | 本次复权因子 | |

---

## 板块与指数成分 API

均支持 `date` 参数（`"YYYY-MM-DD"`，为空取最新），每周一更新。

```python
rs = bs.query_hs300_stocks()   # 沪深300
rs = bs.query_sz50_stocks()    # 上证50
rs = bs.query_zz500_stocks()   # 中证500
```

返回字段：`updateDate`、`code`、`code_name`

常用指数代码：

| 指数 | 代码 |
|------|------|
| 上证综指 | `sh.000001` |
| 深证成指 | `sz.399001` |
| 沪深300 | `sh.000300` |
| 中证500 | `sh.000905` |
| 创业板指 | `sz.399006` |
| 上证50 | `sh.000016` |

---

## 宏观经济 API

### `query_deposit_rate_data(start_date, end_date)` — 存款利率

返回字段：`pubDate`（发布日期）、`demandDepositRate`（活期）、`fixedDepositRate3Month`、`fixedDepositRate6Month`、`fixedDepositRate1Year`、`fixedDepositRate2Year`、`fixedDepositRate3Year`、`fixedDepositRate5Year` 等

### `query_loan_rate_data(start_date, end_date)` — 贷款利率

返回字段：`pubDate`、`loanRate6Month`、`loanRate6MonthTo1Year`、`loanRate1YearTo3Year`、`loanRate3YearTo5Year`、`loanRateAbove5Year`、`mortgateRateBelow5Year`、`mortgateRateAbove5Year`

### `query_required_reserve_ratio_data(start_date, end_date, yearType="0")` — 存款准备金率

- `yearType`：`"0"`=查询公告日期，`"1"`=查询生效日期

返回字段：`pubDate`、`effectiveDate`、`bigInstitutionsRatioPre`（大型金融机构调整前）、`bigInstitutionsRatioAfter`、`mediumInstitutionsRatioPre`、`mediumInstitutionsRatioAfter`

### `query_money_supply_data_month(start_date, end_date)` — 货币供应量（月频）

- `start_date`/`end_date` 格式：`"YYYY-MM"`

返回字段：`statYear`、`statMonth`、`m0Month`、`m0YOY`、`m0ChainRelative`、`m1Month`、`m1YOY`、`m1ChainRelative`、`m2Month`、`m2YOY`、`m2ChainRelative`

### `query_money_supply_data_year(start_date, end_date)` — 货币供应量（年底余额）

- `start_date`/`end_date` 格式：`"YYYY"`

返回字段：`statYear`、`m0Year`、`m0YearYOY`、`m1Year`、`m1YearYOY`、`m2Year`、`m2YearYOY`

### `query_shibor_data(start_date, end_date)` — 银行间同业拆放利率

返回字段：`date`、`ON`（隔夜）、`1W`、`2W`、`1M`、`3M`、`6M`、`9M`、`1Y`
