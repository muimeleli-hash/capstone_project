WITH account_stats AS (
    SELECT
        account_key,
        AVG(amount) AS mean_amount,
        STDDEV(amount) AS std_amount,
        COUNT(*) AS transaction_count
    FROM dwh.fct_activity
    WHERE amount > 0
    GROUP BY account_key
    HAVING COUNT(*) >= 10 AND STDDEV(amount) > 0
),
flagged_tx AS (
    SELECT
        f.activity_key,
        f.account_key,
        f.event_timestamp,
        f.amount,
        ROUND(s.mean_amount, 2) AS historical_mean,
        ROUND((f.amount - s.mean_amount) / s.std_amount, 2) AS z_score
    FROM dwh.fct_activity f
    JOIN account_stats s ON f.account_key = s.account_key
    WHERE (f.amount - s.mean_amount) / s.std_amount > 3.0
)
SELECT
    ft.activity_key,
    a.account_number,
    ft.event_timestamp,
    ft.amount,
    ft.historical_mean,
    ft.z_score
FROM flagged_tx ft
JOIN dwh.dim_account a ON ft.account_key = a.account_key
ORDER BY ft.z_score DESC
LIMIT 25;