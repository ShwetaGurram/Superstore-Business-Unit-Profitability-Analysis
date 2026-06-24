-- NULL CHECKS

-- Check nulls in every critical column of fact_sales
SELECT
    COUNT(*)                                           AS total_rows,
    COUNT(*) FILTER (WHERE order_id       IS NULL)     AS null_order_id,
    COUNT(*) FILTER (WHERE customer_id    IS NULL)     AS null_customer_id,
    COUNT(*) FILTER (WHERE product_id     IS NULL)     AS null_product_id,
    COUNT(*) FILTER (WHERE order_date     IS NULL)     AS null_order_date,
    COUNT(*) FILTER (WHERE ship_date      IS NULL)     AS null_ship_date,
    COUNT(*) FILTER (WHERE sales          IS NULL)     AS null_sales,
    COUNT(*) FILTER (WHERE quantity       IS NULL)     AS null_quantity,
    COUNT(*) FILTER (WHERE discount       IS NULL)     AS null_discount,
    COUNT(*) FILTER (WHERE profit         IS NULL)     AS null_profit,
    COUNT(*) FILTER (WHERE region_id      IS NULL)     AS null_region_id,
    COUNT(*) FILTER (WHERE discount_band  IS NULL)     AS null_discount_band
FROM fact_sales;

-- Check nulls in dim_customer
SELECT
    COUNT(*)                                           AS total_rows,
    COUNT(*) FILTER (WHERE customer_id   IS NULL)      AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_name IS NULL)      AS null_customer_name,
    COUNT(*) FILTER (WHERE segment       IS NULL)      AS null_segment
FROM dim_customer;

-- Check nulls in dim_product
SELECT
    COUNT(*)                                           AS total_rows,
    COUNT(*) FILTER (WHERE product_id    IS NULL)      AS null_product_id,
    COUNT(*) FILTER (WHERE product_name  IS NULL)      AS null_product_name,
    COUNT(*) FILTER (WHERE category      IS NULL)      AS null_category,
    COUNT(*) FILTER (WHERE sub_category  IS NULL)      AS null_sub_category
FROM dim_product;

-- Check nulls in dim_region
SELECT
    COUNT(*)                                            AS total_rows,
    COUNT(*) FILTER (WHERE region        IS NULL)      AS null_region,
    COUNT(*) FILTER (WHERE state         IS NULL)      AS null_state,
    COUNT(*) FILTER (WHERE city          IS NULL)      AS null_city,
    COUNT(*) FILTER (WHERE postal_code   IS NULL)      AS null_postal_code
FROM dim_region;



-- DUPLICATE CHECKS

-- Duplicate customer_id in dim_customer (expected: 0 rows)
SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- Duplicate product_id in dim_product (expected: 0 rows)
SELECT
    product_id,
    COUNT(*) AS occurrences
FROM dim_product
GROUP BY product_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- Duplicate fact_id in fact_sales (expected: 0 rows)
SELECT
    fact_id,
    COUNT(*) AS occurrences
FROM fact_sales
GROUP BY fact_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- Identical rows in fact_sales (same order, product, customer,
--     sales, quantity — true business duplicates)
SELECT
    order_id,
    product_id,
    customer_id,
    sales,
    quantity,
    profit,
    COUNT(*) AS occurrences
FROM fact_sales
GROUP BY order_id, product_id, customer_id, sales, quantity, profit
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;


-- See both rows with their fact_id
SELECT 
    fact_id,
    order_id,
    product_id,
    customer_id,
    sales,
    quantity,
    profit,
    order_date,
    ship_date,
    ship_mode
FROM fact_sales
WHERE order_id    = 'US-2014-150119'
  AND product_id  = 'FUR-CH-10002965'
  AND customer_id = 'LB-16795';


DELETE FROM fact_sales
WHERE fact_id = (
    SELECT MAX(fact_id)
    FROM fact_sales
    WHERE fact_id = 3410
);


SELECT COUNT(*) 
FROM fact_sales;


WITH resequenced AS (
    SELECT 
        fact_id AS old_fact_id,
        ROW_NUMBER() OVER (
		ORDER BY fact_id
		) AS new_fact_id
    FROM fact_sales
)
UPDATE fact_sales f
SET fact_id = r.new_fact_id
FROM resequenced r
WHERE f.fact_id = r.old_fact_id;


SELECT 
    MIN(fact_id) AS starts_at,                                  
    MAX(fact_id) AS ends_at,                                    
    COUNT(*) AS total_rows,                                     
    MAX(fact_id) - MIN(fact_id) + 1 - COUNT(*) AS gaps          
FROM fact_sales;



-- RANGE & BUSINESS LOGIC CHECKS

-- Sales must be greater than zero
SELECT
    'Zero or negative sales' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales
WHERE sales <= 0

UNION ALL

-- Quantity must be greater than zero
SELECT
    'Zero or negative quantity' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales
WHERE quantity <= 0

UNION ALL

-- Discount must be between 0 and 1 (0% to 100%)
SELECT
    'Discount out of range' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales
WHERE discount < 0 OR discount > 1

UNION ALL

-- Ship date must not be before order date
SELECT
    'Ship date before order date' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales
WHERE ship_date < order_date

UNION ALL

-- Ship days must not be negative
SELECT
    'Negative ship days' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales
WHERE ship_days < 0

UNION ALL

-- Profit margin extremes (below -100% or above 100% are suspicious)
SELECT
    'Extreme profit margin' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales
