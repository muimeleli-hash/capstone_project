WITH max_ref AS (
    SELECT MAX(event_timestamp) AS max_time FROM dwh.fct_activity
)
SELECT
    c.client_number,
    c.first_name,
    c.last_name,
    c.province,
    COUNT(f.activity_key) AS total_transactions_12m,
    SUM(f.amount) AS total_transaction_value_12m
FROM dwh.fct_activity f
JOIN dwh.dim_customer c ON f.customer_key = c.customer_key
CROSS JOIN max_ref m
WHERE f.event_timestamp >= (m.max_time - INTERVAL '12 months')
  AND f.amount > 0
GROUP BY c.client_number, c.first_name, c.last_name, c.province
ORDER BY total_transaction_value_12m DESC
LIMIT 20;