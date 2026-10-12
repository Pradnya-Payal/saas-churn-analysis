# SaaS Customer Churn Analysis Project

## Overview

This project analyzes a public Kaggle dataset of SaaS (Software as a Service) customer data
to understand why customers churn (cancel their subscription) and
identify patterns that predict churn. The project uses SQL, Excel,
and Power BI together, but each part also works as a standalone piece.

## Business Question

Why are customers churning, and which customer behaviors are linked
to a higher chance of leaving?

## Dataset

* Source: Kaggle - "SaaS Customer Churn Prediction Dataset"
(by suhanigupta04)
* File used: train.csv
* Total records: 2000 customers
* Columns: Customer\_ID, Name, Email, Account\_Age\_Days,
Login\_Frequency, Daily\_Usage\_Mins, Last\_Support\_Ticket, Churn

## Tools Used

* SQL (MySQL Workbench) - data storage and analysis
* Excel - data cleaning check, pivot tables, charts
* Power BI - visual dashboard

## Data Cleaning Process (done in Excel before loading into SQL)

1. Checked total row count - confirmed 2000 customer records
2. Checked for blank/missing values using Go To Special > Blanks

   * Result: No blank cells found
3. Checked for duplicate records using Remove Duplicates
(checked against Customer\_ID column only)

   * Result: No duplicates found
4. Conclusion: Dataset is clean, ready to load into SQL database

## Database Setup Notes

* Created database `saas\_churn\_project` and a `customers` table matching
the CSV columns.
* Bug found: Customer\_ID turned out to be a UUID (36-character text,
e.g. a8b2ac22-dd31-483e-8672-592b7089138f), not a whole number. The
original INT column type could not hold it, which broke the import.
Fixed by running ALTER TABLE to change the column to VARCHAR(36).
* After the fix, all 2000 rows imported successfully.

## Key Findings (SQL Analysis - COMPLETE)

1. Overall churn rate: 737/2000 customers churned (36.85%)
2. Usage minutes vs churn:

   * Churned customers average 16.42 mins/day
   * Retained customers average 47.68 mins/day
   * Retained customers use the product \~3x more than churned customers
   * Note: correlation, not proven causation
3. Login frequency vs churn rate:

   * Rarely: 85.46% churn rate
   * Weekly: 42.26% churn rate
   * Daily: 13.02% churn rate
   * Clear pattern: less frequent login = far higher churn risk
4. Account age vs churn:

   * Churned customers avg: 548 days
   * Stayed customers avg: 568 days
   * Only a small gap - account age alone is NOT a strong predictor of churn
   * Contrast: login frequency was a much stronger signal (13% vs 85%)
5. Usage buckets vs churn rate (STRONGEST finding):

   * Low (0-20 mins/day): 72.97% churn rate (788 customers)
   * Medium (21-50 mins/day): 16.22% churn rate (629 customers)
   * High (50+ mins/day): 10.29% churn rate (583 customers)
   * Usage under 20 mins/day is a major danger zone
