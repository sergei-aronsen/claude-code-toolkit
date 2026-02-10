# /migrate — Database Migration Help

## Purpose

Help create, review, or troubleshoot database migrations.

---

## Usage

```text
/migrate <action> [options]
```

**Actions:**

- `create` — Create new migration
- `review` — Review existing migration
- `fix` — Fix migration issues
- `rollback` — Help with rollback

**Examples:**

- `/migrate create add_status_to_orders`
- `/migrate review` — Review pending migrations
- `/migrate fix` — Fix failed migration
- `/migrate rollback` — Plan rollback

---

## Laravel Migrations

### Create Migration

```bash
php artisan make:migration add_status_to_orders_table
```

```php
// up(): Schema::table('orders', function (Blueprint $table) {
//     $table->string('status')->default('pending')->after('total');
//     $table->index('status');
// });
// down(): dropIndex(['status']), dropColumn('status')
```

### Safe Migration Patterns

| Pattern | Safety | Notes |
|---------|--------|-------|
| Add nullable column | Safe | `->nullable()` |
| Add column with default | Safe | `->default(value)` |
| Add NOT NULL (no default) | Dangerous | Add nullable first, update data, then NOT NULL |
| Add index | Safe | `->index('column')` |
| Add unique index | Careful | Check for duplicates first |
| Rename column | Safe | Laravel 9+ `->renameColumn()` |
| Drop column | Dangerous | Data loss, check foreign keys |

---

## Prisma Migrations (Next.js)

Prisma: `npx prisma migrate dev --name description`. Same safe patterns apply -- add optional fields (`String?`) or with defaults first, check for duplicates before unique constraints.

---

## Migration Checklist

### Before Creating

- [ ] Is this change necessary?
- [ ] What data exists that might be affected?
- [ ] Do I need to migrate existing data?
- [ ] Is the down() method correct?

### Before Running

- [ ] Backup database
- [ ] Test on staging first
- [ ] Check `migrate:status` or `migrate status`
- [ ] Review with `migrate --pretend` (Laravel)

### After Running

- [ ] Verify data integrity
- [ ] Check application works
- [ ] Monitor for errors

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| NOT NULL fails | Table has existing rows | 3-step: add nullable, update data, then NOT NULL |
| Duplicate index name | Auto-generated name conflicts | Use explicit name: `->index('col', 'table_col_index')` |
| Can't drop column | Foreign key constraint | Drop foreign key first, then drop column |

---

## Output Format

```markdown
## Migration: [name]

### Purpose
[What this migration does]

### SQL Preview
[Generated SQL]

### Migration Code
[Full up() and down() code]

### Checklist
- [ ] Backup created
- [ ] Tested on staging
- [ ] down() method works
- [ ] Data migration needed?

### Commands
Preview, run, rollback commands for the detected framework
```

---

## Actions

1. Understand the required change
2. Check existing data
3. Create migration with proper up() and down()
4. Test on staging/local
5. Document the migration
6. Provide rollback plan
