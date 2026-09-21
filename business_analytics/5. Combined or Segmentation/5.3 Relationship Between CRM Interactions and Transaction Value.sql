WITH customer_aggregates AS (
    SELECT 
        c.customer_key,
        COUNT(CASE WHEN e.interaction_type IS NOT NULL THEN f.activity_key END) AS total_interactions,
        COALESCE(SUM(f.amount), 0) AS total_transaction_value
    FROM dwh.dim_customer c
    LEFT JOIN dwh.fct_activity f ON c.customer_key = f.customer_key
    LEFT JOIN dwh.dim_event e ON f.event_key = e.event_key
    GROUP BY c.customer_key
)
SELECT 
    CASE 
        WHEN total_interactions = 0 THEN '0 interactions'
        WHEN total_interactions BETWEEN 1 AND 2 THEN '1-2 interactions'
        WHEN total_interactions BETWEEN 3 AND 5 THEN '3-5 interactions'
        WHEN total_interactions BETWEEN 6 AND 10 THEN '6-10 interactions'
        ELSE '11+ interactions'
    END AS interaction_bracket,
    COUNT(customer_key) AS customer_count,
    ROUND(AVG(total_transaction_value), 2) AS avg_transaction_value,
    ROUND(AVG(total_interactions), 2) AS avg_interactions
FROM customer_aggregates
GROUP BY 1
ORDER BY MIN(total_interactions);