# Screenshots

> **Author:** Malaya Kumar Padhi (Malay)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide

This folder contains screenshots demonstrating the CREATE OR ALTER TABLE pitfall and recovery process.

## Screenshot List

| File | Description | Used In |
|------|-------------|---------|
| `01_before_data.png` | Original table with 5 columns and sample data | README, LinkedIn Post 1 |
| `02_after_data_loss.png` | Table after CREATE OR ALTER - only 3 columns remain | README, LinkedIn Post 1 |
| `03_recovery_success.png` | Recovered table showing all 5 columns restored | README, LinkedIn Post 2 |
| `04_error_time_travel.png` | "Time travel data not available" error message | Troubleshooting section |
| `05_clone_success.png` | Successful CLONE AT(TIMESTAMP) execution | LinkedIn Post 2 |

## How to Capture Screenshots

### 1. Before Data (01_before_data.png)
```sql
-- Run in Snowsight, then screenshot the results
USE DATABASE DATA_RECOVERY_DEMO;
USE SCHEMA DEMO;
SELECT * FROM orders;
```
**Expected:** 5 columns (order_id, customer_name, order_date, amount, status)

### 2. After Data Loss (02_after_data_loss.png)
```sql
-- After running CREATE OR ALTER, screenshot the results
SELECT * FROM orders;
DESC TABLE orders;
```
**Expected:** Only 3 columns (order_id, amount, priority) - customer_name, order_date, status are GONE

### 3. Recovery Success (03_recovery_success.png)
```sql
-- After running recovery script, screenshot the results
SELECT * FROM orders;
DESC TABLE orders;
```
**Expected:** All 5 original columns restored

### 4. Error Message (04_error_time_travel.png)
```sql
-- This will fail - capture the error
SELECT * FROM orders AT(TIMESTAMP => '2020-01-01'::TIMESTAMP);
```
**Expected:** Error message about time travel not available

### 5. Clone Success (05_clone_success.png)
```sql
-- Capture successful clone creation
CREATE TABLE orders_recovered CLONE orders AT(TIMESTAMP => 'your_timestamp');
SELECT * FROM orders_recovered;
```
**Expected:** Statement executed successfully + recovered data

## Tips for Good Screenshots

1. **Use Snowsight** (web UI) for consistent look
2. **Expand results** to show all columns
3. **Include the SQL** in the screenshot if possible
4. **Highlight key areas** with red boxes (optional, use image editor)
5. **Use consistent window size** for all screenshots

## Adding Screenshots to Repository

After capturing screenshots:
1. Save as PNG files with the names listed above
2. Place in this `screenshots/` folder
3. Reference in README.md and LinkedIn posts using:
   ```markdown
   ![Before Data](screenshots/01_before_data.png)
   ```
