
# Recovery Flow Diagram

> **Author:** Malaya Kumar Padhi (Malay)  
> Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22

---

## Data Recovery Process: CREATE OR ALTER TABLE Incident

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INCIDENT DETECTION                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    User runs CREATE OR ALTER TABLE                                          │
│                    │                                                        │
│                    ▼                                                        │
│    Columns missing from definition                                          │
│                    │                                                        │
│                    ▼                                                        │
│    [!] Data silently dropped                                                │
│                    │                                                        │
│                    ▼                                                        │
│            Incident discovered                                              │
│                                                                             │
└────────────────────┬────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             ASSESSMENT                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│              Time Travel still available?                                   │
│                    │                                                        │
│           ┌───────┴───────┐                                                 │
│           │               │                                                 │
│          NO              YES                                                │
│           │               │                                                 │
│           ▼               ▼                                                 │
│    [X] UNRECOVERABLE    Have ACCOUNTADMIN or                                │
│    Restore from backup  object ownership?                                   │
│                               │                                             │
│                        ┌──────┴──────┐                                      │
│                        │             │                                      │
│                       NO            YES                                     │
│                        │             │                                      │
│                        ▼             │                                      │
│               Request elevated       │                                      │
│               access from admin ─────┘                                      │
│                                                                             │
└────────────────────┬────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           RECOVERY STEPS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    [1] Find valid recovery timestamp                                        │
│        (Query ACCOUNT_USAGE.QUERY_HISTORY)                                  │
│                    │                                                        │
│                    ▼                                                        │
│    [2] CLONE table from BEFORE the damage                                   │
│        CREATE TABLE orders_recovered CLONE orders                           │
│        AT(TIMESTAMP => '...')                                               │
│                    │                                                        │
│                    ▼                                                        │
│    [3] Verify recovered data                                                │
│        SELECT * FROM orders_recovered                                       │
│                    │                                                        │
│                    ▼                                                        │
│    [4] Swap tables                                                          │
│        RENAME orders → orders_corrupted                                     │
│        RENAME orders_recovered → orders                                     │
│                    │                                                        │
│                    ▼                                                        │
│    [5] ALTER TABLE orders ADD COLUMN (correct way)                          │
│                    │                                                        │
│                    ▼                                                        │
│    [6] DROP TABLE orders_corrupted                                          │
│                                                                             │
└────────────────────┬────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           VERIFICATION                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    [✓] Verify column structure (DESC TABLE)                                 │
│                    │                                                        │
│                    ▼                                                        │
│    [✓] Verify row count (SELECT COUNT(*))                                   │
│                    │                                                        │
│                    ▼                                                        │
│    [✓] Verify data integrity (spot check values)                            │
│                    │                                                        │
│                    ▼                                                        │
│    [SUCCESS] Recovery Complete                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

WHY CLONE, NOT UNDROP?
┌─────────────────────────────────────────────────────────────────────────────┐
│  CREATE OR ALTER modifies table IN PLACE - it does NOT drop the table.      │
│  Since the table was never dropped, UNDROP will NOT work.                   │
│  Use Time Travel CLONE to recover data from before the change.              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Mermaid Diagram

```mermaid
flowchart TD
    subgraph INCIDENT["🔴 INCIDENT DETECTION"]
        A[User runs CREATE OR ALTER TABLE] --> B[Columns missing from definition]
        B --> C[Data silently dropped]
        C --> D{Incident discovered}
    end

    subgraph ASSESS["🟡 ASSESSMENT"]
        D --> E{Time Travel<br/>still available?}
        E -->|No| F[❌ Data Unrecoverable<br/>Restore from backup]
        E -->|Yes| G{Have ACCOUNTADMIN<br/>or object ownership?}
        G -->|No| H[Request elevated access<br/>from admin]
        H --> G
        G -->|Yes| I[Proceed with recovery]
    end

    subgraph RECOVER["🟢 RECOVERY STEPS"]
        I --> J["1️⃣ Find valid recovery timestamp"]
        J --> K["2️⃣ CLONE table AT(TIMESTAMP)<br/>CREATE TABLE recovered CLONE orders AT(...)"]
        K --> L["3️⃣ Verify recovered data"]
        L --> M["4️⃣ Swap tables<br/>RENAME orders → corrupted<br/>RENAME recovered → orders"]
        M --> O["5️⃣ ALTER TABLE orders<br/>ADD COLUMN (correct way)"]
        O --> P["6️⃣ DROP TABLE orders_corrupted"]
    end

    subgraph VERIFY["✅ VERIFICATION"]
        P --> Q[Verify column structure]
        Q --> R[Verify row count]
        R --> S[Verify data integrity]
        S --> T[Recovery Complete]
    end

    style A fill:#ff6b6b,color:#fff
    style C fill:#ff6b6b,color:#fff
    style F fill:#ff6b6b,color:#fff
    style T fill:#51cf66,color:#fff
    style J fill:#339af0,color:#fff
    style K fill:#339af0,color:#fff
    style L fill:#339af0,color:#fff
    style M fill:#339af0,color:#fff
    style O fill:#339af0,color:#fff
    style P fill:#339af0,color:#fff
```

