WITH monthly_activity AS (
    SELECT DISTINCT
        customer_key,
        DATE_TRUNC('month', event_date)::date AS activity_month
    FROM dwh.fct_activity
    WHERE event_date IS NOT NULL
)
SELECT
    a.activity_month AS month_n,
    COUNT(DISTINCT a.customer_key) AS active_in_month_n,
    COUNT(DISTINCT b.customer_key) AS retained_in_month_n_plus_1,
    ROUND(
        100.0 * COUNT(DISTINCT b.customer_key) / COUNT(DISTINCT a.customer_key), 2
    ) AS retention_pct
FROM monthly_activity a
LEFT JOIN monthly_activity b
    ON b.customer_key = a.customer_key
   AND b.activity_month = a.activity_month + INTERVAL '1 month'
GROUP BY a.activity_month
ORDER BY a.activity_month;