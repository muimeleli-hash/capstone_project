SELECT
    ch.channel_name,
    COUNT(*) FILTER (WHERE e.interaction_type ILIKE '%complain%') AS complaints,
    COUNT(*) FILTER (WHERE e.interaction_type NOT ILIKE '%complain%') AS other_interactions
FROM dwh.fct_activity f
JOIN dwh.dim_channel ch ON ch.channel_key = f.channel_key
JOIN dwh.dim_event e ON e.event_key = f.event_key
WHERE e.interaction_type IS NOT NULL
GROUP BY ch.channel_name
ORDER BY complaints DESC;