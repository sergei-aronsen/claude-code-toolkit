# /deps — Dependency Analysis

## Purpose

Audit dependencies for security, outdated packages, license compliance, and bundle impact.

---

## Usage

```text
/deps [action] [options]
```

**Actions:**

- `/deps audit` — Security vulnerability scan
- `/deps outdated` — Check for updates
- `/deps licenses` — License compliance check
- `/deps size` — Bundle size impact
- `/deps graph` — Dependency tree visualization
- `/deps all` — Full dependency report

---

## Examples

```text
/deps audit                     # Security vulnerabilities
/deps outdated                  # Available updates
/deps licenses --check=MIT,ISC  # License compliance
/deps size lodash               # Size impact of package
```

---

## Security Audit

### For `/deps audit`

```markdown
## Security Audit Report

### Critical Vulnerabilities (2)

| Package | Version | Vulnerability | Fix |
|---------|---------|---------------|-----|
| lodash | 4.17.20 | Prototype Pollution (CVE-2021-23337) | 4.17.21 |
| axios | 0.21.1 | SSRF (CVE-2021-3749) | 0.21.2+ |

### High Severity (1)

| Package | Version | Vulnerability | Fix |
|---------|---------|---------------|-----|
| tar | 4.4.13 | Arbitrary File Write | 4.4.19+ |

### Recommendations

\`\`\`bash
# Fix all vulnerabilities
npm audit fix

# Force fix (may have breaking changes)
npm audit fix --force

# Manual update for specific packages
npm install lodash@latest axios@latest
\`\`\`

### Unfixable (require manual update)

| Package | Reason | Action |
|---------|--------|--------|
| react-scripts | Depends on vulnerable webpack | Update to react-scripts@5 |
```

---

## Outdated Packages

### For `/deps outdated`

```markdown
## Outdated Packages Report

### Major Updates Available (Breaking)

| Package | Current | Latest | Changelog |
|---------|---------|--------|-----------|
| next | 13.5.4 | 14.0.3 | [View](https://github.com/vercel/next.js/releases) |
| typescript | 4.9.5 | 5.3.2 | [View](https://github.com/microsoft/TypeScript/releases) |

### Minor/Patch Updates (Safe)

| Package | Current | Latest | Type |
|---------|---------|--------|------|
| @prisma/client | 5.5.0 | 5.7.1 | minor |
| zod | 3.22.0 | 3.22.4 | patch |
| eslint | 8.50.0 | 8.55.0 | minor |

### Update Commands

\`\`\`bash
# Safe updates (minor/patch)
npm update

# Update specific package
npm install next@latest

# Interactive update (with npx)
npx npm-check-updates -i
\`\`\`

### Breaking Changes to Review

**Next.js 13 → 14:**
- App Router is now default
- Turbopack improvements
- Server Actions stable

**TypeScript 4 → 5:**
- Decorators changes
- New module resolution
```

---

## License Compliance

### For `/deps licenses`

```markdown
## License Report

### Summary

| License | Count | Status |
|---------|-------|--------|
| MIT | 145 | Allowed |
| ISC | 32 | Allowed |
| Apache-2.0 | 18 | Allowed |
| BSD-3-Clause | 12 | Allowed |
| GPL-3.0 | 2 | Review Required |

### GPL Packages (Copyleft - Review Required)

| Package | License | Used By |
|---------|---------|---------|
| some-package | GPL-3.0 | Direct |
| another-pkg | LGPL-3.0 | Transitive |

### Unknown Licenses

| Package | License | Action |
|---------|---------|--------|
| internal-pkg | UNLICENSED | Verify with author |

### Recommendations

1. Replace GPL packages if possible
2. Ensure LGPL compliance (dynamic linking)
3. Add license field to unlicensed packages

### Generate NOTICE file

\`\`\`bash
npx license-checker --csv > licenses.csv
npx license-checker --production --out licenses.json
\`\`\`
```

---

## Bundle Size Impact

### For `/deps size`

```markdown
## Bundle Size Analysis

### Package Size Impact

| Package | Size | Gzipped | % of Bundle |
|---------|------|---------|-------------|
| lodash | 72.5 KB | 25.2 KB | 5.4% |
| moment | 66.4 KB | 18.1 KB | 4.9% |
| date-fns | 12.3 KB | 4.1 KB | 0.9% |

### Alternatives Comparison

| Current | Alternative | Savings |
|---------|-------------|---------|
| lodash | lodash-es | -30KB (tree-shaking) |
| moment | date-fns | -54KB |
| axios | fetch | -13KB (native) |
| uuid | crypto.randomUUID | -7KB (native) |

### Size Optimization

\`\`\`bash
# Analyze bundle
npx webpack-bundle-analyzer
npx source-map-explorer dist/main.js

# Find duplicates
npx depcheck
npx npm-dedupe
\`\`\`

### Import Optimization

\`\`\`typescript
// Before: imports everything
import _ from 'lodash';
_.get(obj, 'path');

// After: imports only what's needed
import get from 'lodash/get';
get(obj, 'path');
\`\`\`
```

---

## Dependency Graph

### For `/deps graph`

```markdown
## Dependency Graph

### Direct Dependencies (15)

\`\`\`text
my-app@1.0.0
├── next@14.0.3
│   ├── react@18.2.0
│   └── react-dom@18.2.0
├── @prisma/client@5.7.1
├── zod@3.22.4
└── tailwindcss@3.3.5
    └── postcss@8.4.31
\`\`\`

### Duplicate Packages

| Package | Versions | Size Waste |
|---------|----------|------------|
| debug | 4.3.1, 4.3.4 | 8 KB |
| semver | 6.3.1, 7.5.4 | 15 KB |

### Fix Duplicates

\`\`\`bash
npm dedupe
# or
npx yarn-deduplicate
\`\`\`

### Circular Dependencies

| Cycle | Files |
|-------|-------|
| A → B → C → A | utils.ts → helpers.ts → utils.ts |

### Unused Dependencies

| Package | Last Used |
|---------|-----------|
| lodash | Never imported |
| moment | Not found in code |
```

---

## Commands Reference

```bash
# Security
npm audit
npm audit --json
pnpm audit

# Outdated
npm outdated
npx npm-check-updates

# Licenses
npx license-checker
npx license-checker --production --summary

# Size
npx bundlephobia <package>
npx cost-of-modules

# Graph
npm ls
npm ls --all
npx depgraph
```

---

## Actions

1. Run security audit
2. Check for outdated packages
3. Verify license compliance
4. Analyze bundle size impact
5. Identify unused/duplicate dependencies
6. Provide specific remediation steps
