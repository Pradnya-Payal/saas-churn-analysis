-- ============================================================
-- SaaS Customer Churn Analysis - SQL Project
-- Dataset: SaaS Customer Churn Prediction Dataset (Kaggle, suhanigupta04)
-- Total records: 2000 customers
-- ============================================================


-- ============================================================
-- SETUP: Database and Table Creation
-- ============================================================

CREATE DATABASE saas_churn_project;

USE saas_churn_project;

-- Create customers table matching the CSV columns:
-- Customer_ID, Name, Email, Account_Age_Days, Login_Frequency,
-- Daily_Usage_Mins, Last_Support_Ticket, Churn
create table customers(
customer_id INT Primary key NOT NULL,
Name varchar(100),
Email varchar(100),
Account_Age_Days INT,
Login_Frequency varchar(100),
Daily_Usage_Mins INT,
Last_Support_Ticket TEXT,
Churn INT
);

-- Data imported via Table Data Import Wizard (train.csv) - 2000 rows

-- BUG FOUND: Customer_ID turned out to be a UUID (36-character text like
-- a8b2ac22-dd31-483e-8672-592b7089138f), not a whole number. The INT type
-- could not hold it, which caused the import to fail with error:
-- "Column 'Account_Age_Days' specified twice" (a side effect of the type
-- mismatch during import). Fixed by altering the column type:
ALTER TABLE customers MODIFY COLUMN customer_id varchar(36);

-- After this fix, data imported successfully - confirmed via:
-- SELECT COUNT(*) FROM customers;  -->  2000 rows


-- ============================================================
-- DATA CLEANING CHECKS (done in Excel before import)
-- ============================================================
-- 1. Checked total row count - confirmed 2000 customer records
-- 2. Checked for blank/missing values using Go To Special > Blanks
--    - Result: No blank cells found
-- 3. Checked for duplicate records using Remove Duplicates
--    (checked against Customer_ID column only)
--    - Result: No duplicates found
-- 4. Conclusion: Dataset is clean, ready to load into SQL database


-- ============================================================
-- Query 1: Overall churn rate
-- ============================================================
-- Question: How many customers churned vs stayed?
select churn, count(churn) as total_churn
from customers
group by churn;
-- Result: 0 (stayed) = 1263, 1 (churned) = 737
-- Churn rate = 737/2000 = 36.85%


-- ============================================================
-- Query 2: Usage minutes vs churn
-- ============================================================
-- Question: What is the average Daily_Usage_Mins for churned vs non-churned customers?
Select AVG(Daily_Usage_Mins) as avg_Daily_Usage_Mins, churn
from customers
group by churn;
-- Result: Churned (1) avg = 16.42 mins/day, Stayed (0) avg = 47.68 mins/day
-- Insight: Retained customers use the product ~3x more than churned customers,
-- suggesting low engagement is a strong churn signal
-- Note: This is a correlation, not proven causation - low usage could cause
-- churn, OR customers who already decided to leave may reduce usage first.
-- Would need time-based data (usage trend before churn date) to confirm direction.


-- ============================================================
-- Query 3: Login frequency vs churn rate
-- ============================================================
-- Question: What is the churn rate for each login frequency group
-- (Daily, Weekly, Rarely)?
-- Why it matters: Helps identify if infrequent logins are a warning
-- sign for churn, which could help flag at-risk customers early.
Select (sum(churn)/count(*))*100 as rate_of_churn, login_frequency
from customers
group by Login_Frequency;
-- Result: 85.4599 Rarely : 13.0184 Daily : 42.2642 Weekly
-- Insight: Customers who log in rarely churn far more often than those who
-- log in daily or weekly, and the difference gets bigger the less often they
-- log in. (Rarely: 85.46%, Weekly: 42.26%, Daily: 13.02%)


-- ============================================================
-- Query 4: Account age vs churn
-- ============================================================
-- Question: Do customers who've been with us longer stick around more,
-- or do newer customers actually stay longer?
-- What is the average Account_Age_Days for churned customers vs. non-churned customers?
select churn, AVG(Account_Age_Days) as total_customers_Days
from customers
group by churn;
-- Result: 1 (churned): 548, 0 (stayed): 568
-- Insight: Account age days shows only a small difference between the churn
-- (548) and the stayed (568); this alone can not predict the churn, compare
-- to the login_frequency result.


