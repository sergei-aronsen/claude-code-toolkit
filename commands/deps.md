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

## Report Structure

Each action produces a report with these sections:

### `/deps audit` report

Tables: Critical/High/Medium vulnerabilities with Package | Version | CVE | Fix columns. Recommendations with `npm audit fix` / manual update commands. Unfixable packages with reasons.

### `/deps outdated` report

Tables: Major (breaking) and Minor/Patch (safe) updates with Package | Current | Latest columns. Update commands. Breaking changes summary for major updates.

### `/deps licenses` report

License summary table (MIT, ISC, Apache, GPL counts). GPL/copyleft packages flagged for review. Unknown licenses listed. Generate NOTICE: `npx license-checker --csv > licenses.csv`

### `/deps size` report

Package size impact table with Size | Gzipped | % of Bundle. Lighter alternatives comparison. Import optimization tips (tree-shaking, named imports).

### `/deps graph` report

Dependency tree visualization. Duplicate packages with size waste. Circular dependencies. Unused dependencies.

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

---

## Related Commands

- `/audit security` — deep security audit beyond dependency vulnerabilities
- `/verify pre-pr` — includes security scan before creating a PR
- `/perf` — performance profiling (bundle size overlaps with `/deps size`)
