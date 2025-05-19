-- Query to identify users with at least one funded savings plan AND one funded investment plan, sorted by total deposits

SELECT
    uc.id AS owner_id, -- User's ID from the users_customuser table
    CONCAT(uc.first_name, ' ', uc.last_name) AS name, -- Concatenates first and last name for the full name of users
    us.savings_count, -- Number of savings products for the user
    ui.investment_count, -- Number of investment products for the user
    (us.total_savings_deposits + ui.total_investments_deposits) AS total_deposits -- Calculates the sum of deposits from both savings and investment plans
FROM
    users_customuser uc -- Alias for the main user table

-- Subquery for user_savings 
INNER JOIN (
    SELECT
        SA.owner_id, -- Selects Distinct owner's ID
        COUNT(SA.savings_id) AS savings_count, -- Counts the number of savings products for the owner
        SUM(SA.confirmed_amount) AS total_savings_deposits -- Sums the confirmed amounts for the savings products found
    FROM
        savings_savingsaccount AS SA -- Alias for the savings_savingsaccount table
        LEFT JOIN plans_plan AS PL ON PL.id = SA.plan_id -- Joins with plans_plan to filter for only users with a savings plan as is_regular_savings = 1 shows if a plan is savings or not
                                                       -- LEFT JOIN means accounts without a matching plan_id would still be included
    WHERE
        SA.confirmed_amount > 0 -- Filters for savings accounts that are 'funded'
        AND PL.is_regular_savings = 1 -- Condition to identify this account as a 'regular savings' type in the plans_plan table
    GROUP BY
        SA.owner_id -- Groups the results by owner to perform aggregations per user
    HAVING
        COUNT(SA.savings_id) >= 1 -- Ensures the user has at least one 'savings plan'
) AS us ON uc.id = us.owner_id -- Ensures that only users present in UserSavings (i.e., have funded savings) are included

-- Subquery for user_investments
INNER JOIN (
    SELECT
        SA.owner_id, -- Selects the owner's ID
        COUNT(SA.savings_id) AS investment_count, -- Counts the number of investment products for the owner
        SUM(SA.confirmed_amount) AS total_investments_deposits -- Sums the confirmed amounts for these investment
    FROM
        savings_savingsaccount AS SA -- Alias for the savings_savingsaccount table
        LEFT JOIN plans_plan AS PL ON PL.id = SA.plan_id -- Joins with plans_plan
    WHERE
        SA.confirmed_amount > 0 -- Filters for accounts that are 'funded'
        AND PL.is_a_fund = 1 -- Condition to identify this account as an 'investment fund' type
    GROUP BY
        SA.owner_id -- Groups by owner.
    HAVING
        COUNT(SA.savings_id) >= 1 -- Ensures the user has at least one such 'investment plan'
) AS ui ON uc.id = ui.owner_id -- Further ensures that these users are also present in UserInvestments (i.e., have funded investments).

ORDER BY
    total_deposits DESC; -- Sorts the final results by the total deposits in descending order


    