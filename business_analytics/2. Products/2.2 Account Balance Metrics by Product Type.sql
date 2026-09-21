SELECT 
    product_type,
    COUNT(account_key) AS total_accounts,
    SUM(account_balance) AS total_balance,
    ROUND(AVG(account_balance), 2) AS average_balance,
    MIN(account_balance) AS min_balance,
    MAX(account_balance) AS max_balance
FROM dwh.dim_account
GROUP BY product_type
ORDER BY total_balance DESC;