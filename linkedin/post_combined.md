# LinkedIn Post: Complete Guide (Single Post)

> **Author:** Malaya Kumar Padhi (Malay)  
> Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22

---

## Post Content (Copy below line for LinkedIn)

---

🔴 **The Snowflake command that silently destroyed production data**

A developer wanted to add a column. They wrote:

```
CREATE OR ALTER TABLE orders (id INT, amount NUMBER, new_col STRING);
```

They should have written:

```
ALTER TABLE orders ADD COLUMN new_col STRING;
```

Result: 3 columns of data—gone. No warning.

**What happened?**

`CREATE OR ALTER TABLE` doesn't "add" columns. It REPLACES the entire definition. Omitted columns are silently dropped.

**The recovery:**

```
-- Clone from before the damage
CREATE TABLE orders_recovered CLONE orders 
AT(TIMESTAMP => '2024-01-15 10:00:00');

-- Swap tables
ALTER TABLE orders RENAME TO orders_corrupted;
ALTER TABLE orders_recovered RENAME TO orders;
```

⚠️ Note: `UNDROP TABLE` won't work here—the table wasn't dropped, just modified in place.

**Prevention:**

Grant developers ALTER privilege only, not CREATE. Without CREATE, they can't run `CREATE OR ALTER`.

**Key insight:**

| Command | Safe? |
|---------|-------|
| CREATE OR ALTER | ❌ Dangerous |
| ALTER TABLE ADD COLUMN | ✅ Safe |

Full guide with SQL scripts: github.com/Techy-Malay/snowflake-data-recovery-guide

#Snowflake #DataEngineering #DataRecovery #CloudData #DataArchitecture

---

## Post Stats

- **Character count:** ~1,150 (within LinkedIn's 3,000 limit)
- **Format:** Text with code blocks
- **Recommended:** Add screenshot showing before/after data

---
