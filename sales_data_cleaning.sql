-- ============================================================
--  DATA CLEANING WITH SQL IN SSMS
--  Dataset : sales.csv
--  Author  : Data Analyst
--  Date    : 2024
-- ============================================================

-- ============================================================
-- STEP 0 : CREATE & LOAD THE RAW TABLE
-- ============================================================
-- In SSMS use: Tasks > Import Flat File (or Import Data wizard)
-- to load sales.csv into the table below, then run all steps.

USE SalesDB;
GO

-- Drop if re-running
IF OBJECT_ID('dbo.sales_raw',     'U') IS NOT NULL DROP TABLE dbo.sales_raw;
IF OBJECT_ID('dbo.sales_cleaned', 'U') IS NOT NULL DROP TABLE dbo.sales_cleaned;
GO

CREATE TABLE dbo.sales_raw (
    transaction_id   NVARCHAR(50),
    customer_id      NVARCHAR(50),
    customer_name    NVARCHAR(200),
    email            NVARCHAR(200),
    purchase_date    NVARCHAR(50),   -- stored as text first; will convert later
    product_id       NVARCHAR(50),
    category         NVARCHAR(100),
    price            NVARCHAR(50),
    quantity         NVARCHAR(50),
    total_amount     NVARCHAR(50),
    payment_method   NVARCHAR(100),
    delivery_status  NVARCHAR(100),
    customer_address NVARCHAR(500)
);
GO

-- After importing the CSV via the SSMS wizard, run the steps below.
-- ============================================================


-- ============================================================
-- STEP 1 : INITIAL EXPLORATION  (Understand the dirty data)
-- ============================================================

-- 1a. Total rows
SELECT COUNT(*) AS total_rows FROM dbo.sales_raw;

-- 1b. Preview
SELECT TOP 20 * FROM dbo.sales_raw;

-- 1c. Columns with NULLs / blanks
SELECT
    SUM(CASE WHEN transaction_id   IS NULL OR transaction_id   = '' THEN 1 ELSE 0 END) AS null_transaction_id,
    SUM(CASE WHEN customer_id      IS NULL OR customer_id      = '' THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN customer_name    IS NULL OR customer_name    = '' THEN 1 ELSE 0 END) AS null_customer_name,
    SUM(CASE WHEN email            IS NULL OR email            = '' THEN 1 ELSE 0 END) AS null_email,
    SUM(CASE WHEN purchase_date    IS NULL OR purchase_date    = '' THEN 1 ELSE 0 END) AS null_purchase_date,
    SUM(CASE WHEN product_id       IS NULL OR product_id       = '' THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN category         IS NULL OR category         = '' THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN price            IS NULL OR price            = '' THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN quantity         IS NULL OR quantity         = '' THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN total_amount     IS NULL OR total_amount     = '' THEN 1 ELSE 0 END) AS null_total_amount,
    SUM(CASE WHEN payment_method   IS NULL OR payment_method   = '' THEN 1 ELSE 0 END) AS null_payment_method,
    SUM(CASE WHEN delivery_status  IS NULL OR delivery_status  = '' THEN 1 ELSE 0 END) AS null_delivery_status,
    SUM(CASE WHEN customer_address IS NULL OR customer_address = '' THEN 1 ELSE 0 END) AS null_customer_address
FROM dbo.sales_raw;

-- 1d. Duplicate transaction IDs
SELECT transaction_id, COUNT(*) AS occurrences
FROM dbo.sales_raw
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 1e. Invalid emails (no @ symbol)
SELECT transaction_id, email
FROM dbo.sales_raw
WHERE email NOT LIKE '%@%';

-- 1f. Negative quantities
SELECT transaction_id, quantity, total_amount
FROM dbo.sales_raw
WHERE TRY_CAST(quantity AS INT) < 0;

-- 1g. Inconsistent payment methods
SELECT DISTINCT payment_method, COUNT(*) AS cnt
FROM dbo.sales_raw
GROUP BY payment_method
ORDER BY payment_method;

-- 1h. Inconsistent delivery statuses
SELECT DISTINCT delivery_status, COUNT(*) AS cnt
FROM dbo.sales_raw
GROUP BY delivery_status
ORDER BY delivery_status;

-- 1i. Category blanks
SELECT DISTINCT category, COUNT(*) AS cnt
FROM dbo.sales_raw
GROUP BY category
ORDER BY category;


-- ============================================================
-- STEP 2 : CREATE CLEANED TABLE
-- ============================================================

