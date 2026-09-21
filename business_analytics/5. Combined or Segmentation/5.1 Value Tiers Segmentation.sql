WITH customer_totals AS (
    SELECT 
        c.customer_key,
        COALESCE(SUM(f.amount), 0) AS total_val
    FROM dwh.dim_customer c
    LEFT JOIN dwh.fct_activity f ON c.customer_key = f.customer_key
    GROUP BY c.customer_key
),
ranked_customers AS (
    SELECT 
        customer_key,
        total_val,
        PERCENT_RANK() OVER (ORDER BY total_val) AS p_rank
    FROM customer_totals
)
SELECT 
    CASE 
        WHEN p_rank >= 0.90 THEN 'Tier 1: Top 10% (High Value)'
        WHEN p_rank >= 0.75 THEN 'Tier 2: 75th-89th Percentile'
        WHEN p_rank >= 0.25 THEN 'Tier 3: 25th-74th Percentile'
        ELSE 'Tier 4: Bottom 25%'
    END AS value_tier,
    COUNT(customer_key) AS customer_count,
    ROUND(SUM(total_val), 2) AS total_value,
    ROUND(AVG(total_val), 2) AS avg_value_per_customer
FROM ranked_customers
GROUP BY 1
ORDER BY total_value DESC;