/*
================================================================================
File:        02_recovery_steps.sql
Purpose:     Recovery steps using Time Travel CLONE for CREATE OR ALTER data loss
Author:      Malaya Padhi (Malay)
Repository:  https://github.com/Techy-Malay/snowflake-data-recovery-guide
Created:     2026-02-22
Modified:    2026-02-22
--------------------------------------------------------------------------------
Context:     
This script is part of a LinkedIn content series on Snowflake data recovery.
After running Script 01 (demo_problem.sql) which simulates data loss from
CREATE OR ALTER TABLE, use this script to recover the lost columns using
Snowflake's Time Travel CLONE feature. 

CRITICAL INSIGHT:
CREATE OR ALTER TABLE modifies the table IN PLACE - it does NOT drop the table.
Therefore, UNDROP TABLE will NOT work. You must use Time Travel CLONE to
recover data from before the destructive change.

Prerequisites:
- Script 01 executed (problem simulated)
- Time Travel retention period not expired (default: 1 day)
- ACCOUNTADMIN or role with ownership on affected objects
- A valid recovery timestamp (saved from Script 01)

Execution Order: 2 of 3 (Demo → Recovery → Prevention)
================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE DATA_RECOVERY_DEMO;
USE SCHEMA DEMO;

/*
--------------------------------------------------------------------------------
STEP 1: Assess the Situation
--------------------------------------------------------------------------------
*/

-- Check current table structure (corrupted state - missing columns)
DESC TABLE orders;

-- Check Time Travel availability
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN TABLE orders;

/*
--------------------------------------------------------------------------------
STEP 2: Find the Timestamp BEFORE the Destructive Change
--------------------------------------------------------------------------------
⚠️ IMPORTANT FOR GITHUB USERS:
The timestamp in Step 3 is hardcoded from the author's test environment.
You MUST find your own timestamp using the queries below.

Strategy: Find a timestamp AFTER table creation but BEFORE the damaging change.
--------------------------------------------------------------------------------
*/

-- Method A: Use INFORMATION_SCHEMA (NO LATENCY - use for recent changes)
-- Shows when table was created and last modified
-- ⚠️ NOTE: Timestamps shown are in your SESSION TIMEZONE
SELECT TABLE_NAME, CREATED, LAST_ALTERED
FROM DATA_RECOVERY_DEMO.INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'ORDERS';

-- CREATED = when table was first created (earliest valid timestamp)
-- LAST_ALTERED = when CREATE OR ALTER damaged it
-- Recovery timestamp must be: CREATED < timestamp < LAST_ALTERED

-- Method B: Use ACCOUNT_USAGE (45-MIN LATENCY - use for older changes)
-- Shows exact query text and timing
SELECT QUERY_ID, QUERY_TEXT, START_TIME
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TEXT ILIKE 'CREATE OR ALTER TABLE%orders%'
  AND DATABASE_NAME = 'DATA_RECOVERY_DEMO'
ORDER BY START_TIME DESC
LIMIT 5;

-- HOW TO PICK THE TIMESTAMP:
-- 1. Get CREATED time from INFORMATION_SCHEMA (e.g., 2026-02-22 18:35:42)
-- 2. Get destructive query time from QUERY_HISTORY (e.g., 2026-02-22 18:40:39)
-- 3. Pick any time between them (e.g., 2026-02-22 18:36:00)

-- ############################################################################
-- #  RECOMMENDED: USE OFFSET METHOD (NO TIMEZONE ISSUES!)                    #
-- #  OFFSET => -300 means "300 seconds ago" - much simpler!                  #
-- ############################################################################

-- STEP 2B: Calculate Valid OFFSET Range
-- Run this query to find valid OFFSET values for your recovery:
SELECT 
    DATEDIFF('second', CREATED, CURRENT_TIMESTAMP()) AS secs_since_insert,
    DATEDIFF('second', LAST_ALTERED, CURRENT_TIMESTAMP()) AS secs_since_damage,
    '--- VALID OFFSET RANGE ---' AS info,
    -DATEDIFF('second', CREATED, CURRENT_TIMESTAMP()) + 10 AS min_offset_value,
    -DATEDIFF('second', LAST_ALTERED, CURRENT_TIMESTAMP()) - 10 AS max_offset_value
FROM DATA_RECOVERY_DEMO.INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'ORDERS';

/*
    OFFSET VISUAL GUIDE:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                                    NOW
    -1800        -1200         -600          -300         -60        │
    (30 min)    (20 min)      (10 min)      (5 min)     (1 min)      │
       │            │             │             │           │        │
       │            │             │             │           │        │
     INSERT    ─────┴─────  VALID RANGE  ──────┴───── CREATE OR ALTER
     DATA                   FOR OFFSET                  (damage)
    
    Pick any OFFSET value BETWEEN secs_since_damage and secs_since_insert
    (with negative sign!)
    
    Example: If secs_since_insert=1200 and secs_since_damage=300
             Valid OFFSET: -400 to -1100 (pick -600 for safety)
*/

