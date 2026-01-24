# Self-Check Section (Reality Filter)

Insert this section at the end of each audit to filter false positives.

---

## SELF-CHECK (CRITICALLY IMPORTANT!)

**Before adding each issue to the report, ask yourself these questions:**

### Reality Filter

| Question | If "no" → reconsider severity |
| -------- | ----------------------------- |
| Is this **exploitable** in real conditions? | Theoretical vulnerability does not equal real threat |
| Is there an **attack path** for external attacker? | Internal-only does not equal CRITICAL |
| What is the **damage** on successful attack? | Public data leak does not equal password leak |
| Is **authentication** required for exploitation? | Auth-required lowers severity |
| Is this **really missing** or did I not find it? | Check twice before CRITICAL |

### Typical False Positives

**Double-check before including:**

| Seems like an issue | Why it might not be |
| ------------------- | ------------------- |
| "No auth on endpoint" | May be intentionally public (health, webhooks) |
| "CORS: *" | If endpoint is auth-protected — not critical |
| "Sensitive data in logs" | If logs are server-only — medium, not critical |
| "Old package version" | If no CVE for this version — not security issue |
| "SQL without prepared statements" | If parameters are not from user — not SQLi |
| "No comments in code" | Code may be self-documenting |
| "Long file" | If logically connected — this is normal |

### Checklist Before Adding

```text
[ ] I verified this is REALLY exploitable
[ ] I understand the SPECIFIC attack path
[ ] Severity matches REAL damage, not theoretical
[ ] This is not a false positive (checked usage context)
[ ] Fix recommendation is PRACTICAL and doesn't break functionality
```

### Self-Check Example

```text
Found: [finding description]

Checking:
- Exploitable? → [YES/NO, why]
- Attack path? → [description]
- Damage? → [description]
- Auth required? → [YES/NO]
- Really an issue? → [conclusion]

Decision: [INCLUDE/EXCLUDE] as [SEVERITY], [reasoning]
```