6. Customer ranking by usage (window function - RANK()):

   * Ranked all 2000 customers individually by Daily\_Usage\_Mins
   * 48 customers tied for the worst rank, all at 1 min/day usage
   * Subset of the larger "Low usage" danger zone (788 customers, Finding #5)
   * Gives the company actual customer names to prioritize for outreach
   * Technique note: used a subquery to filter on a window function result
7. Support ticket length vs churn:

   * Churned customers avg: 50.89 characters
   * Stayed customers avg: 41.92 characters
   * Small difference - not a strong standalone predictor of churn
8. Login frequency groups above 50% churn (HAVING clause):

   * Only "Rarely" crosses the 50% churn threshold (85.46%)
   * Daily and Weekly groups stay below this threshold
   * HAVING clause automatically isolates risky groups instead of manual comparison

## SQL Techniques Used

SELECT, WHERE, GROUP BY, aggregates (COUNT, SUM, AVG), CASE statements,
window functions (RANK), subqueries, string functions (LENGTH), HAVING

## Limitations

This dataset does not include revenue/payment or customer satisfaction
data, so this analysis focuses on behavioral churn signals (usage, login
frequency, support activity) rather than financial impact.



## Key Findings (Excel Analysis -COMPLETE)

1. Usage buckets vs churn rate (independent pivot table analysis):

   * See: Sheet1 (detailed pivot table with raw counts - Churn, Count,
and Churn\_Rate\_Percent side by side, no chart),
Sheet2 (clean pivot table + final chart used for presentation)
   * 0-19 mins/day: 74.02% churn rate (766 customers)
   * 20-39 mins/day: 17.22% churn rate (395 customers)
   * 40-59 mins/day: 15.90% churn rate (522 customers)
   * 60-79 mins/day: 5.98% churn rate (117 customers)
   * 80-99 mins/day: 5.77% churn rate (104 customers)
   * 100-120 mins/day: 6.25% churn rate (96 customers)
   * Confirms SQL finding independently (SQL: 72.97% for 0-20 bucket,
Excel: 74.02% for 0-19 bucket - small difference due to slightly
different bucket boundaries)
   * NEW insight from finer buckets: churn risk drops sharply right after
the 20-minute mark, then stays low and fairly stable from 20-120
minutes. The real danger zone is specifically 0-20 mins/day - beyond
that, additional usage doesn't dramatically improve retention further.
2. Login frequency vs churn rate (independent pivot table analysis):

   * See: Sheet3 (pivot table + chart)
   * Daily: 13.02% churn rate (868 customers)
   * Weekly: 42.26% churn rate (795 customers)
   * Rarely: 85.46% churn rate (337 customers)
   * Confirms SQL finding independently - numbers match almost exactly
(SQL: Daily=13.02%, Weekly=42.26%, Rarely=85.46%)
3. Login frequency x usage buckets vs churn rate (cross-tab):

   * See: Sheet5 (cross-tab pivot table)
   * 0-19 mins/day: Daily 28.8%, Weekly 70.8%, Rarely 85.5% churn
   * All "Rarely" customers fall in the 0-19 min band, so the two
factors overlap heavily
   * Both factors keep their own signal at equal usage levels
   * Limitation: cell-level customer counts not shown, so small cells
should be read with caution
4. Customer lookup tool (XLOOKUP):

   * See: Customer\_Lookup sheet
   * Enter or list customer IDs and the sheet returns each customer's full
record from the raw data using a single XLOOKUP formula
   * Verified against the raw data for sample customers



## Key Findings (Power BI Dashboard - COMPLETE)

File: SaaS\_Churn\_Dashboard.pbix (2 pages)

Page 1 - Overview:

* KPI cards: Total Customers (2000), Churn Rate (36.85%),
Churned Customers (737), Avg Daily Usage (36.16 mins)
* Churn Rate by Login Frequency (Rarely 85%, Weekly 42%, Daily 13%)
* Churn Rate by Daily Usage (20-minute buckets; the 0-19 bucket
is the danger zone at about 74%)
* Login Frequency slicer: clicking a group updates every visual

Page 2 - At-Risk Customers:

* Table of customers who are still active (not churned) but use
the product 20 minutes/day or less, sorted from lowest usage
* Turns the SQL ranking and usage findings into an actionable list
the company could contact before these customers leave

Notes:

* All numbers match the SQL and Excel results, so the three tools
confirm each other
* Custom theme: dark purple glass-style panels

## Project Status

* \[x] Data sourced and cleaned (Excel)
* \[x] Database and tables created (SQL)
* \[x] Data imported into MySQL (2000 rows confirmed)
* \[x] SQL analysis queries written (8 findings, COMPLETE)
* \[x] Excel pivot table analysis - Completed

  * Exported full raw customers table (2000 rows) from MySQL as CSV
  * Confirmed row count matches MySQL (2000 rows + header)
* \[x] Power BI dashboard built

