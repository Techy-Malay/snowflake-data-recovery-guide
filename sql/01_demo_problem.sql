/*
================================================================================
File:        01_demo_problem.sql
Purpose:     Demonstrates the CREATE OR ALTER TABLE pitfall causing data loss
Author:      Malaya Padhi (Malay)
Repository:  https://github.com/Techy-Malay/snowflake-data-recovery-guide
Created:     2026-02-22
Modified:    2026-02-22
--------------------------------------------------------------------------------
Context:     
This script is part of a LinkedIn content series on Snowflake data recovery.
It demonstrates a common mistake where users attempt to add a column using
CREATE OR ALTER TABLE but accidentally omit existing columns, causing silent
data loss. Run this script FIRST to simulate the problem, then use Script 02
to recover the data.

Prerequisites:
- Snowflake account with ACCOUNTADMIN or SYSADMIN role
- A sandbox/test environment (this script creates test objects)

Execution Order: 1 of 3 (Demo → Recovery → Prevention)
================================================================================
WARNING: This script demonstrates data loss. Use a sandbox environment.

EXECUTION INSTRUCTIONS:
- Run Step 1-3 first (setup + insert + verify)
- WAIT 1-2 minutes (allows Time Travel window)
- Note the timestamp from Step 3
- Then run Step 4 (the destructive command)
- Use the noted timestamp for recovery in Script 02
================================================================================
*/

-- Setup: Create demo database and schema
CREATE DATABASE IF NOT EXISTS DATA_RECOVERY_DEMO;
USE DATABASE DATA_RECOVERY_DEMO;
CREATE SCHEMA IF NOT EXISTS DEMO;
USE SCHEMA DEMO;

/*
--------------------------------------------------------------------------------
SCENARIO: User wants to add a new column to an existing table
--------------------------------------------------------------------------------
*/

-- Step 1: Create original table with data
CREATE OR REPLACE TABLE orders (
    order_id        INT,
    customer_name   STRING,
    order_date      DATE,
    amount          NUMBER(10,2),
    status          STRING
);

-- Step 2: Insert sample data
INSERT INTO orders VALUES
    (1, 'Acme Corp',      '2024-01-15', 15000.00, 'COMPLETED'),
    (2, 'TechStart Inc',  '2024-01-16', 8500.50,  'PENDING'),
    (3, 'Global Services','2024-01-17', 22000.00, 'COMPLETED'),
    (4, 'DataDriven LLC', '2024-01-18', 5000.00,  'SHIPPED');

-- Step 3: Verify original data (5 columns, 4 rows)
SELECT 'BEFORE - Original table structure and data:' AS status;
SELECT * FROM orders;
-- 📸 SCREENSHOT #1: 01_before_data.png (capture the 5 columns above)
SELECT COUNT(*) AS row_count FROM orders;

-- ============================================================================
-- IMPORTANT: Note this timestamp for recovery!
-- ============================================================================
SELECT CURRENT_TIMESTAMP() AS recovery_point_timestamp;
-- SAVE THIS TIMESTAMP! You will need it for Script 02 recovery.
-- Example: 2026-03-05 09:15:00.123 -0800 (yours will be different)

-- ############################################################################
-- #                                                                          #
-- #   ⏸️  PAUSE HERE! WAIT 2-3 MINUTES BEFORE CONTINUING!                    #
-- #                                                                          #
-- #   📸 Take Screenshot: 01_before_data.png (SELECT * FROM orders above)    #
-- #   ✍️  COPY THE TIMESTAMP ABOVE - You need it for recovery!               #
-- #                                                                          #
-- #   This wait creates a Time Travel window for recovery.                   #
-- #                                                                          #
-- ############################################################################

/*
--------------------------------------------------------------------------------
THE MISTAKE: Using CREATE OR ALTER to "add" a column
--------------------------------------------------------------------------------
User's intention: Add a 'priority' column
User's action: Rewrote table definition but FORGOT existing columns
--------------------------------------------------------------------------------
*/

-- ⚠️ DANGER ZONE - This will cause DATA LOSS!
-- WRONG APPROACH: This DROPS columns not in the new definition!
CREATE OR ALTER TABLE orders (
    order_id    INT,
    amount      NUMBER(10,2),
    priority    STRING           -- New column user wanted to add
);
-- RESULT: customer_name, order_date, status columns are GONE

-- Step 4: Check the damage
SELECT 'AFTER - Table structure after CREATE OR ALTER:' AS status;
SELECT * FROM orders;
-- 📸 SCREENSHOT #2: 02_after_data_loss.png (only 3 columns - data LOST!)
DESC TABLE orders;

/*
--------------------------------------------------------------------------------
WHAT HAPPENED:
- CREATE OR ALTER replaced the entire table definition
- Columns not in new definition (customer_name, order_date, status) were DROPPED
- Data in those columns is LOST (unless recovered via Time Travel)
- No warning, no confirmation, silent data loss
--------------------------------------------------------------------------------
*/

/*
--------------------------------------------------------------------------------
THE CORRECT APPROACH: Use ALTER TABLE ADD COLUMN
--------------------------------------------------------------------------------
*/

-- Reset for correct demonstration
CREATE OR REPLACE TABLE orders_correct (
    order_id        INT,
    customer_name   STRING,
    order_date      DATE,
    amount          NUMBER(10,2),
    status          STRING
);

INSERT INTO orders_correct VALUES
    (1, 'Acme Corp',      '2024-01-15', 15000.00, 'COMPLETED'),
    (2, 'TechStart Inc',  '2024-01-16', 8500.50,  'PENDING'),
    (3, 'Global Services','2024-01-17', 22000.00, 'COMPLETED'),
    (4, 'DataDriven LLC', '2024-01-18', 5000.00,  'SHIPPED');

-- RIGHT APPROACH: ALTER TABLE preserves existing columns
ALTER TABLE orders_correct ADD COLUMN priority STRING;

-- Verify: All original columns preserved + new column added
SELECT 'CORRECT - Using ALTER TABLE ADD COLUMN:' AS status;
SELECT * FROM orders_correct;
DESC TABLE orders_correct;

/*
--------------------------------------------------------------------------------
KEY TAKEAWAYS:
1. CREATE OR ALTER TABLE is NOT a safe "modify" operation
2. It REPLACES the table definition entirely
3. Omitted columns are SILENTLY dropped
4. Always use ALTER TABLE for adding/modifying columns
5. Recovery requires Time Travel + elevated privileges (SYSADMIN)
--------------------------------------------------------------------------------
*/

-- Cleanup (optional)
--DROP DATABASE DATA_RECOVERY_DEMO;
