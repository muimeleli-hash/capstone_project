SELECT
    COUNT(DISTINCT client_number) AS savings_no_credit_card_count
FROM dwh.dim_account
WHERE client_number IN (
    SELECT client_number
    FROM dwh.dim_account
    WHERE LOWER(product_type) LIKE '%saving%'
)
AND client_number NOT IN (
    SELECT client_number
    FROM dwh.dim_account
    WHERE LOWER(product_type) LIKE '%credit%'
);