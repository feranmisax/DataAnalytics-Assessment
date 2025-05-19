-- Query to find Account Inactivity Alert

SET @current_date = curdate(); -- Set reference "current date" as per user instruction

-- CTE for active plans
WITH active_plans AS (
    SELECT
        p.id AS plan_id,                 -- plan id either regular savings or investments
        p.owner_id,                      -- the owner of those plans
        p.description,                   -- the description of the plans identified
        CASE 
        WHEN p.is_regular_savings = 1 THEN 'Savings' -- this categorizes plans that meets this criteria as savings
        WHEN p.is_a_fund = 1 THEN 'Investment' -- this categorizes plans that meets this criteria as investments
        ELSE 'Unknown'
        END AS type,
        p.created_on AS plan_creation_date, -- the date such identified plan was created
        p.last_charge_date AS plan_updated_at,    -- this identifies the date such plan had any activity
        P.amount AS amount_paid   -- the amount paid for the last activity
    FROM
        plans_plan p
    WHERE
        p.status_id = 2 -- Assuming status 2 means 'Ongoing' or 'Active' for plans_plan
),

-- CTE to get activity records
savings_account_activity AS (
    SELECT
        ssa.plan_id,                         -- From savings_savingsaccount.plan_id (for joining)
        MAX(ssa.transaction_date) AS max_ssa_updated_at, -- last transaction inflow
        SUM(CASE WHEN COALESCE(ssa.confirmed_amount, 0) > 0 THEN 1 ELSE 0 END) AS count_funded_linked_ssa -- Counts linked savings accounts that have a positive confirmed_amount 
    FROM
        savings_savingsaccount ssa
    WHERE
        ssa.plan_id IS NOT NULL            -- Ensure it's linked to a plan
    GROUP BY
        ssa.plan_id
),

-- CTE to combine plan activity with savings account activity
combined_activity AS (
    SELECT
        ap.plan_id,
        ap.owner_id,
        ap.type,
        ap.plan_creation_date,
        -- Determine the most recent update time (proxy for last activity)
        GREATEST(
            COALESCE(ap.plan_updated_at, '0001-01-01'),
            COALESCE(lsa.max_ssa_updated_at, '0001-01-01')
        ) AS temp_effective_last_update, -- This will be the latest known update for the plan or its linked accounts
        (COALESCE(ap.amount_paid, 0) > 0 OR COALESCE(lsa.count_funded_linked_ssa, 0) > 0) AS has_any_inflow_indicator
    FROM
        active_plans ap
    LEFT JOIN
        savings_account_activity lsa ON ap.plan_id = lsa.plan_id
),

-- CTE to finalize the effective_last_update date (handling the '0001-01-01' placeholder)
activity_summary AS (
    SELECT
        cpa.plan_id,
        cpa.owner_id,
        cpa.type,
        cpa.plan_creation_date,
        CASE WHEN cpa.temp_effective_last_update = '0001-01-01' 
        THEN NULL 
        ELSE cpa.temp_effective_last_update 
        END AS effective_last_update,
        cpa.has_any_inflow_indicator
    FROM combined_activity cpa
)
-- Final SELECT to identify plans with no inflow activity for over 365 days
SELECT
    pas.plan_id,
    pas.owner_id,
    pas.type,
    -- Display last_transaction_date (by effective_last_update) only if inflow was indicated.
    CASE
        WHEN pas.has_any_inflow_indicator 
        THEN DATE(pas.effective_last_update)
        ELSE NULL -- No detectable inflow, so no last transaction date for inflow.
		END AS last_transaction_date,
    -- Calculate inactivity_days. The reference point for inactivity is the effective_last_update if inflows were indicated,
    -- otherwise it's the plan_creation_date (plan has been inactive with respect to inflows since creation).
    DATEDIFF(
        @current_date,
        CASE
            WHEN pas.has_any_inflow_indicator AND pas.effective_last_update IS NOT NULL 
            THEN pas.effective_last_update
            ELSE pas.plan_creation_date
        END
    ) AS inactivity_days
FROM
    activity_summary pas
WHERE
    -- The inactivity condition: checks if the reference date for activity is older than 365 days.
    CASE
        WHEN pas.has_any_inflow_indicator AND pas.effective_last_update IS NOT NULL 
        THEN pas.effective_last_update
        ELSE pas.plan_creation_date -- If no inflow indicated, check inactivity since creation
    END < DATE_SUB(@current_date, INTERVAL 365 DAY)
ORDER BY
    inactivity_days DESC;


    