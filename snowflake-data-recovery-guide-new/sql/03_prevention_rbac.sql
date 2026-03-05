/*
================================================================================
File:        03_prevention_rbac.sql
Purpose:     RBAC guardrails to prevent CREATE OR ALTER TABLE accidents
Author:      Malaya Padhi (Malay)
Repository:  https://github.com/Techy-Malay/snowflake-data-recovery-guide
Created:     2026-02-22
Modified:    2026-02-22
--------------------------------------------------------------------------------
Context:     
This script is part of a LinkedIn content series on Snowflake data recovery.
After understanding the problem (Script 01) and recovery (Script 02), this
script implements preventive RBAC controls. The key principle: restrict 
CREATE TABLE privileges to admin roles, grant only ALTER TABLE to developers.

Since CREATE OR ALTER TABLE requires CREATE privilege, developers without
CREATE privilege can only use ALTER TABLE ADD COLUMN (safe operation) and
cannot accidentally run CREATE OR ALTER (dangerous operation).

Prerequisites:
- SECURITYADMIN or ACCOUNTADMIN role for creating roles and grants
- Understanding of your organization's role hierarchy

Execution Order: 3 of 3 (Demo → Recovery → Prevention)
================================================================================
Principle: Restrict CREATE TABLE to admin roles, grant ALTER TABLE to developers
================================================================================
*/

USE ROLE SECURITYADMIN;

/*
--------------------------------------------------------------------------------
RBAC STRATEGY: Separation of DDL Privileges
--------------------------------------------------------------------------------
CREATE TABLE  → Can replace/destroy table definitions (DANGEROUS)
ALTER TABLE   → Can only modify existing tables safely (SAFE)

Solution: Developers get ALTER, not CREATE
--------------------------------------------------------------------------------
*/

/*
--------------------------------------------------------------------------------
STEP 1: Create Role Hierarchy
--------------------------------------------------------------------------------
*/

-- Admin role: Full DDL control (restricted membership)
CREATE ROLE IF NOT EXISTS DATA_DDL_ADMIN;
COMMENT ON ROLE DATA_DDL_ADMIN IS 'Full DDL privileges - CREATE, DROP, ALTER';

-- Developer role: Safe DDL only (broader membership)
CREATE ROLE IF NOT EXISTS DATA_DEVELOPER;
COMMENT ON ROLE DATA_DEVELOPER IS 'Limited DDL - ALTER only, no CREATE/DROP';

-- Analyst role: Read-only (widest membership)
CREATE ROLE IF NOT EXISTS DATA_ANALYST;
COMMENT ON ROLE DATA_ANALYST IS 'Read-only access to production data';

-- Role hierarchy: SYSADMIN → DDL_ADMIN → DEVELOPER → ANALYST
GRANT ROLE DATA_ANALYST TO ROLE DATA_DEVELOPER;
GRANT ROLE DATA_DEVELOPER TO ROLE DATA_DDL_ADMIN;
GRANT ROLE DATA_DDL_ADMIN TO ROLE SYSADMIN;

/*
--------------------------------------------------------------------------------
STEP 2: Setup Demo Environment
--------------------------------------------------------------------------------
*/

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS PRODUCTION_DB;
CREATE SCHEMA IF NOT EXISTS PRODUCTION_DB.SALES;

-- Create sample production table
CREATE OR REPLACE TABLE PRODUCTION_DB.SALES.ORDERS (
    order_id        INT,
    customer_name   STRING,
    order_date      DATE,
    amount          NUMBER(10,2),
    status          STRING
);

/*
--------------------------------------------------------------------------------
STEP 3: Grant Privileges - DDL Admin Role
--------------------------------------------------------------------------------
Full control: CREATE, DROP, ALTER (restricted to senior engineers)
--------------------------------------------------------------------------------
*/

USE ROLE SECURITYADMIN;

GRANT USAGE ON DATABASE PRODUCTION_DB TO ROLE DATA_DDL_ADMIN;
GRANT USAGE ON SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DDL_ADMIN;
GRANT CREATE TABLE ON SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DDL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DDL_ADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DDL_ADMIN;

/*
--------------------------------------------------------------------------------
STEP 4: Grant Privileges - Developer Role
--------------------------------------------------------------------------------
Limited DDL: ALTER only (cannot CREATE OR ALTER, cannot DROP)
--------------------------------------------------------------------------------
*/

