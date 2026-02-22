/*
================================================================================
File:        test_scenarios.sql
Purpose:     End-to-end validation script with PASS/FAIL output
Author:      Malaya Padhi (Malay)
Repository:  https://github.com/Techy-Malay/snowflake-data-recovery-guide
Created:     2026-02-22
Modified:    2026-02-22
--------------------------------------------------------------------------------
Context:     
This script validates all scenarios demonstrated in the LinkedIn content series.
Run this script to verify the concepts work in your Snowflake environment.
It tests: (1) CREATE OR ALTER drops columns, (2) Time Travel CLONE recovery,
(3) ALTER TABLE ADD COLUMN preserves data, (4) RBAC prevents unauthorized DDL.

All tests output PASS or FAIL for easy validation. The script creates its own
test database and cleans up after execution.

Prerequisites:
- ACCOUNTADMIN or SYSADMIN role for full test coverage
- No dependency on other scripts (self-contained)

Execution: Optional - Run anytime to validate concepts
================================================================================
PURPOSE: Validates all scenarios with PASS/FAIL output
REQUIREMENTS: ACCOUNTADMIN or SYSADMIN role for full test coverage
================================================================================
*/

USE ROLE ACCOUNTADMIN;

-- Setup test environment
CREATE DATABASE IF NOT EXISTS DATA_RECOVERY_TEST;
USE DATABASE DATA_RECOVERY_TEST;
CREATE SCHEMA IF NOT EXISTS TEST_SCHEMA;
USE SCHEMA TEST_SCHEMA;

/*
================================================================================
TEST 1: Demonstrate CREATE OR ALTER Drops Columns
================================================================================
Expected: Column count reduces from 5 to 3 after CREATE OR ALTER
*/

-- Setup
CREATE OR REPLACE TABLE test_orders (
    order_id        INT,
    customer_name   STRING,
    order_date      DATE,
    amount          NUMBER(10,2),
    status          STRING
);

INSERT INTO test_orders VALUES (1, 'Test Corp', '2024-01-15', 1000.00, 'ACTIVE');

-- Capture before state
SET before_cols = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'TEST_ORDERS' AND TABLE_SCHEMA = 'TEST_SCHEMA');

-- Execute the problematic command
CREATE OR ALTER TABLE test_orders (
    order_id    INT,
    amount      NUMBER(10,2),
    new_col     STRING
);

-- Capture after state
SET after_cols = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'TEST_ORDERS' AND TABLE_SCHEMA = 'TEST_SCHEMA');

-- Validate
SELECT 
    'TEST 1: CREATE OR ALTER Drops Columns' AS test_name,
    $before_cols AS columns_before,
    $after_cols AS columns_after,
    CASE 
        WHEN $before_cols = 5 AND $after_cols = 3 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result,
    'Expected: 5 cols → 3 cols (customer_name, order_date, status dropped)' AS description;

/*
================================================================================
TEST 2: Demonstrate Time Travel CLONE Recovery
================================================================================
Expected: After recovery using CLONE AT(TIMESTAMP), original 5 columns are restored
NOTE: UNDROP does NOT work for CREATE OR ALTER (table is modified in place, not dropped)
*/

-- Step 1: Get timestamp from before the CREATE OR ALTER
SET recovery_ts = (SELECT DATEADD('minute', -1, CURRENT_TIMESTAMP()));

-- Step 2: Clone table from before the destructive change
CREATE OR REPLACE TABLE test_orders_recovered CLONE test_orders AT(TIMESTAMP => $recovery_ts);

-- Capture recovered state
SET recovered_cols = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                      WHERE TABLE_NAME = 'TEST_ORDERS_RECOVERED' AND TABLE_SCHEMA = 'TEST_SCHEMA');

-- Validate
SELECT 
    'TEST 2: Time Travel CLONE Recovery' AS test_name,
    $recovered_cols AS columns_after_recovery,
    CASE 
        WHEN $recovered_cols = 5 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result,
    'Expected: 5 cols restored via CLONE AT(TIMESTAMP)' AS description;

-- Verify data integrity
SELECT 
    'TEST 2b: Data Integrity Check' AS test_name,
    COUNT(*) AS row_count,
    MAX(customer_name) AS sample_customer,
    CASE 
        WHEN COUNT(*) = 1 AND MAX(customer_name) = 'Test Corp' THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result,
    'Expected: 1 row with customer_name = Test Corp' AS description
FROM test_orders_recovered;

-- Cleanup test 2
DROP TABLE IF EXISTS test_orders_recovered;
DROP TABLE IF EXISTS test_orders;

/*
================================================================================
TEST 3: Demonstrate ALTER TABLE ADD COLUMN (Safe Method)
================================================================================
Expected: Column count increases from 5 to 6, original data preserved
*/

-- Setup
CREATE OR REPLACE TABLE test_orders_safe (
    order_id        INT,
    customer_name   STRING,
    order_date      DATE,
    amount          NUMBER(10,2),
    status          STRING
);

