-- Part A: Customers per product type
SELECT
    COALESCE(product_type, 'Unassigned') AS product_type,
    COUNT(DISTINCT client_number) AS customer_count
FROM dwh.dim_account
GROUP BY product_type
ORDER BY customer_count DESC;

-- Part B: Cross-holding count (Hold > 1 product)
WITH client_product_depth AS (
    SELECT
        client_number,
        COUNT(DISTINCT product_type) AS distinct_products_held
    FROM dwh.dim_account
    GROUP BY client_number
)
SELECT
    COUNT(CASE WHEN distinct_products_held > 1 THEN 1 END) AS cross_holding_customers,
    COUNT(*) AS total_customers_with_accounts,
    ROUND(
        100.0 * COUNT(CASE WHEN distinct_products_held > 1 THEN 1 END) / COUNT(*),
        2
    ) AS cross_holding_rate_pct
FROM client_product_depth;