GRANT USAGE ON DATABASE PRODUCTION_DB TO ROLE DATA_DEVELOPER;
GRANT USAGE ON SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DEVELOPER;

-- KEY: Grant ALTER but NOT CREATE
-- This allows: ALTER TABLE ... ADD COLUMN
-- This blocks: CREATE OR ALTER TABLE (requires CREATE privilege)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DEVELOPER;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_DEVELOPER;

-- Grant ALTER on specific tables (explicit, auditable)
GRANT ALTER ON TABLE PRODUCTION_DB.SALES.ORDERS TO ROLE DATA_DEVELOPER;

/*
--------------------------------------------------------------------------------
STEP 5: Grant Privileges - Analyst Role
--------------------------------------------------------------------------------
Read-only: SELECT only
--------------------------------------------------------------------------------
*/

GRANT USAGE ON DATABASE PRODUCTION_DB TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA PRODUCTION_DB.SALES TO ROLE DATA_ANALYST;

/*
--------------------------------------------------------------------------------
STEP 6: Assign Users to Roles
--------------------------------------------------------------------------------
*/

-- Example user assignments (replace with actual usernames)
-- GRANT ROLE DATA_DDL_ADMIN TO USER senior_engineer;
-- GRANT ROLE DATA_DEVELOPER TO USER developer1;
-- GRANT ROLE DATA_DEVELOPER TO USER developer2;
-- GRANT ROLE DATA_ANALYST TO USER analyst1;

/*
--------------------------------------------------------------------------------
STEP 7: Verification - Test the Guardrails
--------------------------------------------------------------------------------
*/

-- Test as DEVELOPER role
USE ROLE DATA_DEVELOPER;
USE DATABASE PRODUCTION_DB;
USE SCHEMA SALES;

-- This WORKS: ALTER TABLE ADD COLUMN (safe operation)
ALTER TABLE ORDERS ADD COLUMN IF NOT EXISTS region STRING;

-- This FAILS: CREATE OR ALTER (requires CREATE privilege)
-- Uncomment to test:
-- CREATE OR ALTER TABLE ORDERS (order_id INT, amount NUMBER);
-- Error: "Insufficient privileges to operate on schema 'SALES'"

-- This FAILS: DROP TABLE (not granted)
-- DROP TABLE ORDERS;
-- Error: "Insufficient privileges"

/*
--------------------------------------------------------------------------------
STEP 8: Verify Privilege Configuration
--------------------------------------------------------------------------------
*/

USE ROLE SECURITYADMIN;

-- Show grants on the table
SHOW GRANTS ON TABLE PRODUCTION_DB.SALES.ORDERS;

-- Show grants to each role
SHOW GRANTS TO ROLE DATA_DDL_ADMIN;
SHOW GRANTS TO ROLE DATA_DEVELOPER;
SHOW GRANTS TO ROLE DATA_ANALYST;

/*
--------------------------------------------------------------------------------
PREVENTION SUMMARY:
--------------------------------------------------------------------------------
| Role            | CREATE TABLE | ALTER TABLE | DROP TABLE | SELECT/DML |
|-----------------|--------------|-------------|------------|------------|
| DATA_DDL_ADMIN  | YES          | YES         | YES        | YES        |
| DATA_DEVELOPER  | NO           | YES         | NO         | YES        |
| DATA_ANALYST    | NO           | NO          | NO         | SELECT     |
--------------------------------------------------------------------------------

KEY INSIGHT:
- CREATE OR ALTER requires CREATE TABLE privilege
- Without CREATE, developers can only use ALTER TABLE (safe)
- This prevents accidental table definition replacement
--------------------------------------------------------------------------------
*/

/*
--------------------------------------------------------------------------------
ADDITIONAL GUARDRAILS (Optional)
--------------------------------------------------------------------------------
*/

-- Extend Time Travel for critical tables (max 90 days for Enterprise+)
-- ALTER TABLE PRODUCTION_DB.SALES.ORDERS SET DATA_RETENTION_TIME_IN_DAYS = 30;

-- Enable change tracking for audit
-- ALTER TABLE PRODUCTION_DB.SALES.ORDERS SET CHANGE_TRACKING = TRUE;

-- Create a DDL audit view using ACCESS_HISTORY
-- SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
-- WHERE QUERY_TEXT ILIKE '%CREATE%TABLE%' OR QUERY_TEXT ILIKE '%ALTER%TABLE%'
-- ORDER BY QUERY_START_TIME DESC;