WHERE profit_margin_pct < -100 
   OR profit_margin_pct > 100;


-- Breakdown of extreme margins
SELECT
    MIN(profit_margin_pct) AS lowest_margin,
    MAX(profit_margin_pct) AS highest_margin,
    AVG(profit_margin_pct) AS avg_margin,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER 
        (WHERE profit_margin_pct < -100) AS below_minus_100,
    COUNT(*) FILTER 
        (WHERE profit_margin_pct > 100) AS above_100
FROM fact_sales
WHERE profit_margin_pct < -100 
   OR profit_margin_pct > 100;


-- See the extreme rows in detail
SELECT
    fact_id,
    order_id,
    category,
    sub_category,
    sales,
    quantity,
    discount,
    profit,
    profit_margin_pct,
    discount_band
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
WHERE profit_margin_pct < -100
   OR profit_margin_pct > 100
ORDER BY profit_margin_pct ASC;
-- LIMIT 20;



-- REFERENTIAL INTEGRITY CHECKS

-- Orphaned customer_id in fact_sales
--     (fact rows with no matching dim_customer record)
SELECT
    'Orphaned customer_id' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales f
LEFT JOIN dim_customer c 
		ON f.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Orphaned product_id in fact_sales
SELECT
    'Orphaned product_id' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales f
LEFT JOIN dim_product p 
		ON f.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Orphaned region_id in fact_sales
SELECT
    'Orphaned region_id' AS issue,
    COUNT(*) AS affected_rows
FROM fact_sales f
LEFT JOIN dim_region r 
       ON f.region_id = CONCAT(r.city, '-', r.state)
WHERE r.city IS NULL;



-- DERIVED COLUMN VALIDATION

-- Validate profit_margin_pct matches manual calculation
--     (tolerance: 0.01 to allow for rounding differences)
SELECT
    COUNT(*) AS mismatch_count
FROM fact_sales
WHERE ABS(profit_margin_pct - ROUND(profit / NULLIF(sales, 0) * 100, 2)) > 0.01;

-- Validate ship_days matches date difference
SELECT
    COUNT(*) AS mismatch_count
FROM fact_sales
WHERE ship_days != (ship_date - order_date);

-- Validate discount_band logic
SELECT
    COUNT(*) AS mismatch_count
FROM fact_sales
WHERE discount_band != 
    CASE
        WHEN discount = 0      THEN 'No Discount'
        WHEN discount <= 0.10  THEN '1-10%'
        WHEN discount <= 0.20  THEN '11-20%'
        ELSE '20%+'
    END;

-- Validate year extracted correctly
SELECT
    COUNT(*) AS mismatch_count
FROM fact_sales
WHERE year != EXTRACT(YEAR FROM order_date)::INTEGER;

-- Check all 4 discount bands are present
SELECT
    discount_band,
    COUNT(*) AS row_count
FROM fact_sales
GROUP BY discount_band
ORDER BY discount_band;

-- Check all expected segments exist in dim_customer
--     (expected: Consumer, Corporate, Home Office)
SELECT
    segment,
    COUNT(*) AS customer_count
FROM dim_customer
GROUP BY segment
ORDER BY segment;

-- Check all expected categories exist in dim_product
--     (expected: Furniture, Office Supplies, Technology)
SELECT
    category,
    COUNT(*) AS product_count
FROM dim_product
GROUP BY category
ORDER BY category;

-- Check all expected regions exist in dim_region
--     (expected: Central, East, South, West)
SELECT
    region,
    COUNT(*) AS location_count
FROM dim_region
GROUP BY region
ORDER BY region;



-- Overall data health
-- All counts should be 0 for a clean dataset

SELECT issue, affected_rows,
    CASE 
        WHEN affected_rows = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM (

    SELECT 'Null sales' AS issue,
        COUNT(*) FILTER (WHERE sales IS NULL) AS affected_rows
    FROM fact_sales

    UNION ALL SELECT 'Null profit',
        COUNT(*) FILTER (WHERE profit IS NULL)
    FROM fact_sales

    UNION ALL SELECT 'Null order_date',
        COUNT(*) FILTER (WHERE order_date IS NULL)
    FROM fact_sales

    UNION ALL SELECT 'Zero or negative sales',
        COUNT(*) FROM fact_sales WHERE sales <= 0

    UNION ALL SELECT 'Discount out of range',
        COUNT(*) FROM fact_sales
        WHERE discount < 0 OR discount > 1

    UNION ALL SELECT 'Ship date before order date',
        COUNT(*) FROM fact_sales WHERE ship_date < order_date

    UNION ALL SELECT 'Orphaned customer_id',
        COUNT(*) FROM fact_sales f
        LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
        WHERE c.customer_id IS NULL

    UNION ALL SELECT 'Orphaned product_id',
        COUNT(*) FROM fact_sales f
        LEFT JOIN dim_product p ON f.product_id = p.product_id
        WHERE p.product_id IS NULL

    UNION ALL SELECT 'Duplicate customer_id in dim_customer',
        COUNT(*) FROM (
            SELECT customer_id FROM dim_customer
            GROUP BY customer_id HAVING COUNT(*) > 1
        ) d

    UNION ALL SELECT 'Duplicate product_id in dim_product',
        COUNT(*) FROM (
            SELECT product_id FROM dim_product
            GROUP BY product_id HAVING COUNT(*) > 1
        ) d

) quality_report
ORDER BY status DESC, issue;