# /find-script — Find Scripts and Commands

## Purpose

Find scripts, artisan commands, npm scripts, or bash scripts in the project.

---

## Usage

```text
/find-script <query>
```text

**Examples:**

- `/find-script deploy` — Find deployment scripts
- `/find-script queue` — Find queue-related scripts
- `/find-script build` — Find build scripts

---

## Search Locations

### Laravel Projects

```text
- app/Console/Commands/*.php     # Artisan commands
- scripts/                        # Bash scripts
- composer.json → scripts         # Composer scripts
- package.json → scripts          # NPM scripts
- deploy.sh, deploy-*.sh          # Deploy scripts
- Makefile                        # Make targets
```text

### Next.js Projects

```text
- scripts/                        # Bash/Node scripts
- package.json → scripts          # NPM scripts
- bin/                            # Binary scripts
- .github/workflows/              # CI/CD scripts
```text

### Universal

```text
- *.sh files                      # Shell scripts
- Makefile                        # Make targets
- docker-compose.yml              # Docker commands
```text

---

## Output Format

```markdown
## Scripts matching "[query]"

### Artisan Commands (if Laravel)
| Command | Class | Description |
|---------|-------|-------------|
| `app:command` | CommandClass | What it does |

### NPM Scripts
| Script | Command | Description |
|--------|---------|-------------|
| `npm run dev` | `vite` | Run dev server |

### Shell Scripts
| File | Purpose |
|------|---------|
| `deploy.sh` | Production deployment |

### Suggested Usage
\`\`\`bash
# Most relevant command for your query
php artisan app:command
\`\`\`
```text

---

## Behavior

1. **Search comprehensively** — Check all script locations
2. **Match by name or content** — Search both filenames and script content
3. **Show relevant context** — Include what each script does
4. **Prioritize results** — Most relevant first

---

## Actions

1. Search for scripts matching the query
2. Read relevant script files to understand purpose
3. Format results with descriptions
4. Suggest the most relevant command to use
