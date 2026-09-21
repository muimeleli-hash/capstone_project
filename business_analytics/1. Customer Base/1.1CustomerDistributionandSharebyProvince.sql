SELECT 
    COALESCE(province, 'Unknown') AS province,
    COUNT(customer_key) AS customer_count,
    ROUND(
        100.0 * COUNT(customer_key) / SUM(COUNT(customer_key)) OVER (), 
        2
    ) AS percentage_share
FROM dwh.dim_customer
GROUP BY COALESCE(province, 'Unknown')
ORDER BY customer_count DESC;