# Online Retail Sales Analysis

End-to-end sales analysis of 541,909 online retail transactions: cleaned and analysed in SQL Server (T-SQL), then modelled and visualised in Power BI.

## Headline figures (valid sales only)
| Revenue | Orders | Customers | Avg order value |
|---|---|---|---|
| 10,271,433 | 19,773 | 4,334 | 519.47 |

## What's in the repo
| File | What it is |
|---|---|
| `online_retail_sql_queries.sql` | Staging table, cleaning step and 18 analysis queries (SQL Server) |
| `OnlineRetail.pbip` + `OnlineRetail.Report/` + `OnlineRetail.SemanticModel/` | Power BI Project (open the `.pbip` in Power BI Desktop) |
| `online_retail.zip` | The source data (`online_retail.csv`), zipped to fit GitHub's file size limit |

## Cleaning
- Removed cancelled invoices (`InvoiceNo` starting with `C`), returns (`Quantity <= 0`) and zero-price lines
- Removed non-product codes (postage, bank charges, Amazon fees, manual adjustments, gift vouchers)
- Converted Excel serial dates into proper date-times
- 541,909 raw lines became 527,758 valid sales lines

## SQL analysis
Total revenue, orders, unique customers and average order value; monthly, yearly and daily trends; top 10 products by revenue and quantity; top 10 customers; revenue and revenue share by country; data quality checks; net revenue including returns.

## Power BI dashboard
- DAX measures: Total Revenue, Orders, Customers, Avg Order Value
- Top 10 products and countries using `RANKX`
- KPI cards, monthly revenue trend, sales map and slicers

## How to open
1. Unzip `online_retail.zip`.
2. Open `OnlineRetail.pbip` in Power BI Desktop (2024 or newer).
3. Home > Transform data > Edit parameters > set `CsvPath` to the full path of `online_retail.csv`, then Refresh.

## Tools
SQL Server / SSMS, Power BI Desktop, Power Query, DAX
