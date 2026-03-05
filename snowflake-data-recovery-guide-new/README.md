# Snowflake Data Recovery Guide: CREATE OR ALTER TABLE Pitfall

[![Snowflake](https://img.shields.io/badge/Snowflake-Data%20Recovery-29B5E8)](https://www.snowflake.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/Techy-Malay/snowflake-data-recovery-guide?style=social)](https://github.com/Techy-Malay/snowflake-data-recovery-guide)

> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22  
> **Author:** Malaya Kumar Padhi (Malay)

⭐ **If this helps you, please star the repository!**

---

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [Recovery Requirements](#recovery-requirements)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Recovery Process](#recovery-process-high-level)
- [Prevention](#prevention)
- [Testing](#testing)
- [Key Learnings](#key-learnings)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [Author](#author)
- [License](#license)

---

## Overview

This repository documents a critical Snowflake pitfall where `CREATE OR ALTER TABLE` can silently drop columns, causing unexpected data loss—and how to recover from it.

## The Problem

```sql
-- User intended to add a column
-- WRONG: Omitting existing columns causes data loss
CREATE OR ALTER TABLE orders (id INT, amount NUMBER, new_col STRING);

-- RIGHT: Use ALTER TABLE to add columns safely
ALTER TABLE orders ADD COLUMN new_col STRING;
```

**Key Insight**: `CREATE OR ALTER TABLE` replaces the table definition. Any columns not included in the new definition are **permanently dropped**.

## Recovery Requirements

- **Time Travel** must still be available (default: 1 day retention)
- **ACCOUNTADMIN** or role with object ownership required
- Must find a valid timestamp between table creation and the destructive change

## Repository Structure

```
├── sql/
│   ├── 01_demo_problem.sql      # Demonstrates the pitfall
│   ├── 02_recovery_steps.sql    # Time Travel CLONE recovery
│   └── 03_prevention_rbac.sql   # RBAC guardrails
├── tests/
│   └── test_scenarios.sql       # End-to-end validation script
├── linkedin/
│   ├── post_01_danger.md        # The hidden danger
│   ├── post_02_recovery.md      # Recovery process
│   └── post_03_prevention.md    # Prevention architecture
├── diagrams/
│   └── recovery_flow.md         # Mermaid: Recovery flow
└── LICENSE
```

## Quick Start

1. Review `sql/01_demo_problem.sql` to understand the pitfall
2. Use `sql/02_recovery_steps.sql` if you need to recover data
3. Implement `sql/03_prevention_rbac.sql` to prevent future incidents

## Recovery Process (High-Level)

1. **Find** a valid recovery timestamp (after table creation, before damage)
2. **Clone** the table from that timestamp: `CLONE orders AT(TIMESTAMP => '...')`
3. **Rename** corrupted table, rename recovered table to original name
4. **Add** the column correctly: `ALTER TABLE ADD COLUMN`
5. **Drop** the corrupted table

## Prevention

- Restrict `CREATE TABLE` privileges to admin roles
- Grant only `ALTER TABLE` to developers
- Implement CI/CD review for DDL changes

## Testing

Run the end-to-end test script to validate all scenarios in your environment:

```sql
-- Requires ACCOUNTADMIN or SYSADMIN role
-- Run: tests/test_scenarios.sql
```

**Test Coverage:**

| Test | Scenario | Expected Result |
|------|----------|-----------------|
| 1 | CREATE OR ALTER drops columns | 5 cols → 3 cols |
| 2 | Time Travel CLONE recovery | 5 cols restored |
| 2b | Data integrity after recovery | Original data preserved |
| 3 | ALTER TABLE ADD COLUMN (safe) | 5 cols → 6 cols |
| 3b | Data preservation (safe method) | Original data intact |
| 4a | Developer can ALTER | Success |
| 4b | Developer blocked from CREATE OR ALTER | Fails (as expected) |

All tests output ✅ PASS or ❌ FAIL for easy validation.

## Key Learnings

### Command Behavior Comparison

| Command | What It Does | Table Dropped? | Recovery Method |
|---------|--------------|----------------|-----------------|
| `CREATE OR REPLACE TABLE` | Drops and recreates table | YES | `UNDROP TABLE` |
| `CREATE OR ALTER TABLE` | Modifies table in place | NO | `CLONE AT(TIMESTAMP)` |
| `ALTER TABLE ADD COLUMN` | Adds column safely | NO | N/A (safe operation) |

### Critical Insights

1. **CREATE OR ALTER is NOT a safe "upsert"** - It replaces the entire table definition
2. **Omitted columns are silently dropped** - No warning, no confirmation
3. **UNDROP won't work** - Because the table isn't dropped, just modified
4. **Time Travel CLONE is the solution** - Clone from before the destructive change
5. **Privilege separation prevents accidents** - Developers with only ALTER privilege cannot run CREATE OR ALTER

### When This Mistake Happens

- Developer copies table definition, adds new column, forgets to include all existing columns
- Using IDE auto-complete that doesn't show all columns
- Working from outdated documentation of table structure
- Misunderstanding what "CREATE OR ALTER" actually does

## Troubleshooting

### Common Errors and Solutions

| #   | Error Message                                      | Cause                                    | Solution                                  |
|-----|---------------------------------------------------|------------------------------------------|-------------------------------------------|
| 1   | `Time travel data is not available for table`     | Timestamp before creation or expired     | Use timestamp AFTER table creation        |
| 2   | `Table did not exist or was purged`               | Tried UNDROP (wrong method for this)     | Use `CLONE AT(TIMESTAMP)` instead         |
| 3   | `Insufficient privileges to operate on schema`    | Role lacks required permissions          | Use ACCOUNTADMIN or object owner role     |
| 4   | `Object already exists`                           | Target table name already exists         | Rename corrupted table first              |
| 5   | `Statement cannot be used for time travel`        | Used BEFORE clause with DDL statement    | Use `CLONE AT(TIMESTAMP)` instead         |

### Recovery Checklist

- [ ] Verify Time Travel is still available (check retention period)
- [ ] Find valid timestamp (after INSERT, before CREATE OR ALTER)
- [ ] Use correct role (ACCOUNTADMIN or object owner)
- [ ] Clone table from valid timestamp
- [ ] Verify recovered data before dropping corrupted table

## References

### Official Snowflake Documentation

- [CREATE OR ALTER TABLE](https://docs.snowflake.com/en/sql-reference/sql/create-table#create-or-alter-table) - Official syntax and behavior
- [Time Travel](https://docs.snowflake.com/en/user-guide/data-time-travel) - Understanding data recovery windows
- [CLONE](https://docs.snowflake.com/en/sql-reference/sql/create-clone) - Creating zero-copy clones
- [UNDROP TABLE](https://docs.snowflake.com/en/sql-reference/sql/undrop-table) - When and how UNDROP works
- [Access Control Privileges](https://docs.snowflake.com/en/user-guide/security-access-control-privileges) - Understanding CREATE vs ALTER privileges

### Related Concepts

- [Data Retention Period](https://docs.snowflake.com/en/user-guide/data-time-travel#data-retention-period) - How long Time Travel data is available
- [Role-Based Access Control](https://docs.snowflake.com/en/user-guide/security-access-control-overview) - Implementing least-privilege access

## Author

**Malaya Kumar Padhi (Malay)**  
Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)](https://www.linkedin.com/in/mkpadhi/)

## License

MIT License - See [LICENSE](LICENSE)