/*
--------------------------------------------------------------------------------
STEP 3: Recover Data Using Time Travel CLONE
--------------------------------------------------------------------------------
CREATE OR ALTER modifies in place - UNDROP will NOT work.
Use CLONE AT(TIMESTAMP) to recover the table state before the change.
--------------------------------------------------------------------------------
*/

-- First, try UNDROP to show why it doesn't work (for educational purposes)
-- UNDROP TABLE orders;  -- This will fail or restore wrong version

-- 📸 SCREENSHOT #4: 04_error_time_travel.png - Run this to capture error:
-- SELECT * FROM orders AT(TIMESTAMP => '2020-01-01'::TIMESTAMP);
-- (Shows: "Time travel data is not available...")

-- ⚠️ METHOD 1: TIMESTAMP (timezone-sensitive - can cause errors!)
-- Use the timestamp you saved from Script 01, Step 3
-- Example below is from author's test - yours will be different
-- CREATE OR REPLACE TABLE orders_recovered CLONE orders 
-- AT(TIMESTAMP => 'YYYY-MM-DD HH:MI:SS'::TIMESTAMP);  -- ← PASTE YOUR TIMESTAMP HERE!

-- ✅ METHOD 2: OFFSET (RECOMMENDED - no timezone issues!)
-- Use the values from STEP 2B query above:
-- Pick a negative number BETWEEN secs_since_damage and secs_since_insert
-- Example: If secs_since_insert=1200, secs_since_damage=300, use OFFSET => -600
CREATE OR REPLACE TABLE orders_recovered CLONE orders 
AT(OFFSET => -1600);  -- ← CHANGE THIS based on your STEP 2B results!



-- Verify recovered data - should show all 5 original columns
DESC TABLE orders_recovered;
SELECT * FROM orders_recovered;
-- 📸 SCREENSHOT #3: 03_recovery_success.png (all 5 columns restored!)

-- 📸 SCREENSHOT #5: 05_clone_success.png - Run a fresh clone to capture success:
-- CREATE TABLE orders_clone_screenshot CLONE orders AT(OFFSET => -60);

/*
--------------------------------------------------------------------------------
STEP 4: Replace Corrupted Table with Recovered Table
--------------------------------------------------------------------------------
*/

-- Option A: Swap names (keeps audit trail)
ALTER TABLE orders RENAME TO orders_corrupted;
ALTER TABLE orders_recovered RENAME TO orders;

-- Verify recovery
DESC TABLE orders;
SELECT * FROM orders;

/*
--------------------------------------------------------------------------------
STEP 5: Handle Any New Data (If Applicable)
--------------------------------------------------------------------------------
If data was inserted into corrupted table AFTER the incident,
migrate those records to the recovered table.
--------------------------------------------------------------------------------
*/

-- Check if corrupted table has data not in recovered table
SELECT 'DATA IN CORRUPTED TABLE (may need migration):' AS status;
SELECT * FROM orders_corrupted;

-- Example: Migrate new records (adjust columns based on what existed)
-- INSERT INTO orders (order_id, amount)
-- SELECT order_id, amount FROM orders_corrupted
-- WHERE order_id NOT IN (SELECT order_id FROM orders);

/*
--------------------------------------------------------------------------------
STEP 6: Add the Originally Intended Column (Correctly This Time)
--------------------------------------------------------------------------------
*/

ALTER TABLE orders ADD COLUMN priority STRING;

-- Verify final structure - should show 6 columns now
DESC TABLE orders;
SELECT * FROM orders;

/*
--------------------------------------------------------------------------------
STEP 7: Cleanup
--------------------------------------------------------------------------------
*/

-- Drop corrupted table once recovery is verified
--DROP TABLE IF EXISTS orders_corrupted;

-- Verify final state
SHOW TABLES LIKE 'orders%';

/*
================================================================================
RECOVERY SUMMARY:
================================================================================
For CREATE OR ALTER TABLE data loss:

1. Find the timestamp BEFORE the destructive change (ACCOUNT_USAGE.QUERY_HISTORY)
2. CLONE the table from that timestamp: 
   CREATE TABLE recovered CLONE table AT(TIMESTAMP => '...')
3. Rename corrupted table, rename recovered table to original name
4. Migrate any new data if needed
5. Add the column correctly: ALTER TABLE ADD COLUMN
6. Cleanup corrupted table

================================================================================
WHY UNDROP DOES NOT WORK:
================================================================================
- CREATE OR REPLACE TABLE: Drops table, creates new → UNDROP works
- CREATE OR ALTER TABLE: Modifies in place → UNDROP does NOT work

CREATE OR ALTER keeps the same table object but removes columns.
The table was never dropped, so there's nothing to UNDROP.
Must use Time Travel (CLONE AT or SELECT AT) to recover data.

================================================================================
COMMON ISSUES:
================================================================================
- "Table did not exist or was purged": Time Travel expired OR used UNDROP 
  for CREATE OR ALTER (wrong method - use CLONE instead)
- "Insufficient privileges": Need ACCOUNTADMIN or object ownership
- No data in CLONE: Timestamp was after the destructive change, try earlier

================================================================================
*/
