WITH ref AS (
    SELECT MAX(full_date) AS ref_date FROM dwh.dim_date
),
last_activity AS (
    SELECT customer_key, MAX(event_date) AS last_activity_date
    FROM dwh.fct_activity
    WHERE event_date IS NOT NULL
    GROUP BY customer_key
)
SELECT
    CASE
        WHEN c.signup_date >= ref.ref_date - INTERVAL '90 days'
            THEN '1. New'
        WHEN la.last_activity_date >= ref.ref_date - INTERVAL '90 days'
            THEN '2. Active'
        WHEN la.last_activity_date >= ref.ref_date - INTERVAL '180 days'
            THEN '3. At risk'
        ELSE '4. Dormant'
    END AS lifecycle_segment,
    COUNT(*) AS customer_count
FROM dwh.dim_customer c
LEFT JOIN last_activity la ON la.customer_key = c.customer_key
CROSS JOIN ref
GROUP BY lifecycle_segment
ORDER BY lifecycle_segment;