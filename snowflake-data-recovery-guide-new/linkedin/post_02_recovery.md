# LinkedIn Post 2: Recovering from CREATE OR ALTER TABLE Data Loss

> **Author:** Malaya Kumar Padhi (Malay)  
> Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)  
> **Series:** Snowflake Data Recovery Guide (Post 2 of 3)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22

---

**How to recover when CREATE OR ALTER TABLE drops your columns**

Following my last post about the hidden danger of `CREATE OR ALTER TABLE`—here's the recovery playbook.

**Prerequisites:**
- Time Travel must still be available (default: 1 day retention)
- You need ACCOUNTADMIN or ownership on the affected objects

**Critical insight:**

`CREATE OR ALTER TABLE` modifies the table **in place**—it doesn't drop it.

This means `UNDROP TABLE` will NOT work. You must use **Time Travel CLONE**.

**The recovery process:**

```sql
-- 1. Find a valid recovery timestamp
--    (after table creation, before the destructive change)
SELECT QUERY_TEXT, START_TIME
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TEXT ILIKE 'CREATE OR ALTER TABLE orders%'
ORDER BY START_TIME DESC LIMIT 1;

-- 2. Clone table from BEFORE the damage
CREATE TABLE orders_recovered CLONE orders 
AT(TIMESTAMP => '2024-01-15 10:29:00'::TIMESTAMP);

-- 3. Verify recovery (should show all original columns)
SELECT * FROM orders_recovered;

-- 4. Swap tables
ALTER TABLE orders RENAME TO orders_corrupted;
ALTER TABLE orders_recovered RENAME TO orders;

-- 5. Add your column correctly
ALTER TABLE orders ADD COLUMN new_col STRING;

-- 6. Cleanup
DROP TABLE orders_corrupted;
```

**Why CLONE instead of UNDROP?**

`CREATE OR ALTER` modifies the existing table—it doesn't drop and recreate it.

Since the table was never dropped, there's nothing to UNDROP. The data exists in Time Travel history, accessible via `CLONE AT` or `SELECT AT`.

**What if Time Travel expired?**

You have two options:
1. Restore from external backup (if you have one)
2. Accept the loss

This is why I recommend extending Time Travel for critical tables:

```sql
ALTER TABLE orders 
SET DATA_RETENTION_TIME_IN_DAYS = 30;
```

**Common errors:**

- "Time travel data not available" → Timestamp before table creation or after retention
- "Insufficient privileges" → Need ACCOUNTADMIN or object ownership

Save this. You'll need it at 2 AM someday.

---

**Suggested hashtags:**
#Snowflake #DataRecovery #TimeTravel #DataEngineering #IncidentResponse #CloudData

**Suggested post format:** Text post with SQL code image or carousel

**Character count:** ~1,500 (within LinkedIn limit)

---
