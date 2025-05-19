-- Query to calculate Customer Lifetime Value (CLV) Estimation

SET @current_date = curdate(); -- Set reference "current date" as per user instruction

-- Note:
-- 1. "Total transactions" is interpreted as the total number of savings accounts a customer owns.
-- 2. "Total transaction value" (used for profit calculation) is interpreted as the sum of
--    the 'initial_deposit' amounts from these savings accounts.

-- CTE for customer information and tenure in months
WITH customer_tenure AS (
    SELECT
        uc.id AS customer_id,                                     -- this serves as the customer id
        CONCAT(uc.first_name, ' ', uc.last_name) AS name,         -- concatenates first and last name to get a users fullname 
        -- Calculate tenure in months from date_joined to @current_date
        -- GREATEST(1, ...) ensures tenure is at least 1 month for the CLV formula
        -- users_customuser.date_joined is NOT NULL
        GREATEST(1, TIMESTAMPDIFF(MONTH, uc.date_joined, @current_date)) AS tenure_months
    FROM
        users_customuser uc
    WHERE
        uc.date_joined <= @current_date -- Consider only users who have joined by the @current_date
),

-- CTE to aggregate transaction data from savings_savingsaccount
account_aggregates AS (
    SELECT
        sa.owner_id,                                      -- this serves as the owner of the account
        COUNT(sa.savings_id) AS total_transactions,       -- Each account is one "transaction" 
        SUM(COALESCE(sa.confirmed_amount, 0)) AS total_transaction_value -- Sum of initial_deposit
    FROM
        savings_savingsaccount sa
    GROUP BY
        sa.owner_id
)

-- Final SELECT to calculate the simplified CLV and present the results
SELECT
    ct.customer_id,
    ct.name,
    ct.tenure_months,
    COALESCE(aa.total_transactions, 0) AS total_transactions, -- This is the count of savings accounts
    -- Estimated CLV calculation using the simplified formula with:
    -- (Total_Transaction_Value * 0.1% profit margin * 12 months/year) / Tenure in Months
    -- COALESCE handles users with no accounts/initial deposits (CLV will be 0)
    -- ct.tenure_months is guaranteed to be at least 1
    (COALESCE(aa.total_transaction_value, 0) * 0.001 * 12) / ct.tenure_months AS estimated_clv
FROM
    customer_tenure ct
LEFT JOIN 
    account_aggregates aa ON ct.customer_id = aa.owner_id
ORDER BY
    estimated_clv DESC