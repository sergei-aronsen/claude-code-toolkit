---
name: i18n — Internationalization
description: Internationalization and localization — translations, locale files, multilanguage support. Triggers on i18n/l10n/translation/localization keywords.
---

# i18n — Internationalization Skill

> Load when: adding multilanguage support, translations, localization

---

## File Structure

```text
lang/
├── en/
│   ├── common.json      # UI: buttons, statuses, errors
│   ├── validation.json  # Form validation
│   └── {domain}.json    # Business domains: billing, metrics
└── ru/
    └── ...
```

**Rule:** One file < 500 keys, otherwise split.

---

## Key Naming

```text
{namespace}.{component}.{element}
```

```json
{
  "common.button.save": "Save",
  "common.status.loading": "Loading...",
  "validation.email.invalid": "Invalid email format",
  "dashboard.stats.total_users": "Total Users"
}
```

**Forbidden:**

- `btn1`, `text_234` — meaningless IDs
- `"Save changes": "Save changes"` — text as key

---

## Golden Rules

### 1. No String Concatenation

```javascript
// BAD
t('hello') + ' ' + name

// GOOD
t('hello', { name })
```

### 2. No Sentence Construction in Code

```javascript
// BAD
t('you_have') + count + t('messages')

// GOOD
t('messages_count', { count })
```

### 3. Use Libraries for Complex Logic

Don't write your own logic for plurals, gender, declensions.

---

## Plural Forms

```json
// en.json — 2 forms
"sites.count": "No sites | {n} site | {n} sites"

// ru.json — 4 forms
"sites.count": "Нет сайтов | {n} сайт | {n} сайта | {n} сайтов"
```

```javascript
t('sites.count', count)  // Auto-selects form
```

---

## Date / Number / Currency

Use Intl API (built into browser):

```javascript
// Date
new Intl.DateTimeFormat(locale).format(date)

// Number: "1,234.5" (EN) / "1 234,5" (RU)
new Intl.NumberFormat(locale).format(1234.5)

// Currency
new Intl.NumberFormat(locale, {
  style: 'currency',
  currency: 'USD'
}).format(99)
```

---

## Flexible UI

| Language | Length vs English |
|----------|-------------------|
| German | +20-30% |
| Russian | +10-20% |
| Chinese | -10-20% |

```css
/* BAD */
.button { width: 120px; }

/* GOOD */
.button {
  min-width: 80px;
  padding: 8px 16px;
}
```

---

## Libraries

| Framework | Library |
|-----------|---------|
| React | react-i18next, react-intl |
| Vue | vue-i18n |
| Next.js | next-intl |
| Angular | @angular/localize |

---

## Quick Translation (AI)

```bash
cat lang/en/common.json | claude "Translate values to Russian. Keep JSON keys. Output valid JSON."
```

---

## Full Guide

For detailed implementation: `components/i18n-multilanguage.md`