## Privilege Requirements Flow

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ROLE HIERARCHY                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    ACCOUNTADMIN ──► SYSADMIN ──► DATA_DDL_ADMIN ──► DATA_DEVELOPER          │
│                                                            │                │
│                                                            ▼                │
│                                                     DATA_ANALYST            │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                    TIME TRAVEL CLONE CAPABILITY                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    Role              │ Can CLONE AT(TIMESTAMP)?                             │
│    ──────────────────┼─────────────────────────                             │
│    ACCOUNTADMIN      │ [✓] YES                                              │
│    SYSADMIN          │ [✓] YES (if has object access)                       │
│    DATA_DDL_ADMIN    │ [✓] YES (if has object access)                       │
│    DATA_DEVELOPER    │ [?] Depends on grants                                │
│    DATA_ANALYST      │ [X] NO - Read only                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Mermaid Diagram

```mermaid
flowchart LR
    subgraph ROLES["Role Hierarchy"]
        ACCOUNT[ACCOUNTADMIN] --> SYS[SYSADMIN]
        SYS --> DDL[DATA_DDL_ADMIN]
        DDL --> DEV[DATA_DEVELOPER]
        DEV --> ANALYST[DATA_ANALYST]
    end

    subgraph PRIVS["Time Travel CLONE Capability"]
        ACCOUNT -.->|Can CLONE| CLONE[CLONE AT TIMESTAMP]
        SYS -.->|Can CLONE| CLONE
        DDL -.->|Can CLONE| CLONE
        DEV -.->|❌ Limited| BLOCKED[May be blocked]
        ANALYST -.->|❌ Cannot| BLOCKED
    end

    style CLONE fill:#51cf66,color:#fff
    style BLOCKED fill:#ff6b6b,color:#fff
```

## Prevention Architecture

### ASCII Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    RBAC PREVENTION ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐         │
│  │   DEVELOPER ROLE            │    │   ADMIN ROLE                │         │
│  │   (DATA_DEVELOPER)          │    │   (DATA_DDL_ADMIN)          │         │
│  ├─────────────────────────────┤    ├─────────────────────────────┤         │
│  │                             │    │                             │         │
│  │  [✓] ALTER TABLE            │    │  [✓] ALTER TABLE            │         │
│  │      ADD COLUMN             │    │  [✓] CREATE TABLE           │         │
│  │                             │    │  [✓] DROP TABLE             │         │
│  │  [X] CREATE OR ALTER        │    │  [✓] CREATE OR ALTER        │         │
│  │      (No CREATE privilege)  │    │                             │         │
│  │                             │    │                             │         │
│  │  [X] DROP TABLE             │    │                             │         │
│  │      (No DROP privilege)    │    │                             │         │
│  │                             │    │                             │         │
│  └──────────────┬──────────────┘    └─────────────────────────────┘         │
│                 │                                                           │
│                 ▼                                                           │
│  ┌─────────────────────────────┐                                            │
│  │      OUTCOME                │                                            │
│  ├─────────────────────────────┤                                            │
│  │                             │                                            │
│  │  Developers can only use    │                                            │
│  │  safe operations (ALTER)    │                                            │
│  │                             │                                            │
│  │  [✓] DATA PROTECTED         │                                            │
│  │                             │                                            │
│  └─────────────────────────────┘                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

PRIVILEGE MATRIX:
┌────────────────┬────────┬───────┬──────┬────────────┐
│ Role           │ CREATE │ ALTER │ DROP │ SELECT/DML │
├────────────────┼────────┼───────┼──────┼────────────┤
│ DATA_DDL_ADMIN │   ✓    │   ✓   │  ✓   │     ✓      │
│ DATA_DEVELOPER │   X    │   ✓   │  X   │     ✓      │
│ DATA_ANALYST   │   X    │   X   │  X   │  SELECT    │
└────────────────┴────────┴───────┴──────┴────────────┘
```

### Mermaid Diagram

```mermaid
flowchart TD
    subgraph DEVELOPER["Developer Role (DATA_DEVELOPER)"]
        D1[ALTER TABLE ✅] --> SAFE[Safe Operations]
        D2[CREATE OR ALTER ❌] --> BLOCKED1[Blocked - No CREATE privilege]
        D3[DROP TABLE ❌] --> BLOCKED2[Blocked - No DROP privilege]
    end

    subgraph ADMIN["Admin Role (DATA_DDL_ADMIN)"]
        A1[ALTER TABLE ✅]
        A2[CREATE TABLE ✅]
        A3[DROP TABLE ✅]
        A4[CREATE OR ALTER ✅]
    end

    subgraph RESULT["Outcome"]
        SAFE --> PROTECTED[Data Protected]
        BLOCKED1 --> PROTECTED
        BLOCKED2 --> PROTECTED
    end

    style SAFE fill:#51cf66,color:#fff
    style PROTECTED fill:#51cf66,color:#fff
    style BLOCKED1 fill:#ff6b6b,color:#fff
    style BLOCKED2 fill:#ff6b6b,color:#fff
```

## Command Comparison

| Scenario | Wrong Command | Correct Command |
|----------|---------------|-----------------|
| Add column | `CREATE OR ALTER TABLE t (existing_cols..., new_col)` | `ALTER TABLE t ADD COLUMN new_col` |
| Modify column | `CREATE OR ALTER TABLE t (col NEW_TYPE)` | `ALTER TABLE t ALTER COLUMN col SET DATA TYPE NEW_TYPE` |
| Rename column | `CREATE OR ALTER TABLE t (new_name TYPE)` | `ALTER TABLE t RENAME COLUMN old_name TO new_name` |

## Key Recovery Insight

| DDL Command | Table Dropped? | Recovery Method |
|-------------|----------------|-----------------|
| CREATE OR REPLACE TABLE | YES | UNDROP TABLE |
| CREATE OR ALTER TABLE | NO (modifies in place) | CLONE AT(TIMESTAMP) |
