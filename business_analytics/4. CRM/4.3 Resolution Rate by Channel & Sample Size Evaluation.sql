SELECT
    c.channel,
    COUNT(f.activity_key) AS total_logged_cases,
    COUNT(CASE WHEN UPPER(TRIM(f.resolved_flag)) IN ('Y', 'YES', '1', 'TRUE') THEN 1 END) AS resolved_cases,
    ROUND(
        100.0 * COUNT(CASE WHEN UPPER(TRIM(f.resolved_flag)) IN ('Y', 'YES', '1', 'TRUE') THEN 1 END)
        / NULLIF(COUNT(f.activity_key), 0),
        2
    ) AS resolution_rate_pct
FROM dwh.fct_activity f
JOIN dwh.dim_channel c ON f.channel_key = c.channel_key
WHERE f.resolved_flag IS NOT NULL
GROUP BY c.channel
ORDER BY resolution_rate_pct ASC;