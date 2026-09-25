SELECT
    c.channel_name,
    COUNT(f.activity_key) AS total_logged_cases,
    COUNT(*) FILTER (WHERE f.resolved_flag) AS resolved_cases,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.resolved_flag)
        / NULLIF(COUNT(f.activity_key), 0),
        2
    ) AS resolution_rate_pct
FROM dwh.fct_activity f
JOIN dwh.dim_channel c ON f.channel_key = c.channel_key
WHERE f.resolved_flag IS NOT NULL
GROUP BY c.channel_name
ORDER BY resolution_rate_pct ASC;