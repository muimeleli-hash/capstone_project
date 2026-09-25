-- count for the cross-sell target list
SELECT COUNT(DISTINCT client_number) AS savings_no_cc_customers
FROM dwh.dim_account
WHERE product_type = 'Savings'
  AND client_number NOT IN (
      SELECT client_number FROM dwh.dim_account WHERE product_type = 'Credit Card'
  );

-- the actual list, ready to hand to CRM/marketing
SELECT c.client_number, c.full_name, c.email, c.mobile_number
FROM dwh.dim_customer c
WHERE c.client_number IN (
    SELECT client_number FROM dwh.dim_account WHERE product_type = 'Savings'
    EXCEPT
    SELECT client_number FROM dwh.dim_account WHERE product_type = 'Credit Card'
);