WITH anchor_date AS (
    SELECT MAX(event_timestamp) AS max_timestamp FROM dwh.fct_activity
),
customer_recency AS (
    SELECT
        c.customer_key,
        MAX(f.event_timestamp) AS last_activity_time
    FROM dwh.dim_customer c
    LEFT JOIN dwh.fct_activity f ON c.customer_key = f.customer_key
    GROUP BY c.customer_key
)
SELECT
    CASE
        WHEN cr.last_activity_time >= (a.max_timestamp - INTERVAL '90 days') THEN 'Active (<= 90 days)'
        ELSE 'Inactive / Dormant (> 90 days)'
    END AS customer_status,
    COUNT(cr.customer_key) AS customer_count,
    ROUND(100.0 * COUNT(cr.customer_key) / SUM(COUNT(cr.customer_key)) OVER (), 2) AS share_pct
FROM customer_recency cr
CROSS JOIN anchor_date a
GROUP BY 1;