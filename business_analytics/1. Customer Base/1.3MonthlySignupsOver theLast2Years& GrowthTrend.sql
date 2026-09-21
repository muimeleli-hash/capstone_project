WITH max_date_ref AS (
    SELECT MAX(full_date) AS max_date FROM dwh.dim_date
),
monthly_signups AS (
    SELECT
        DATE_TRUNC('month', c.signup_date)::DATE AS signup_month,
        COUNT(c.customer_key) AS new_signups
    FROM dwh.dim_customer c
    CROSS JOIN max_date_ref m
    WHERE c.signup_date >= (m.max_date - INTERVAL '24 months')
    GROUP BY DATE_TRUNC('month', c.signup_date)::DATE
)
SELECT
    signup_month,
    new_signups,
    LAG(new_signups) OVER (ORDER BY signup_month) AS prev_month_signups,
    ROUND(
        100.0 * (new_signups - LAG(new_signups) OVER (ORDER BY signup_month))
        / NULLIF(LAG(new_signups) OVER (ORDER BY signup_month), 0), 2
    ) AS mom_growth_pct,
    ROUND(AVG(new_signups) OVER (
        ORDER BY signup_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0) AS rolling_3m_avg
FROM monthly_signups
ORDER BY signup_month;