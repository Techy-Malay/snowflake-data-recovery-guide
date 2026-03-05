# LinkedIn Post 1: The Hidden Danger of CREATE OR ALTER TABLE

> **Author:** Malaya Kumar Padhi (Malay)  
> Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)  
> **Series:** Snowflake Data Recovery Guide (Post 1 of 3)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22

---

**The Snowflake command that can silently destroy your data**

Last week, a developer wanted to add a column to a production table.

They wrote:
```sql
CREATE OR ALTER TABLE orders (
  id INT, 
  amount NUMBER, 
  new_col STRING
);
```

They should have written:
```sql
ALTER TABLE orders ADD COLUMN new_col STRING;
```

The result: 3 columns of production data—gone. No warning. No confirmation.

**What happened?**

`CREATE OR ALTER TABLE` doesn't "modify" a table. It *replaces* the entire definition.

Any column not in the new definition is dropped. Silently.

**The recovery problem:**

The developer tried to run `UNDROP TABLE`. Access denied.

Why? UNDROP requires SYSADMIN or equivalent privileges. Their role didn't have it.

They had to escalate to an admin, who recovered the data via Time Travel—but only because we caught it within 24 hours.

**Key takeaways:**

1. `CREATE OR ALTER` is not a safe "upsert" for table schemas
2. Always use `ALTER TABLE ADD COLUMN` for adding columns
3. UNDROP requires elevated privileges—regular users can't self-recover
4. Time Travel has limits (default: 1 day). After that, data is gone.

This is why RBAC matters. Restrict CREATE TABLE to admin roles. Grant developers ALTER only.

The privilege separation isn't bureaucracy—it's a guardrail.

---

**Suggested hashtags:**
#Snowflake #DataEngineering #CloudData #DataGovernance #RBAC #DataRecovery #SolutionArchitecture

**Suggested post format:** Text post with code snippet image

**Character count:** ~1,400 (within LinkedIn limit)

---