CREATE TABLE dbo.sales_cleaned (
    transaction_id   INT            NOT NULL,
    customer_id      INT            NOT NULL,
    customer_name    NVARCHAR(200),
    email            NVARCHAR(200),
    purchase_date    DATE           NOT NULL,
    product_id       INT            NOT NULL,
    category         NVARCHAR(100),
    price            DECIMAL(10,2),
    quantity         INT,
    total_amount     DECIMAL(12,2),
    payment_method   NVARCHAR(50),
    delivery_status  NVARCHAR(50),
    customer_address NVARCHAR(500)
);
GO


-- ============================================================
-- STEP 3 : REMOVE EXACT DUPLICATE ROWS
-- ============================================================
-- Keep only the first occurrence of each duplicate transaction_id.

WITH CTE_Dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY transaction_id
               ORDER BY (SELECT NULL)   -- no reliable ordering, keep first loaded
           ) AS rn
    FROM dbo.sales_raw
)
INSERT INTO dbo.sales_cleaned (
    transaction_id, customer_id, customer_name, email,
    purchase_date, product_id, category, price, quantity,
    total_amount, payment_method, delivery_status, customer_address
)
SELECT
    TRY_CAST(transaction_id AS INT),
    TRY_CAST(customer_id    AS INT),
    -- Clean customer_name: trim whitespace
    NULLIF(LTRIM(RTRIM(customer_name)), ''),
    -- Email: keep only valid emails, else NULL
    CASE WHEN email LIKE '%@%' THEN LTRIM(RTRIM(email)) ELSE NULL END,
    -- Date: convert DD/MM/YYYY -> DATE
    TRY_CONVERT(DATE, purchase_date, 103),
    TRY_CAST(product_id   AS INT),
    -- Category: replace blank with NULL
    NULLIF(LTRIM(RTRIM(category)), ''),
    TRY_CAST(price        AS DECIMAL(10,2)),
    TRY_CAST(quantity     AS INT),
    TRY_CAST(total_amount AS DECIMAL(12,2)),
    -- Standardise payment_method
    CASE
        WHEN LOWER(LTRIM(RTRIM(payment_method))) IN ('creditcard','credit card','cc','credit') THEN 'Credit Card'
        WHEN LOWER(LTRIM(RTRIM(payment_method))) IN ('debit card','debit')                     THEN 'Debit Card'
        WHEN LOWER(LTRIM(RTRIM(payment_method))) = 'paypal'                                    THEN 'PayPal'
        WHEN LOWER(LTRIM(RTRIM(payment_method))) = 'bank transfer'                              THEN 'Bank Transfer'
        ELSE NULLIF(LTRIM(RTRIM(payment_method)), '')
    END,
    -- Standardise delivery_status
    CASE
        WHEN LTRIM(RTRIM(delivery_status)) IN ('', 'NULL') THEN NULL
        ELSE LTRIM(RTRIM(delivery_status))
    END,
    NULLIF(LTRIM(RTRIM(customer_address)), '')
FROM CTE_Dedup
WHERE rn = 1;

-- Verify row count after dedup
SELECT COUNT(*) AS rows_after_dedup FROM dbo.sales_cleaned;


-- ============================================================
-- STEP 4 : HANDLE NEGATIVE QUANTITIES & NEGATIVE TOTAL_AMOUNT
-- ============================================================
-- Negative quantities likely represent returns; set them to
-- their absolute value and flag delivery_status as 'Returned'
-- when status is unknown.

UPDATE dbo.sales_cleaned
SET
    quantity     = ABS(quantity),
    total_amount = ABS(total_amount),
    delivery_status = COALESCE(delivery_status, 'Returned')
WHERE quantity < 0;

-- Verify
SELECT COUNT(*) AS remaining_negative_qty
FROM dbo.sales_cleaned
WHERE quantity < 0;


-- ============================================================
-- STEP 5 : FIX MISMATCHED total_amount
-- ============================================================
-- total_amount should equal price * quantity.
-- Recalculate where the existing value is NULL or wrong.

UPDATE dbo.sales_cleaned
SET total_amount = ROUND(price * quantity, 2)
WHERE
    total_amount IS NULL
    OR ABS(total_amount - (price * quantity)) > 0.05;   -- tolerance for rounding

-- Check
SELECT TOP 10
    transaction_id, price, quantity,
    total_amount,
    ROUND(price * quantity, 2) AS expected_total
FROM dbo.sales_cleaned
WHERE ABS(total_amount - ROUND(price * quantity, 2)) > 0.05;


-- ============================================================
-- STEP 6 : HANDLE NULL / MISSING CRITICAL VALUES
-- ============================================================

