# DataAnalytics-Assessment
This document contains the SQL queries developed for analyzing data from the `adashi_staging` database, based on the `adashi_assessment.sql` dump. For each question, the approach, specific challenges, and the final query.

**Reference Date for Analysis:** For time-sensitive queries (like inactivity or tenure), I assumed the reference "current date" to be **'2025-04-18'**, based on the latest timestamps observed in the dump.

## Per-Question Analysis

### 1. High-Value Customers with Multiple Products
 
* **Explanation of Approach:**
    1.  **Getting each Product type:** The aim of this question was to identify "savings plans" and "investment plans correctly." The `adashi_assessment.sql` dump revealed that `is_regular_savings = 1` determines that a plan is savings and is_a_fund = 1 determines that a plan is investment which is the accurate way to distinguish these.
    2.  **Defining if a plan is funded or not:**
        * After determining each product type, I then moved on to define whether a plan is funded or not For plans derived from the `plans_plan` table, "funded" was interpreted as `SA.confirmed_amount > 0 since confimed_amount column from the savings table determines the figures from the amount column were successfully deposited.
    3.  **Identifying Customers with Both:**
        * A subquery was used to aggregate data for users with funded savings plans and another for users with funded investment plans.
        * They count the number of respective plans and sum their relevant deposit amounts ( `savings_savingsaccount.confirmed_amount` depending on the specific interpretation being refined).
    4.  **Final Selection:** The `users_customuser` table was then `INNER JOIN`ed with both subqueries. The `INNER JOIN` ensures that only customers present in *both* subqueries (i.e., having at least one of each product type) are selected.
    5.  **Total Deposits and Sorting:** The total deposits from both product types were summed, and the results were ordered by this sum in descending order.

