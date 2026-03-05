# LinkedIn Post: Complete Guide (Enhanced Version)

> **Author:** Malaya Kumar Padhi (Malay)  
> Snowflake | Data Architecture | Data Engineering | Analytics Architecture | (Principal Data Architect – Aspirational)  
> **Repository:** https://github.com/Techy-Malay/snowflake-data-recovery-guide  
> **Created:** 2026-02-22

---

## Post Content (Copy below line for LinkedIn)

---

I watched a developer lose 3 columns of production data in 2 seconds.

No error. No warning. Just... gone.

Here's what happened 👇

━━━━━━━━━━━━━━━━━━━━━━

𝗧𝗵𝗲 𝗠𝗶𝘀𝘁𝗮𝗸𝗲

They wanted to add ONE column to an existing table.

They wrote:
```
CREATE OR ALTER TABLE orders (
  id INT, 
  amount NUMBER, 
  new_col STRING
);
```

They should have written:
```
ALTER TABLE orders ADD COLUMN new_col STRING;
```

The difference? Their version REPLACED the table definition.

Every column not explicitly listed was silently dropped.
• customer_name → gone
• order_date → gone  
• status → gone

No confirmation prompt. No warning.

━━━━━━━━━━━━━━━━━━━━━━

𝗧𝗵𝗲 𝗥𝗲𝗰𝗼𝘃𝗲𝗿𝘆 (𝗧𝗿𝗶𝗰𝗸𝘆 𝗣𝗮𝗿𝘁)

First instinct: Run UNDROP TABLE.

❌ Doesn't work.

Why? CREATE OR ALTER modifies the table in place—it doesn't drop it. Since nothing was dropped, there's nothing to undrop.

✅ The solution: Time Travel CLONE

```
CREATE TABLE orders_recovered CLONE orders 
AT(TIMESTAMP => '2024-01-15 10:00:00');

ALTER TABLE orders RENAME TO orders_corrupted;
ALTER TABLE orders_recovered RENAME TO orders;
```

This clones the table from BEFORE the destructive change.

━━━━━━━━━━━━━━━━━━━━━━

𝗧𝗵𝗲 𝗣𝗿𝗲𝘃𝗲𝗻𝘁𝗶𝗼𝗻

Here's the RBAC fix we implemented:

• Developers get ALTER privilege only
• CREATE privilege restricted to admins

Without CREATE, developers can't run CREATE OR ALTER.
They can only use ALTER TABLE ADD COLUMN (which is safe).

━━━━━━━━━━━━━━━━━━━━━━

𝗞𝗲𝘆 𝗧𝗮𝗸𝗲𝗮𝘄𝗮𝘆𝘀

1️⃣ CREATE OR ALTER ≠ safe "upsert"
2️⃣ Omitted columns are silently dropped
3️⃣ UNDROP won't work (use CLONE instead)
4️⃣ Least-privilege RBAC prevents this entirely

━━━━━━━━━━━━━━━━━━━━━━

I've open-sourced the complete guide with:
✓ Demo scripts (simulate the problem)
✓ Recovery scripts (step-by-step fix)
✓ RBAC templates (prevention)

🔗 github.com/Techy-Malay/snowflake-data-recovery-guide

Have you seen this happen? Drop a comment 👇

━━━━━━━━━━━━━━━━━━━━━━

#Snowflake #DataEngineering #DataRecovery #DataArchitecture #CloudData #TimeTravel #RBAC

---

## Post Stats

- **Character count:** ~2,100 (within LinkedIn's 3,000 limit)
- **Format:** Text with code blocks and visual separators
- **Recommended:** Attach screenshot showing before/after data

## Enhancements Made:

| Aspect | Before | After |
|--------|--------|-------|
| Hook | Generic statement | Personal story hook |
| Spacing | Dense paragraphs | Visual separators, scannable |
| Structure | Flat | Clear sections with headers |
| UNDROP insight | Brief mention | Full explanation of WHY |
| Call-to-action | Just GitHub link | Question + engagement ask |
| Length | ~1,150 chars | ~2,100 chars (more value) |

---
