-- Query to analyze for 'transaction frequency'

-- CTE to define each savings account creation as an "event"
WITH account_creation_events AS (
    SELECT
        owner_id,          -- The ID of the user who created the savings account
        id AS account_event_id, -- Using the savings account's own ID as a unique identifier for the creation event
        created_on         -- Timestamp of when the savings account was created
    FROM
        savings_savingsaccount
),

-- CTE to determine the overall observation period in months, based on account creation dates
overall_account_creation_period AS (
    SELECT
        -- Calculate the number of months from the earliest to the latest account creation
        -- If no accounts exist in the table, MIN/MAX will be NULL, resulting in 0 months
        CASE
            WHEN MIN(ace.created_on) IS NULL OR MAX(ace.created_on) IS NULL THEN 0
            -- GREATEST ensures at least 1 month if all account creations are within the same month
            ELSE GREATEST(1, TIMESTAMPDIFF(MONTH, MIN(ace.created_on), MAX(ace.created_on)) + 1)
        END AS total_months_in_dataset
    FROM
        account_creation_events ace
),

-- CTE to count the total number of savings accounts created by each customer
customer_total_account_creations AS (
    SELECT
        owner_id,
        COUNT(account_event_id) AS total_creations -- Count all account creation events for each owner
    FROM
        account_creation_events
    GROUP BY
        owner_id
),

-- CTE to calculate the average number of account creations per customer per month
avg_monthly_creations AS (
    SELECT
        ctac.owner_id,
        ctac.total_creations,
        oacp.total_months_in_dataset,
        -- Calculate average only if the observation period (total_months_in_dataset) is greater than 0
        -- If total_months_in_dataset is 0, this implies no accounts were created, so avg is 0
        CASE
            WHEN oacp.total_months_in_dataset > 0 THEN ctac.total_creations * 1.0 / oacp.total_months_in_dataset
            ELSE 0
        END AS avg_creations_per_customer_per_month
    FROM
        customer_total_account_creations ctac,
        overall_account_creation_period oacp -- Implicit cross join as OverallAccountCreationPeriod has one row
    WHERE oacp.total_months_in_dataset > 0 -- This ensures we only proceed if there's a valid period. If no accounts, this CTE will be empty
),

-- CTE to categorize customers based on their average monthly account creation frequency
categorized_creations AS (
    SELECT
        camc.owner_id, -- This is the customer identifier
        camc.avg_creations_per_customer_per_month,
        CASE
            WHEN camc.avg_creations_per_customer_per_month >= 10 THEN 'High Frequency'
            WHEN camc.avg_creations_per_customer_per_month >= 3  THEN 'Medium Frequency' -- Implicitly < 10 due to order
            ELSE 'Low Frequency' -- Covers < 3 (i.e., 0 to 2.99... account creations per month)
        END AS frequency_category
    FROM
        avg_monthly_creations camc
)

-- Final SELECT to aggregate results into the expected output format
SELECT
    ccc.frequency_category,
    COUNT(ccc.owner_id) AS customer_count, -- Count of distinct customers in each frequency category
    AVG(ccc.avg_creations_per_customer_per_month) AS avg_transactions_per_month -- This now represents the average 'account creations' per month for customers in this category
FROM
    categorized_creations ccc
GROUP BY
    ccc.frequency_category
ORDER BY
    CASE ccc.frequency_category
        WHEN 'High Frequency' THEN 1
        WHEN 'Medium Frequency' THEN 2
        WHEN 'Low Frequency' THEN 3
        ELSE 4
    END;