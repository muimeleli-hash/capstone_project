WITH ref AS (
    SELECT MAX(event_date) AS ref_date
    FROM dwh.fct_activity
    WHERE transaction_type_key IS NOT NULL
)
SELECT
    c.client_number,
    c.full_name,
    SUM(f.amount) AS total_txn_value
FROM dwh.fct_activity f
JOIN dwh.dim_customer c ON c.customer_key = f.customer_key
CROSS JOIN ref
WHERE f.transaction_type_key IS NOT NULL
  AND f.event_date >= ref.ref_date - INTERVAL '12 months'
GROUP BY c.client_number, c.full_name
ORDER BY total_txn_value DESC
LIMIT 20;