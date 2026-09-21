SELECT
    c.channel,
    COUNT(CASE WHEN LOWER(e.interaction_type) = 'complaint' THEN 1 END) AS complaint_count,
    COUNT(CASE WHEN LOWER(e.interaction_type) != 'complaint' OR e.interaction_type IS NULL THEN 1 END) AS other_interaction_count,
    ROUND(
        100.0 * COUNT(CASE WHEN LOWER(e.interaction_type) = 'complaint' THEN 1 END)
        / NULLIF(SUM(COUNT(CASE WHEN LOWER(e.interaction_type) = 'complaint' THEN 1 END)) OVER (), 0),
        2
    ) AS share_of_all_complaints_pct
FROM dwh.fct_activity f
JOIN dwh.dim_channel c ON f.channel_key = c.channel_key
LEFT JOIN dwh.dim_event e ON f.event_key = e.event_key
GROUP BY c.channel
ORDER BY complaint_count DESC;