# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in the templates or scripts, please report it by:

1. **DO NOT** create a public GitHub issue
2. Email: <security@digitalplanet.no> (or create a private security advisory)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Response Timeline

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Fix release**: Depends on severity (critical: ASAP, high: within 14 days)

## Scope

This security policy covers:

- Shell scripts (`scripts/*.sh`)
- Template content that could lead to insecure code patterns
- CI/CD configurations

## Out of Scope

- Vulnerabilities in projects that USE these templates (that's on the user)
- Theoretical vulnerabilities without practical exploit path

## Recognition

We appreciate responsible disclosure and will acknowledge security researchers in our CHANGELOG (unless you prefer to remain anonymous).
