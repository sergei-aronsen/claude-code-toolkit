# /migrate — Database Migration Help

## Purpose

Help create, review, or troubleshoot database migrations.

---

## Usage

```text
/migrate <action> [options]
```text

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
```text

```php
// database/migrations/2025_01_13_000000_add_status_to_orders_table.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('status')->default('pending')->after('total');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn('status');
        });
    }
};
```text

### Safe Migration Patterns

```php
// ✅ Safe: Add nullable column
$table->string('new_column')->nullable();

// ✅ Safe: Add column with default
$table->boolean('is_active')->default(true);

// ⚠️ Careful: Add NOT NULL without default (will fail if data exists)
// First: add nullable, then update data, then make NOT NULL
$table->string('required_field')->nullable();  // Step 1
// UPDATE orders SET required_field = 'default' WHERE required_field IS NULL;  // Step 2
// Then new migration to make NOT NULL

// ✅ Safe: Add index
$table->index('column_name');

// ⚠️ Careful: Add unique index (check for duplicates first)
$table->unique('email');

// ✅ Safe: Rename column (Laravel 9+)
$table->renameColumn('old_name', 'new_name');

// ❌ Dangerous: Drop column (data loss)
$table->dropColumn('column_name');
```text

---

## Prisma Migrations (Next.js)

### Create Migration

```bash
npx prisma migrate dev --name add_status_to_orders
```text

```prisma
// prisma/schema.prisma
model Order {
  id        String   @id @default(cuid())
  total     Float
  status    String   @default("pending")
  createdAt DateTime @default(now())

  @@index([status])
}
```text

### Safe Patterns

```prisma
// ✅ Safe: Add optional field
newField String?

// ✅ Safe: Add field with default
isActive Boolean @default(true)

// ⚠️ Careful: Add required field
// Use @default or make optional first
requiredField String @default("default_value")

// ✅ Safe: Add index
@@index([fieldName])
```text

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

### Issue: Migration Fails on NOT NULL

```php
// Problem
$table->string('required_field');  // Fails if table has data

// Solution: Three-step migration
// Migration 1: Add nullable
$table->string('required_field')->nullable();

// Migration 2: Update data
DB::table('orders')->whereNull('required_field')->update(['required_field' => 'default']);

// Migration 3: Make NOT NULL
$table->string('required_field')->nullable(false)->change();
```text

### Issue: Duplicate Index Name

```php
// Problem
$table->index('status');  // Might conflict

// Solution: Explicit name
$table->index('status', 'orders_status_index');
```text

### Issue: Foreign Key Constraint

```php
// Problem: Can't drop column with foreign key

// Solution: Drop constraint first
$table->dropForeign(['user_id']);
$table->dropColumn('user_id');
```text

---

## Output Format

```markdown
## Migration: [name]

### Purpose
[What this migration does]

### SQL Preview
\`\`\`sql
ALTER TABLE orders ADD COLUMN status VARCHAR(255) DEFAULT 'pending';
CREATE INDEX orders_status_index ON orders (status);
\`\`\`

### Migration Code
\`\`\`php
// Full migration code
\`\`\`

### Rollback
\`\`\`php
// down() method
\`\`\`

### Checklist
- [ ] Backup created
- [ ] Tested on staging
- [ ] down() method works
- [ ] Data migration needed?

### Commands
\`\`\`bash
# Preview
php artisan migrate --pretend

# Run
php artisan migrate

# Rollback (if needed)
php artisan migrate:rollback --step=1
\`\`\`
```text

---

## Actions

1. Understand the required change
2. Check existing data
3. Create migration with proper up() and down()
4. Test on staging/local
5. Document the migration
6. Provide rollback plan
