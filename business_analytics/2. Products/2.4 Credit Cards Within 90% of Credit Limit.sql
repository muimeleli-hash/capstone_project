SELECT
    COUNT(*) AS total_credit_cards,
    COUNT(CASE WHEN account_balance >= 0.90 * credit_limit THEN 1 END) AS near_limit_accounts,
    ROUND(
        100.0 * COUNT(CASE WHEN account_balance >= 0.90 * credit_limit THEN 1 END) / NULLIF(COUNT(*), 0),
        2
    ) AS proportion_near_limit_pct
FROM dwh.dim_account
WHERE LOWER(product_type) LIKE '%credit%'
  AND credit_limit > 0;