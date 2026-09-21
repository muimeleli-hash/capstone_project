SELECT 
    d.year,
    d.month,
    d.month_name,
    t.transaction_type,
    COUNT(f.activity_key) AS total_transactions,
    SUM(f.amount) AS total_value
FROM dwh.fct_activity f
JOIN dwh.dim_date d ON f.date_key = d.date_key
JOIN dwh.dim_transaction_type t ON f.transaction_type_key = t.transaction_type_key
WHERE f.amount > 0
GROUP BY d.year, d.month, d.month_name, t.transaction_type
ORDER BY d.year, d.month, t.transaction_type;