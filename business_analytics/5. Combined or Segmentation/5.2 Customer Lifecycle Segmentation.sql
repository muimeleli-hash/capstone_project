WITH max_ref AS (
    SELECT MAX(event_timestamp) AS max_date FROM dwh.fct_activity
),
customer_summary AS (
    SELECT 
        c.customer_key,
        c.signup_date,
        MAX(f.event_timestamp) AS last_activity,
        (SELECT max_date FROM max_ref) AS ref_date
    FROM dwh.dim_customer c
    LEFT JOIN dwh.fct_activity f ON c.customer_key = f.customer_key
    GROUP BY c.customer_key, c.signup_date
)
SELECT 
    CASE 
        WHEN signup_date >= (ref_date - INTERVAL '90 days') THEN '1. New'
        WHEN last_activity >= (ref_date - INTERVAL '60 days') THEN '2. Active'
        WHEN last_activity >= (ref_date - INTERVAL '180 days') THEN '3. At Risk'
        ELSE '4. Dormant'
    END AS lifecycle_segment,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct
FROM customer_summary
GROUP BY 1
ORDER BY 1;