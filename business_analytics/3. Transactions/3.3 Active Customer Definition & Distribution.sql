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
        WHEN la.last_activity_date >= ref.ref_date - INTERVAL '90 days'
            THEN 'Active'
        ELSE 'Not Active'
    END AS status,
    COUNT(*) AS customer_count
FROM dwh.dim_customer c
LEFT JOIN last_activity la ON la.customer_key = c.customer_key
CROSS JOIN ref
GROUP BY status;