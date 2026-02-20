
<img width="1536" height="1024" alt="Sale data SSMS" src="https://github.com/user-attachments/assets/48520bb9-b528-4a31-b8ba-7cc1805e6931" />







# 🧹 Sales Data Cleaning with SQL in SSMS

![SQL Server](https://img.shields.io/badge/SQL%20Server-SSMS-blue?logo=microsoftsqlserver)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Dataset](https://img.shields.io/badge/Dataset-Sales%20CSV-orange)

## 📌 Project Overview

This project demonstrates a **complete, end-to-end Data Cleaning workflow** using **SQL in SQL Server Management Studio (SSMS)**. The raw dataset (`sales.csv`) contains ~2,000 transactional sales records with a wide range of real-world data quality issues that are identified and resolved systematically.

---

## 🗂️ Dataset: `sales.csv`

| Column | Type | Description |
|---|---|---|
| `transaction_id` | INT | Unique transaction identifier |
| `customer_id` | INT | Customer identifier |
| `customer_name` | VARCHAR | Full name of the customer |
| `email` | VARCHAR | Customer email address |
| `purchase_date` | DATE | Date of purchase (DD/MM/YYYY) |
| `product_id` | INT | Product identifier |
| `category` | VARCHAR | Product category |
| `price` | DECIMAL | Unit price |
| `quantity` | INT | Units purchased |
| `total_amount` | DECIMAL | price × quantity |
| `payment_method` | VARCHAR | Mode of payment |
| `delivery_status` | VARCHAR | Status of delivery |
| `customer_address` | VARCHAR | Full customer address |

---

## 🦠 Identified Data Quality Issues

| # | Issue | Example |
|---|---|---|
| 1 | **Duplicate rows** | `transaction_id = 1001` appears twice |
| 2 | **Invalid emails** | `brownbenjamin` — no `@` symbol |
| 3 | **Negative quantities** | `quantity = -1`, `-3`, `-5` |
| 4 | **Mismatched total_amount** | `price * quantity` ≠ `total_amount` |
| 5 | **NULL / blank category** | Several rows have empty category |
| 6 | **Inconsistent payment methods** | `creditcard`, `credit card`, `CC`, `Credit Card` |
| 7 | **NULL delivery_status** | Rows with empty status field |
| 8 | **NULL customer_name** | Missing name values |
| 9 | **Wrong date format** | Stored as text `DD/MM/YYYY` instead of `DATE` |
| 10 | **Zero-quantity junk rows** | `quantity = 0`, `total_amount = 0` |

---

## 🔧 Cleaning Steps (SQL Workflow)

```
Step 0  →  Create raw & cleaned tables
Step 1  →  Exploratory Data Analysis (EDA)
Step 2  →  Schema design for cleaned table
Step 3  →  Remove duplicate rows (ROW_NUMBER + CTE)
Step 4  →  Fix negative quantities (flag as 'Returned')
Step 5  →  Recalculate mismatched total_amount
Step 6  →  Handle NULL values (delete, impute, or default)
Step 7  →  Standardise text fields (trim, lowercase email)
Step 8  →  Validate date range
Step 9  →  Add PK + indexes on cleaned table
Step 10 →  Final quality checks & distribution report
```

---

## 📂 Repository Structure

```
📦 sales-data-cleaning-sql/
├── 📄 README.md
├── 📄 sales.csv                    ← Raw dataset
└── 📄 sales_data_cleaning.sql      ← Full cleaning script (SSMS)
```

---

## 🚀 How to Run

### Prerequisites
- Microsoft SQL Server (2016+)
- SQL Server Management Studio (SSMS 18+)

## Dataset

**File:** `sales.csv`  
**Columns include:** transaction_id, customer_id, customer_name, email, purchase_date, product_id, category, price, quantity, total_amount, payment_method, delivery_status, customer_address

Common data issues handled:
- Missing category / price / total_amount
- Invalid emails (missing `@`, missing domain)
- Mixed / inconsistent payment methods (e.g., `creditcard`, `CC`, `Credit Card`)
- Duplicate `transaction_id` rows
- Negative quantity values (treated as returns)
- Mismatched totals (recomputed from price × quantity)
- Address field containing newline characters (split into 2 lines)

---
## How to Run

### 1) Create tables
Run the script sections:
- `sales_staging` (all VARCHAR)
- `sales_clean` (typed final table)

### 2) Import CSV
Update the path in the script:
```sql
BULK INSERT dbo.sales_staging
FROM 'C:\Data\sales.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='65001');
## Tools Used
- **Microsoft SQL Server**
- **SQL Server Management Studio (SSMS)**
- `BULK INSERT`, CTEs, `TRY_CONVERT`, `ROW_NUMBER`, standardization logic
---

## 📊 Results Summary

| Metric | Before Cleaning | After Cleaning |
|---|---|---|
| Total Rows | ~1,954 | ~1,900 *(exact depends on data)* |
| Duplicate Rows | Present | **Removed** |
| Invalid Emails | Present | **Set to NULL** |
| Negative Quantities | Present | **Converted to ABS values** |
| Inconsistent Payment Methods | 6+ variants | **4 standardised values** |
| NULL Categories | Present | **Set to 'Unknown'** |
| Date Format | Text DD/MM/YYYY | **SQL DATE type** |

---

## 🧠 Key SQL Concepts Used

- `ROW_NUMBER()` with `PARTITION BY` — deduplication
- `TRY_CAST` / `TRY_CONVERT` — safe type conversion
- `CASE WHEN` — conditional standardisation
- `NULLIF`, `COALESCE` — null handling
- `UPDATE` / `DELETE` — data correction
- `CTE` (Common Table Expressions) — modular logic
- `ABS()`, `ROUND()` — numerical fixes
- DDL: `ALTER TABLE`, `CREATE INDEX`, `ADD CONSTRAINT`

---
**Example Insights Queries**

Revenue by category

SELECT category, SUM(total_amount) AS net_revenue
FROM dbo.vw_sales_analytics
GROUP BY category
ORDER BY net_revenue DESC;

Monthly trend

SELECT DATEFROMPARTS(YEAR(purchase_date), MONTH(purchase_date), 1) AS month_start,
       SUM(total_amount) AS net_revenue
FROM dbo.vw_sales_analytics
GROUP BY DATEFROMPARTS(YEAR(purchase_date), MONTH(purchase_date), 1)
ORDER BY month_start;

What I Practiced

Importing CSV safely using a staging pattern

Cleaning messy text into reliable typed columns

Standardizing categorical values

Data quality rules + anomaly flags

Deduplication strategies with window functions

Building analytics-ready views
## 👤 Author

**Sarah Sair**
- 💼 [LinkedIn](https://linkedin.com/in/sarahsair)
- 🐙 [GitHub](https://github.com/sarahsair25)

---

## 📜 License

This project is licensed under the MIT License.