-- ============================================================
-- Query 5: Usage buckets vs churn rate (CASE statement) - STRONGEST FINDING
-- ============================================================
-- Question: Which customers are more likely to churn based on their daily
-- usage, and is there a danger zone of low usage?
select
 CASE
 WHEN Daily_Usage_Mins<= 20 THEN 'Low(0-20)mins'
 WHEN Daily_Usage_Mins between 21 and 50 THEN 'Medium(21-50)mins'
 else 'High(50+mins)'
 END 'usage_bucket',
 COUNT(*) AS total_customers,
 sum(churn) as total_churn_customers,
 (sum(churn)/count(*))*100 as churn_rate_percent
 from customers
 group by usage_bucket;
-- Result: Low(0-20)mins: 788 customers, 575 churned, 72.9695% churn rate
--         Medium(21-50)mins: 629 customers, 102 churned, 16.2162% churn rate
--         High(50+mins): 583 customers, 60 churned, 10.2916% churn rate
-- Insight: The customers using the product 50+ mins or 21-50 mins are clearly
-- not in the danger zone (10.29% and 16.22% churn respectively), while
-- customers using the product 20 minutes or less per day are in a clear
-- danger zone (72.97% churn) - nearly 3x higher than the medium group and
-- 7x higher than the high-usage group.


-- ============================================================
-- Query 6: Ranked worst customers by usage (RANK window function + subquery)
-- ============================================================
-- Question: Which customers are most likely to leave/churn, ranked from worst
-- to best based on their daily usage minutes?
-- Why it matters: This lets the company reach out to the customers most likely
-- to leave (e.g. with a special offer or check-in email) before they actually cancel.

-- Full ranked list:
select customer_id, name, Daily_Usage_Mins,
RANK() over (order by Daily_usage_mins asc) as customer_churn_rank
from customers;

-- Count of customers tied at the worst rank:
select count(*) from
(select customer_id, name, Daily_Usage_Mins,
RANK() over (order by Daily_usage_mins asc) as customer_churn_rank from customers) as temp_name
WHERE customer_churn_rank = 1;
-- Result: 48 customers share the worst rank, all with 1 min/day of usage.
-- Insight: These 48 customers represent the most extreme cases within the
-- larger "danger zone" group found earlier (788 low-usage customers). Rather
-- than treating all 788 the same, the company can prioritize outreach starting
-- with these 48 most-at-risk customers first, since they have real names
-- attached to act on immediately.
-- Technique note: used a subquery (window function results can't be filtered
-- directly with WHERE, so the RANK() query had to be wrapped as a subquery).


-- ============================================================
-- Query 7: Support ticket length vs churn (string function - LENGTH)
-- ============================================================
-- Question: Which customers in the company are most likely to churn - those
-- who write longer support messages or those with shorter messages?
-- Why it matters: The company gets the idea if longer support ticket messages
-- are correlated with churn - it means the customers are reaching out with
-- unresolved problems before leaving.
select Avg(length(Last_Support_Ticket)) as avg_length_Last_Support_Ticket, churn
from customers
group by churn;
-- Result: avg length for stayed (0) = 41.9192 characters,
--         avg length for churned (1) = 50.8928 characters
-- Insight: The avg_length_Last_Support_Ticket has a very small difference
-- (50 churned vs 41 stayed) - it alone can't predict the churn.


-- ============================================================
-- Query 8: Login frequency groups above 50% churn (HAVING clause)
-- ============================================================
-- Question: Which login frequency groups have a churn rate higher than 50%?
-- Why it matters: The company gets the idea of which login frequency groups
-- cause the most churn, automatically, without manually checking each group.
select login_frequency,
COUNT(*) AS total_customers,
sum(churn) as total_churn_customers
from customers
group by login_frequency
having (sum(churn)/count(*))*100 > 50;
-- Result: Only the "Rarely" login frequency group has a churn rate above 50%
-- (288/337 = ~85.46%), while Daily and Weekly did not meet the condition.
-- Insight: In the login frequency groups, "Rarely" is the subset that is the
-- most danger zone compared to Weekly and Daily. The HAVING clause made this
-- possible rather than manually checking all groups one by one.


-- ============================================================
-- SQL Techniques used across all 8 queries:
-- SELECT, WHERE, GROUP BY, aggregates (COUNT/SUM/AVG), CASE statements,
-- window functions (RANK), subqueries, string functions (LENGTH), HAVING
-- ============================================================
