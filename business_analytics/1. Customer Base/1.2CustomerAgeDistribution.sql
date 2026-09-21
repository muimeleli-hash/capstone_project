WITH customer_ages AS (
    SELECT 
        customer_key,
        FLOOR(DATE_PART('year', AGE((SELECT MAX(full_date) FROM dwh.dim_date), date_of_birth))) AS age
    FROM dwh.dim_customer
    WHERE date_of_birth IS NOT NULL
)
SELECT 
    CASE 
        WHEN age < 25 THEN '1. Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '2. 25 - 34'
        WHEN age BETWEEN 35 AND 49 THEN '3. 35 - 49'
        WHEN age BETWEEN 50 AND 64 THEN '4. 50 - 64'
        WHEN age >= 65 THEN '5. 65+'
        ELSE '6. Unknown'
    END AS age_band,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM customer_ages
GROUP BY 1
ORDER BY 1;