# LinkedIn Post 3: Preventing CREATE OR ALTER TABLE Disasters with RBAC

> **Author:** Malaya Kumar Padhi (Malay)  
> Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)  
> **Series:** Snowflake Data Recovery Guide (Post 3 of 3)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22

---

**Stop fixing data loss. Start preventing it.**

This is Part 3 of my series on `CREATE OR ALTER TABLE` data loss in Snowflake.

Part 1: The danger
Part 2: The recovery
Part 3: The prevention (this post)

**The core insight:**

`CREATE OR ALTER TABLE` requires the CREATE TABLE privilege.

`ALTER TABLE ADD COLUMN` requires only the ALTER privilege.

If you don't grant CREATE, developers can't accidentally replace table definitions.

**The RBAC architecture:**

```
| Role           | CREATE | ALTER | DROP | SELECT/DML |
|----------------|--------|-------|------|------------|
| DATA_DDL_ADMIN | ✅     | ✅    | ✅   | ✅         |
| DATA_DEVELOPER | ❌     | ✅    | ❌   | ✅         |
| DATA_ANALYST   | ❌     | ❌    | ❌   | ✅ SELECT  |
```

**Implementation:**

```sql
-- Developer role: ALTER only, no CREATE
GRANT USAGE ON DATABASE prod_db TO ROLE data_developer;
GRANT USAGE ON SCHEMA prod_db.sales TO ROLE data_developer;
GRANT ALTER ON TABLE prod_db.sales.orders TO ROLE data_developer;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE prod_db.sales.orders TO ROLE data_developer;

-- Note: No GRANT CREATE TABLE
```

**What this prevents:**

```sql
-- As DATA_DEVELOPER role:

-- ✅ This works
ALTER TABLE orders ADD COLUMN priority STRING;

-- ❌ This fails (no CREATE privilege)
CREATE OR ALTER TABLE orders (id INT, amount NUMBER);
-- Error: Insufficient privileges
```

**The principle:**

Developers need to modify tables. They rarely need to replace them.

Grant the minimum privilege for the job. ALTER does the job. CREATE enables the accident.

**Additional guardrails:**

1. Extend Time Travel: `SET DATA_RETENTION_TIME_IN_DAYS = 30`
2. Require PR review for DDL changes in CI/CD
3. Monitor DDL via ACCESS_HISTORY

Prevention costs minutes. Recovery costs hours—and sometimes data.

---

**Suggested hashtags:**
#Snowflake #RBAC #DataGovernance #DataSecurity #CloudArchitecture #LeastPrivilege #DataEngineering

**Suggested post format:** Text post with privilege matrix image

**Character count:** ~1,450 (within LinkedIn limit)

---
