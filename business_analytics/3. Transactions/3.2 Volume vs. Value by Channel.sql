SELECT
    c.channel,
    COUNT(f.activity_key) AS transaction_count,
    ROUND(100.0 * COUNT(f.activity_key) / SUM(COUNT(f.activity_key)) OVER (), 2) AS volume_share_pct,
    SUM(f.amount) AS total_value,
    ROUND(100.0 * SUM(f.amount) / SUM(SUM(f.amount)) OVER (), 2) AS value_share_pct,
    ROUND(AVG(f.amount), 2) AS avg_transaction_size
FROM dwh.fct_activity f
JOIN dwh.dim_channel c ON f.channel_key = c.channel_key
WHERE f.amount > 0
GROUP BY c.channel
ORDER BY transaction_count DESC;