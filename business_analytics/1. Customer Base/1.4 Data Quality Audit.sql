SELECT
    'Missing Email & Mobile' AS issue_type,
    COUNT(*) AS problem_count
FROM dwh.dim_customer
WHERE (email IS NULL OR TRIM(email) = '')
  AND (mobile_number IS NULL OR TRIM(mobile_number) = '')

UNION ALL

SELECT
    'Invalid Email Format' AS issue_type,
    COUNT(*) AS problem_count
FROM dwh.dim_customer
WHERE email IS NOT NULL
  AND email NOT LIKE '%@%.%'

UNION ALL

SELECT
    'Unrealistic Age (<16 or >105)' AS issue_type,
    COUNT(*) AS problem_count
FROM dwh.dim_customer
WHERE date_of_birth IS NULL
   OR DATE_PART('year', AGE(CURRENT_DATE, date_of_birth)) < 16
   OR DATE_PART('year', AGE(CURRENT_DATE, date_of_birth)) > 105

UNION ALL

SELECT
    'Duplicate Client Numbers' AS issue_type,
    COUNT(*) AS problem_count
FROM (
    SELECT client_number
    FROM dwh.dim_customer
    GROUP BY client_number
    HAVING COUNT(*) > 1
) sub;