INSERT INTO test_orders_safe VALUES (1, 'Safe Corp', '2024-01-15', 2000.00, 'ACTIVE');

-- Capture before state
SET safe_before = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_NAME = 'TEST_ORDERS_SAFE' AND TABLE_SCHEMA = 'TEST_SCHEMA');

-- Execute safe method
ALTER TABLE test_orders_safe ADD COLUMN priority STRING;

-- Capture after state
SET safe_after = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'TEST_ORDERS_SAFE' AND TABLE_SCHEMA = 'TEST_SCHEMA');

-- Validate
SELECT 
    'TEST 3: ALTER TABLE ADD COLUMN (Safe)' AS test_name,
    $safe_before AS columns_before,
    $safe_after AS columns_after,
    CASE 
        WHEN $safe_before = 5 AND $safe_after = 6 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result,
    'Expected: 5 cols → 6 cols (priority added, all original preserved)' AS description;

-- Verify original data preserved
SELECT 
    'TEST 3b: Data Preservation Check' AS test_name,
    customer_name,
    CASE 
        WHEN customer_name = 'Safe Corp' THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result,
    'Expected: Original customer_name preserved' AS description
FROM test_orders_safe;

-- Cleanup test 3
DROP TABLE IF EXISTS test_orders_safe;

/*
================================================================================
TEST 4: Demonstrate RBAC Prevention
================================================================================
Expected: Developer role can ALTER but cannot CREATE OR ALTER
================================================================================
*/

-- Setup roles
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS TEST_DEVELOPER_ROLE;
GRANT ROLE TEST_DEVELOPER_ROLE TO ROLE SYSADMIN;

-- Setup permissions
USE ROLE SYSADMIN;
GRANT USAGE ON DATABASE DATA_RECOVERY_TEST TO ROLE TEST_DEVELOPER_ROLE;
GRANT USAGE ON SCHEMA DATA_RECOVERY_TEST.TEST_SCHEMA TO ROLE TEST_DEVELOPER_ROLE;

-- Create test table
CREATE OR REPLACE TABLE DATA_RECOVERY_TEST.TEST_SCHEMA.rbac_test (
    id INT,
    name STRING
);

-- Grant ALTER but NOT CREATE
USE ROLE SECURITYADMIN;
GRANT ALTER ON TABLE DATA_RECOVERY_TEST.TEST_SCHEMA.rbac_test TO ROLE TEST_DEVELOPER_ROLE;
GRANT SELECT ON TABLE DATA_RECOVERY_TEST.TEST_SCHEMA.rbac_test TO ROLE TEST_DEVELOPER_ROLE;

-- Test as developer role
USE ROLE TEST_DEVELOPER_ROLE;
USE DATABASE DATA_RECOVERY_TEST;
USE SCHEMA TEST_SCHEMA;

-- Test 4a: ALTER should succeed
BEGIN
    ALTER TABLE rbac_test ADD COLUMN IF NOT EXISTS test_col STRING;
    SELECT 
        'TEST 4a: Developer Can ALTER' AS test_name,
        '✅ PASS' AS result,
        'ALTER TABLE ADD COLUMN succeeded' AS description;
EXCEPTION
    WHEN OTHER THEN
        SELECT 
            'TEST 4a: Developer Can ALTER' AS test_name,
            '❌ FAIL' AS result,
            'ALTER TABLE should have succeeded' AS description;
END;

-- Test 4b: CREATE OR ALTER should fail
DECLARE
    test_passed BOOLEAN DEFAULT FALSE;
BEGIN
    CREATE OR ALTER TABLE rbac_test (id INT);
EXCEPTION
    WHEN OTHER THEN
        test_passed := TRUE;
END;

SELECT 
    'TEST 4b: Developer Cannot CREATE OR ALTER' AS test_name,
    CASE WHEN test_passed THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
    'CREATE OR ALTER should be blocked without CREATE privilege' AS description;

-- Cleanup
USE ROLE ACCOUNTADMIN;
DROP ROLE IF EXISTS TEST_DEVELOPER_ROLE;

/*
================================================================================
TEST SUMMARY
================================================================================
*/

USE ROLE ACCOUNTADMIN;

SELECT '========================================' AS separator;
SELECT 'TEST EXECUTION COMPLETE' AS status;
SELECT '========================================' AS separator;
SELECT 'Review results above for PASS/FAIL status' AS instruction;

-- Final cleanup
DROP DATABASE IF EXISTS DATA_RECOVERY_TEST;

/*
================================================================================
EXPECTED RESULTS:
--------------------------------------------------------------------------------
TEST 1:  ✅ PASS - CREATE OR ALTER drops columns (5 → 3)
TEST 2:  ✅ PASS - UNDROP restores original (5 cols)
TEST 2b: ✅ PASS - Data integrity preserved
TEST 3:  ✅ PASS - ALTER ADD COLUMN safe (5 → 6)
TEST 3b: ✅ PASS - Original data preserved
TEST 4a: ✅ PASS - Developer can ALTER
TEST 4b: ✅ PASS - Developer blocked from CREATE OR ALTER
================================================================================
*/
