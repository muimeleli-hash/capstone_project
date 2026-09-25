SELECT
    ch.channel_name,
    COUNT(*) AS txn_count,
    SUM(f.amount) AS total_value,
    ROUND(AVG(f.amount), 2) AS avg_txn_value
FROM dwh.fct_activity f
JOIN dwh.dim_channel ch ON ch.channel_key = f.channel_key
WHERE f.transaction_type_key IS NOT NULL
GROUP BY ch.channel_name
ORDER BY total_value DESC;