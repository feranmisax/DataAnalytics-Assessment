# DataAnalytics-Assessment
This document contains the SQL queries developed for analyzing data from the `adashi_staging` database, based on the `adashi_assessment.sql` dump. For each question, the approach, specific challenges, and the final query.

**Reference Date for Analysis:** For time-sensitive queries (like inactivity or tenure), I assumed the reference "current date" to be **'2025-04-18'**, based on the latest timestamps observed in the dump.

## Per-Question Analysis

### 1. High-Value Customers with Multiple Products
 
* **Explanation of Approach:**
    1.  **Getting each Product type:** The aim of this question was to identify "savings plans" and "investment plans correctly." The `adashi_assessment.sql` dump revealed that `is_regular_savings = 1` determines that a plan is savings and is_a_fund = 1 determines that a plan is investment which is the accurate way to distinguish these.
    2.  **Defining if a plan is funded or not:**
        * After determining each product type, I then moved on to define whether a plan is funded or not For plans derived from the `plans_plan` table, "funded" was interpreted as `SA.confirmed_amount > 0 since confimed_amount column from the savings table determines the figures from the amount column were successfully deposited.
    3.  **Identifying Customers with Both savings and investment plans:**
        * A subquery was used to aggregate data for users with funded savings plans and another for users with funded investment plans.
        * They count the number of respective plans and sum their relevant deposit amounts (`savings_savingsaccount.confirmed_amount` depending on the specific interpretation being refined).
    4.  **Final Selection:** The `users_customuser` table was then `INNER JOIN`ed with both subqueries. The `INNER JOIN` ensures that only customers present in *both* subqueries (i.e., having at least one of each product type) are selected.
    5.  **Total Deposits and Sorting:** The total deposits from both product types were summed, and the results were ordered by this sum in descending order.

---

### 2. Transaction Frequency Analysis
* **Explanation of Approach (based on the user-provided query):**
    1.  **Interpreting "Transaction":** I defined a "transactional event" as **the creation of a savings account**. Therefore, this analysis measures the frequency of *savings account creations* per customer. The column name `created_on` in the provided query for `savings_savingsaccount` was used.
    2.  **Identifying Account Creation Events:**
        * I created a CTE named `account_creation_events`.
        * In this CTE, I selected `owner_id`, the savings account's `id` (aliased as `account_event_id`), and its creation timestamp (`created_on` in the provided query) from the `savings_savingsaccount` table. Each row here represents one "account creation event."
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

### 3. Account Inactivity Alert

* **Explanation of Approach:**
    My approach was to identify "active accounts" primarily from the `plans_plan` table and identify "inflow transaction" activity and the "last transaction date" using only the columns available in `plans_plan` and `savings_savingsaccount`.

    1.  **Setting the Current Date:** I set `@current_date = CURDATE();` so the inactivity calculation is always relative to the day the query is run.
    2.  **Identifying Active Plans (`active_plans` CTE):**
        * I selected plans from the `plans_plan` table (`p`).
        * I considered a plan "active" if `p.status_id = 2`. *(The lookup table `plans_plan_status` indicates `status_id = 2` is 'Ongoing'.)*
        * I derived the `type` ('Savings' or 'Investment') using `CASE` statements based on `p.is_regular_savings = 1` and `p.is_a_fund = 1`. 
        * I used `p.created_on` as `plan_creation_date`.
        * I used `p.last_charge_date` as `plan_updated_at` to find the plan's last activity.
        * I selected `P.amount` as `amount_paid`. 
    3.  **Gathering Linked Savings Account Activity (`savings_account_activity` CTE):**
        * To incorporate activity from `savings_savingsaccount` that might be related to a plan, I created this CTE.
        * I grouped `savings_savingsaccount` (`ssa`) records by `ssa.plan_id` (assuming this links back to `plans_plan.id`).
        * I used `MAX(ssa.transaction_date)` as `max_ssa_updated_at` to get the latest "transaction date" from the savings account.
        * I counted "funded linked savings accounts" using `SUM(CASE WHEN COALESCE(ssa.confirmed_amount, 0) > 0 THEN 1 ELSE 0 END)`. This uses `confirmed_amount`.
        * I filtered for `ssa.plan_id IS NOT NULL`. 
    4.  **Combining Activity queries (`combined_activity` CTE):**
        * I `LEFT JOIN`ed `active_plans` with `savings_account_activity`.
        * I determined `temp_effective_last_update` by taking the `GREATEST` of the plan's proxied last activity date (`ap.plan_updated_at` which mapped to `p.last_charge_date`) and the linked savings accounts' latest proxied transaction date (`lsa.max_ssa_updated_at` which mapped to `MAX(ssa.transaction_date)`). `COALESCE` with '0001-01-01' was used to handle `NULL`s in `GREATEST`.
        * I created an `has_any_inflow_indicator` flag. This is true if the plan's `amount_paid` (proxied by `P.amount`) is greater than 0 OR if there's at least one "funded linked savings account." This proxies an inflow.
    5.  **Finalizing Activity Summary (`activity_summary` CTE):**
        * I converted the `temp_effective_last_update` placeholder '0001-01-01' back to `NULL` if no actual update date was found from either source, resulting in `effective_last_update`.
    6.  **Final Selection and Inactivity Logic:**
        * `last_transaction_date`: I displayed this as `DATE(pas.effective_last_update)` but only if `pas.has_any_inflow_indicator` is true. Otherwise, it's `NULL` (no proxied inflow, so no last transaction date for an inflow).
        * `inactivity_days`: I calculated this using `DATEDIFF(@current_date, reference_date)`. The `reference_date` is `pas.effective_last_update` if an inflow was indicated *and* an `effective_last_update` date exists; otherwise, it defaults to `pas.plan_creation_date`. This means if no inflow was ever detected via proxies, inactivity is measured since the plan's creation.
        * `WHERE` Clause: I filtered for plans where this `reference_date` is older than 365 days from `@current_date`.
        * The results are ordered by `inactivity_days` descending.

---

### 4. Customer Lifetime Value (CLV) Estimation

* **Reference "Current Date":** `CURDATE()` (dynamically set at query execution time).

* **Explanation of Approach (based on the user-provided query):**
 My approach for this query involved making significant interpretations for the metrics "total transactions" and "transaction value," as these are not directly available in the specified tables in a granular, transactional form.

    1.  **Setting the Current Date:** I used `SET @current_date = CURDATE();` to ensure that the tenure calculation is always based on the date the query is executed.
    2.  **Interpreting "Transactions" and "Transaction Value":**
        * The introductory comments in my query explicitly state these crucial interpretations:
            * **"Total transactions"**: I interpreted this as the total number of savings accounts a customer owns. Each row in `savings_savingsaccount` for a customer is counted as one "transactional event."
            * **"Total transaction value"**: For the purpose of calculating profit, I interpreted this as the sum of `confirmed_amount` from these savings accounts. 
    3.  **Calculating Customer Tenure (`customer_tenure` CTE):**
        * I selected `id` (as `customer_id`) and concatenated `first_name` and `last_name` (for `name`) from the `users_customuser` table.
        * I calculated `tenure_months` using `TIMESTAMPDIFF(MONTH, uc.date_joined, @current_date)`. To prevent division by zero in the CLV formula and to handle very new users, I wrapped this with `GREATEST(1, ...)` ensuring a minimum tenure of 1 month.
        * I filtered for users where `uc.date_joined <= @current_date`.
    4.  **Aggregating Transaction Data (`account_aggregates` CTE):**
        * I selected `owner_id` from `savings_savingsaccount` (`sa`).
        * I counted `sa.savings_id` (aliased as `total_transactions`). 
        * I summed `COALESCE(sa.confirmed_amount, 0)` to get `total_transaction_value`.
        * These results were grouped by `sa.owner_id`.
    5.  **Final CLV Calculation and Output:**
        * I `LEFT JOIN`ed the `customer_tenure` CTE with the `account_aggregates` CTE on `customer_id = owner_id`. This ensures all customers are included, even if they have no savings accounts (their transaction counts and values would be 0).
        * `total_transactions` displayed is the `COALESCE(aa.total_transactions, 0)`.
        * The `estimated_clv` was calculated using the simplified formula: `(COALESCE(aa.total_transaction_value, 0) * 0.001 * 12) / ct.tenure_months`. The `0.001` represents the 0.1% profit margin, and `12` annualizes it. `tenure_months` is guaranteed to be at least 1.
        * The results were ordered by `estimated_clv` descending.


## General Challenges Encountered & Resolutions

1.  **Schema Discovery and Accuracy:**
    * **Challenge:** The first challenge I faced was having few tables and columns to effectively carry out this analysis using the `adashi_assessment.sql` dump. This directly impacted query accuracy and executability.
    * **Resolution:** I consistently referred back to the `adashi_assessment.sql` dump to verify actual table structures, column names, primary/foreign keys, data types, and the meaning of status/type codes. I also made use of the hint provided in the doc to guide me.

2.  **Interpreting Business Logic under Strict Table Constraints:**
    * **Challenge:** There were limitations on what tables to use per question (e.g., tables `users_customuser` and `savings_savingsaccount`") even when these tables lacked direct data for the required metrics (like detailed transaction history for "transaction frequency" or "CLV"). This necessitated making significant assumptions and using available fields as proxies.
    * **Resolution:** When faced with this issue, I make sure to fully understand each question and look through the tables to see how they both link for such specific question.

3.  **Date and Time Functions for Analysis:**
    * **Challenge:** Ensuring consistent and correct date/time calculations for metrics like tenure or inactivity periods.
    * **Resolution:** I utilized standard SQL date/time functions appropriate for MySQL (which the dump syntax suggests), such as `TIMESTAMPDIFF()`, `DATEDIFF()`, `DATE_SUB()`, `GREATEST()`, `COALESCE()`, and `DATE()`. A fixed `@current_date` variable was often discussed and used for reproducibility in time-sensitive analyses, or `CURDATE()` if specified in the user's query.

4.  **Handling NULLs, Data Integrity, and Division by Zero:**
    * **Challenge:** Ensuring that aggregations, joins, and arithmetic calculations handle `NULL` values effectively and potential errors like division by zero (e.g., in CLV if tenure was zero or transaction counts were zero).
    * **Resolution:** I used `COALESCE()` to handle `NULL`s in calculations (e.g., defaulting `NULL` sums to 0). For division, I ensured denominators were non-zero, often by using `GREATEST(1, denominator)` for quantities like tenure, or by using `CASE` statements to explicitly handle scenarios where a denominator might be zero (e.g., setting CLV to 0 if there were no transactions). `LEFT JOIN` was used when records from one table were needed regardless of a match, while `INNER JOIN` was used to enforce conditions requiring matches across all joined tables.

5.  **Dynamic vs. Fixed "Current Date":**
    * **Challenge:** Some queries were developed assuming a fixed "current date" based on data recency, while others provided by the user employed `CURDATE()`.
    * **Resolution:** I adapted the explanations and the `SET @current_date` line to match the context of the specific query being documented for the README.

This README provides explanations for each query alongside the challenges faced and how they were resolved.
