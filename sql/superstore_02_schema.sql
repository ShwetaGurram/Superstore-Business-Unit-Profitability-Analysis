-- Creating star schema tables

--DIM_DATE 
CREATE TABLE dim_date AS
WITH date_range AS (
    SELECT generate_series(
        (SELECT MIN(TO_DATE(order_date, 'MM/DD/YYYY')) FROM data_raw),
        (SELECT MAX(TO_DATE(ship_date,  'MM/DD/YYYY')) FROM data_raw),
        '1 day'::interval
    )::date AS date
)
SELECT
    date,
    EXTRACT(YEAR    FROM date)::INTEGER          AS year,
    EXTRACT(MONTH   FROM date)::INTEGER          AS month_num,
    TO_CHAR(date, 'Mon')                         AS month_name,
    TO_CHAR(date, 'Month')                       AS month_full_name,
    'Q' || EXTRACT(QUARTER FROM date)::TEXT      AS quarter,
    EXTRACT(QUARTER FROM date)::INTEGER          AS quarter_num,
    EXTRACT(DOW     FROM date)::INTEGER          AS day_of_week_num,
    TO_CHAR(date, 'Day')                         AS day_of_week_name,
    EXTRACT(DAY     FROM date)::INTEGER          AS day_of_month,
    CASE WHEN EXTRACT(DOW FROM date) IN (0,6)
         THEN TRUE ELSE FALSE END                AS is_weekend,
    TO_CHAR(date, 'YYYY-MM')                     AS year_month
FROM date_range
ORDER BY date;

ALTER TABLE dim_date ADD PRIMARY KEY (date);
 
SELECT COUNT(*) AS total_dates FROM dim_date;
SELECT MIN(date) AS earliest, MAX(date) AS latest FROM dim_date;


-- dim_customer
CREATE TABLE dim_customer AS
SELECT DISTINCT
    customer_id,
    customer_name,
    segment
FROM data_raw;
 
ALTER TABLE dim_customer ADD PRIMARY KEY (customer_id);
 
-- Verify uniqueness
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS unique_ids
FROM dim_customer; 


-- dim_product
CREATE TABLE dim_product AS
SELECT DISTINCT ON (product_id)
    product_id,
    product_name,
    category,
    sub_category
FROM data_raw
ORDER BY product_id;
 
ALTER TABLE dim_product ADD PRIMARY KEY (product_id);
 
-- Verify uniqueness
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT product_id) AS unique_ids
FROM dim_product;   


-- dim_region
CREATE TABLE dim_region AS
SELECT DISTINCT
    city || '-' || state || '-' || postal_code  AS region_id,
    country,
    region,
    state,
    city,
    postal_code
FROM data_raw;
 
ALTER TABLE dim_region ADD PRIMARY KEY (region_id);
 
-- Verify uniqueness
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT region_id) AS unique_ids
FROM dim_region;  


-- fact_sales (clean, typed, with derived columns)
CREATE TABLE fact_sales AS
SELECT
    order_id,
    TO_DATE(order_date, 'MM/DD/YYYY') AS order_date,
    TO_DATE(ship_date,  'MM/DD/YYYY') AS ship_date,
    ship_mode,
    customer_id,
    product_id,
    city || '-' || state || '-' || postal_code AS region_id,
    sales,
    quantity,
    discount,
    profit,
 
    -- derived columns
    ROUND(profit / NULLIF(sales, 0) * 100, 2) AS profit_margin_pct,
    (TO_DATE(ship_date,  'MM/DD/YYYY')
   - TO_DATE(order_date, 'MM/DD/YYYY')) AS ship_days,
    CASE
        WHEN discount = 0      THEN 'No Discount'
        WHEN discount <= 0.10  THEN '1-10%'
        WHEN discount <= 0.20  THEN '11-20%'
        ELSE '20%+'
    END AS discount_band
 
FROM data_raw;

-- Surrogate primary key — handles the case where the same
-- product/order/customer combination legitimately repeats
-- with different sales/quantity/profit (multiple line items)
ALTER TABLE fact_sales ADD COLUMN fact_id SERIAL PRIMARY KEY;
 
SELECT COUNT(*) AS total_fact_rows FROM fact_sales;  