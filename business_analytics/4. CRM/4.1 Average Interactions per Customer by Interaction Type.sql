WITH interaction_counts AS (
    SELECT
        e.interaction_type,
        f.customer_key,
        COUNT(f.activity_key) AS interactions
    FROM dwh.fct_activity f
    JOIN dwh.dim_event e ON f.event_key = e.event_key
    WHERE e.interaction_type IS NOT NULL
    GROUP BY e.interaction_type, f.customer_key
),
total_customers AS (
    SELECT COUNT(*) AS total_cust FROM dwh.dim_customer
)
SELECT
    ic.interaction_type,
    SUM(ic.interactions) AS total_interactions,
    -- Average across entire customer base
    ROUND(SUM(ic.interactions)::NUMERIC / (SELECT total_cust FROM total_customers), 2) AS avg_per_total_customer,
    -- Average across customers with at least one interaction
    ROUND(AVG(ic.interactions), 2) AS avg_per_engaged_customer
FROM interaction_counts ic
GROUP BY ic.interaction_type
ORDER BY total_interactions DESC;