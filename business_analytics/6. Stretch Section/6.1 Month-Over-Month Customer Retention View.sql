WITH monthly_active_customers AS (
    SELECT DISTINCT
        DATE_TRUNC('month', f.event_timestamp)::DATE AS activity_month,
        f.customer_key
    FROM dwh.fct_activity f
    WHERE f.amount > 0 OR f.event_key IS NOT NULL
),
retention_matrix AS (
    SELECT 
        curr.activity_month AS current_month,
        COUNT(DISTINCT curr.customer_key) AS active_in_month_n,
        COUNT(DISTINCT nxt.customer_key) AS retained_in_month_n_plus_1
    FROM monthly_active_customers curr
    LEFT JOIN monthly_active_customers nxt 
        ON curr.customer_key = nxt.customer_key 
        AND nxt.activity_month = (curr.activity_month + INTERVAL '1 month')::DATE
    GROUP BY curr.activity_month
)
SELECT 
    current_month,
    active_in_month_n,
    retained_in_month_n_plus_1,
    ROUND(
        100.0 * retained_in_month_n_plus_1 / NULLIF(active_in_month_n, 0), 
        2
    ) AS mom_retention_rate_pct
FROM retention_matrix
ORDER BY current_month;