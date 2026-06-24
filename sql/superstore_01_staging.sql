-- Creating data_raw table (raw import — exact CSV columns)
CREATE TABLE data_raw (
    row_id          INTEGER,
    order_id        VARCHAR(20),
    order_date      VARCHAR(20),
    ship_date       VARCHAR(20),
    ship_mode       VARCHAR(50),
    customer_id     VARCHAR(20),
    customer_name   VARCHAR(100),
    segment         VARCHAR(50),
    country         VARCHAR(50),
    city            VARCHAR(100),
    state           VARCHAR(100),
    postal_code     VARCHAR(10),
    region          VARCHAR(20),
    product_id      VARCHAR(20),
    category        VARCHAR(50),
    sub_category    VARCHAR(50),
    product_name    VARCHAR(200),
    sales           NUMERIC(10,2),
    quantity        INTEGER,
    discount        NUMERIC(5,4),
    profit          NUMERIC(10,2)
);


-- Import CSV into data_raw table
COPY data_raw
FROM 'D:\superstore-business-unit-profitability\Superstore_dataset.csv'
DELIMITER ','
CSV HEADER
ENCODING 'WIN1252';


DELETE FROM data_raw
WHERE order_date LIKE '%/2014' 
   OR order_date LIKE '%/2018';

   
-- Verifying import data_raw table
SELECT *
FROM data_raw;

SELECT DISTINCT EXTRACT(YEAR FROM TO_DATE(order_date, 'MM/DD/YYYY')) AS order_year
FROM data_raw;


SELECT 
	COUNT(row_id) AS total_rows
FROM data_raw;


SELECT 
	COUNT(*) 
FROM data_raw
WHERE sales IS NULL OR profit IS NULL;