-- 6a. Rows with NULL transaction_id or purchase_date are unresolvable – remove them
DELETE FROM dbo.sales_cleaned
WHERE transaction_id IS NULL OR purchase_date IS NULL;

-- 6b. NULL category – assign 'Unknown'
UPDATE dbo.sales_cleaned
SET category = 'Unknown'
WHERE category IS NULL;

-- 6c. NULL payment_method – assign 'Unknown'
UPDATE dbo.sales_cleaned
SET payment_method = 'Unknown'
WHERE payment_method IS NULL;

-- 6d. NULL delivery_status – assign 'Unknown'
UPDATE dbo.sales_cleaned
SET delivery_status = 'Unknown'
WHERE delivery_status IS NULL;

-- 6e. NULL price where total and quantity are known – back-calculate
UPDATE dbo.sales_cleaned
SET price = ROUND(total_amount / NULLIF(quantity, 0), 2)
WHERE price IS NULL AND total_amount IS NOT NULL AND quantity IS NOT NULL AND quantity <> 0;

-- 6f. Zero quantity rows with no meaningful data – remove
DELETE FROM dbo.sales_cleaned
WHERE quantity = 0 AND total_amount = 0;


-- ============================================================
-- STEP 7 : STANDARDISE TEXT FIELDS
-- ============================================================

-- 7a. Trim & title-case customer_name (SSMS doesn't have a built-in
--     INITCAP, so we use UPPER on first char + LOWER for the rest
--     for single-word names; for full names use a scalar UDF or
--     just ensure there is no leading/trailing whitespace).
UPDATE dbo.sales_cleaned
SET customer_name = LTRIM(RTRIM(customer_name));

-- 7b. Lowercase all emails
UPDATE dbo.sales_cleaned
SET email = LOWER(LTRIM(RTRIM(email)));

-- 7c. Trim address
UPDATE dbo.sales_cleaned
SET customer_address = LTRIM(RTRIM(customer_address));


-- ============================================================
-- STEP 8 : VALIDATE DATE RANGE
-- ============================================================
-- Flag or remove dates in the future (beyond today) or implausible past.

SELECT transaction_id, purchase_date
FROM dbo.sales_cleaned
WHERE purchase_date > CAST(GETDATE() AS DATE)
   OR purchase_date < '2000-01-01';

-- Optional: remove future-dated rows
-- DELETE FROM dbo.sales_cleaned WHERE purchase_date > CAST(GETDATE() AS DATE);


-- ============================================================
-- STEP 9 : ADD CONSTRAINTS & INDEXES ON CLEANED TABLE
-- ============================================================

-- Primary Key
ALTER TABLE dbo.sales_cleaned
ADD CONSTRAINT PK_sales_cleaned PRIMARY KEY (transaction_id);

-- Index on customer_id for faster lookups
CREATE INDEX IX_sales_cleaned_customer ON dbo.sales_cleaned (customer_id);

-- Index on purchase_date for time-series queries
CREATE INDEX IX_sales_cleaned_date ON dbo.sales_cleaned (purchase_date);


-- ============================================================
-- STEP 10 : FINAL QUALITY CHECK
-- ============================================================

-- 10a. Row counts comparison
SELECT
    (SELECT COUNT(*) FROM dbo.sales_raw)     AS raw_rows,
    (SELECT COUNT(*) FROM dbo.sales_cleaned) AS cleaned_rows;

-- 10b. Remaining NULLs in key columns
SELECT
    SUM(CASE WHEN customer_name    IS NULL THEN 1 ELSE 0 END) AS null_names,
    SUM(CASE WHEN email            IS NULL THEN 1 ELSE 0 END) AS null_emails,
    SUM(CASE WHEN category         IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN payment_method   IS NULL THEN 1 ELSE 0 END) AS null_payment,
    SUM(CASE WHEN delivery_status  IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN price            IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN total_amount     IS NULL THEN 1 ELSE 0 END) AS null_total
FROM dbo.sales_cleaned;

-- 10c. Distribution check
SELECT category, COUNT(*) AS cnt, ROUND(AVG(price),2) AS avg_price
FROM dbo.sales_cleaned
GROUP BY category ORDER BY cnt DESC;

SELECT payment_method, COUNT(*) AS cnt
FROM dbo.sales_cleaned
GROUP BY payment_method ORDER BY cnt DESC;

SELECT delivery_status, COUNT(*) AS cnt
FROM dbo.sales_cleaned
GROUP BY delivery_status ORDER BY cnt DESC;

-- 10d. Final clean preview
SELECT TOP 20 * FROM dbo.sales_cleaned ORDER BY purchase_date;

PRINT 'Data Cleaning Complete!';
GO
