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
        * I used subqueries here and they were used to aggregate data for users with funded savings plans and another for users with funded investment plans.
        * They count the number of respective plans and sum their relevant deposit amounts ( `savings_savingsaccount.confirmed_amount` depending on the specific interpretation being refined).
    4.  **Final Selection:** The `users_customuser` table was then `INNER JOIN`ed with both subqueries. The `INNER JOIN` ensures that only customers present in *both* subqueries (i.e., having at least one of each product type) are selected.
    5.  **Total Deposits and Sorting:** The total deposits from both product types were summed, and the results were ordered by this sum in descending order.

---

### 2. Transaction Frequency Analysis
* **Explanation of Approach (based on the user-provided query):**
    1.  **Interpreting "Transaction":** I defined a "transactional event" as **the creation of a savings account**. Therefore, this analysis measures the frequency of *savings account creations* per customer. The column name `created_on` in the provided query for `savings_savingsaccount` was used.
    2.  **Identifying Account Creation Events:**
        * I created a CTE named `account_creation_events`.
        * In this CTE, I selected `owner_id`, the savings account's `id` (aliased as `account_event_id`), and its creation timestamp (`created_on` in the provided query and needs schema alignment) from the `savings_savingsaccount` table. Each row here represents one "account creation event."
    3.  **Calculating Overall Observation Period:**
        * I then used a CTE `overall_account_creation_period` to determine the total span of time, in months, during which these account creations happened.
        * I found the `MIN(created_on)` and `MAX(created_on)` from the `account_creation_events`. The difference in months, plus one, gave the `total_months_in_dataset`. I used `GREATEST(1, ...)` to ensure this period is at least 1 month, and handled the case where no accounts exist (period becomes 0).
    4.  **Aggregating Creations Per Customer:**
        * In the `customer_total_account_creations` CTE, I grouped the `account_creation_events` by `owner_id` and used `COUNT(account_event_id)` to get the `total_creations` for each customer.
    5.  **Calculating Average Monthly Creations:**
        * The `avg_monthly_creations` CTE calculated `avg_creations_per_customer_per_month` by dividing `total_creations` by `total_months_in_dataset`. I ensured this calculation only proceeded if `total_months_in_dataset > 0`.
    6.  **Categorization:**
        * In the `categorized_creations` CTE, I used a `CASE` statement to assign each customer to a `frequency_category` ("High Frequency", "Medium Frequency", or "Low Frequency") based on their `avg_creations_per_customer_per_month` (>=10, 3-9, <3 respectively).
    7.  **Final Aggregation and Output:**
        * The final `SELECT` statement grouped results by `frequency_category`.
        * I calculated `customer_count` using `COUNT(owner_id)` within each category.
        * I calculated `avg_transactions_per_month` by taking the `AVG()` of the `avg_creations_per_customer_per_month` for all customers within that category. This output column name is kept for consistency with the original problem, but its meaning here is "average account creations per month."
        * The results are ordered by frequency category.

---
