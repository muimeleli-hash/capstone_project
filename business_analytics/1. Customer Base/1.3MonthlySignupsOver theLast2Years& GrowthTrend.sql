WITH ref AS (
    SELECT MAX(signup_date) AS max_signup FROM dwh.dim_customer
),
monthly AS (
    SELECT
        DATE_TRUNC('month', c.signup_date)::date AS signup_month,
        COUNT(*) AS signups
    FROM dwh.dim_customer c, ref
    WHERE c.signup_date >= ref.max_signup - INTERVAL '24 months'
    GROUP BY signup_month
)
SELECT * FROM monthly ORDER BY signup_month;