#!/usr/bin/env python3
"""validate-integrations-catalog.py — Validate scripts/lib/integrations-catalog.json (CAT-03).

Phase 32-01 (CAT-03). Catalog schema v2 introduced by Phase 32-01 (CAT-01).
Successor of the implicit shape contract that lived only in mcp.sh's jq queries.

Schema (v2):
  {
    "schema_version": 2,
    "categories": ["docs-research", "dev-tools", "workspace", "email", "monitoring"],
    "components": {
      "mcp": {
        "<name>": {
          "name": "<name>",
          "display_name": "<string>",
          "category": "<one of categories[]>",
          "env_var_keys": ["<UPPER_SNAKE>"...],
          "install_args": ["<string>"...],
          "description": "<string>",
          "requires_oauth": <bool>,
          "default_scope": "user"|"project"
        }
      }
    }
  }

Checks performed:
  1. Top-level "schema_version" must equal 2.
  2. Top-level "categories" must be a non-empty array of strings.
  3. Top-level "components" must be an object with at least the "mcp" key.
  4. Every entry under components.mcp must be an object with all required keys:
     name, display_name, category, env_var_keys, install_args, description,
     requires_oauth, default_scope.
  5. components.mcp[<name>].name must equal the entry's key (self-reference invariant).
  6. components.mcp[<name>].category must be a member of top-level categories[].
  7. env_var_keys[] must contain only valid POSIX env-var names (^[A-Z_][A-Z0-9_]*$).
  8. install_args[] must be a non-empty array of strings.
  9. requires_oauth must be a boolean.
  10. No duplicate entry keys across components.mcp (JSON loader already enforces this,
      but we re-check defensively against parser quirks).
  11. default_scope must equal "user" or "project" (Phase 36 SCOPE-01).

Exit 0 on pass. Exit 1 with stderr messages on any failure.

Constraints:
- Python stdlib only (no jsonschema dependency).
- Compatible with Python 3.8+.
- Must run unmodified on macOS BSD and GNU Linux.
"""

import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_CATALOG_PATH = os.path.join(REPO_ROOT, "scripts", "lib", "integrations-catalog.json")

EXPECTED_SCHEMA_VERSION = 2

# Required keys on every components.mcp[<name>] entry.
REQUIRED_ENTRY_KEYS = (
    "name",
    "display_name",
    "category",
    "env_var_keys",
    "install_args",
    "description",
    "requires_oauth",
    "default_scope",
)

# POSIX env-var name shape: leading uppercase or underscore, then alphanumeric/underscore.
ENV_VAR_RE = re.compile(r"^[A-Z_][A-Z0-9_]*$")


def fail(message):
    print("ERROR: " + message, file=sys.stderr)


def main():
    errors = 0

    # Optional path argument lets future per-project overrides reuse the same
    # validator (PATTERNS § 4 step 3 — "specifics §82").  Plan 32-03 hermetic
    # smoke test (test-integrations-foundation.sh) relies on this seam to
    # validate in-sandbox fixtures without mutating the shipped catalog.
    catalog_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CATALOG_PATH

    # Load catalog
    try:
        with open(catalog_path, "r", encoding="utf-8") as fh:
            catalog = json.load(fh)
    except FileNotFoundError:
        fail("integrations-catalog.json not found at: " + catalog_path)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        fail("integrations-catalog.json is not valid JSON: " + str(exc))
        sys.exit(1)

    if not isinstance(catalog, dict):
        fail("top-level value must be a JSON object")
        sys.exit(1)

    # Check 1: schema_version
    schema_version = catalog.get("schema_version")
    if schema_version != EXPECTED_SCHEMA_VERSION:
        fail(
            "schema_version must be "
            + str(EXPECTED_SCHEMA_VERSION)
            + ", got: "
            + repr(schema_version)
        )
        errors += 1

    # Check 2: categories
    categories = catalog.get("categories")
    valid_categories = set()
    if not isinstance(categories, list) or len(categories) == 0:
        fail('"categories" must be a non-empty array')
        errors += 1
    else:
        for idx, cat in enumerate(categories):
            if not isinstance(cat, str) or not cat:
                fail(
                    "categories[" + str(idx) + "] must be a non-empty string, got: "
                    + repr(cat)
                )
                errors += 1
            else:
                valid_categories.add(cat)

    # Check 3: components.mcp must exist and be an object
    components = catalog.get("components")
    if not isinstance(components, dict):
        fail('"components" must be an object')
        sys.exit(1 if errors == 0 else 1)

    mcp_section = components.get("mcp")
    if not isinstance(mcp_section, dict):
        fail('"components.mcp" must be an object')
        sys.exit(1 if errors == 0 else 1)

    if len(mcp_section) == 0:
        fail('"components.mcp" must contain at least one entry')
        errors += 1

    # Check 4-9: per-entry validation
    seen_keys = set()
    for key, entry in mcp_section.items():
        location = "components.mcp[" + repr(key) + "]"

        # Check 10: duplicate keys (defensive — JSON loader rejects, but re-check)
        if key in seen_keys:
            fail("duplicate entry key " + repr(key))
            errors += 1
            continue
        seen_keys.add(key)

        if not isinstance(entry, dict):
            fail(location + " must be an object, got " + type(entry).__name__)
            errors += 1
            continue

        # Check 4: required keys
        missing = [k for k in REQUIRED_ENTRY_KEYS if k not in entry]
        if missing:
            fail(location + " missing required keys: " + ", ".join(missing))
            errors += 1
            continue

        # Check 5: name self-reference
        if entry.get("name") != key:
            fail(
                location + ": .name (" + repr(entry.get("name"))
                + ") must equal the entry key (" + repr(key) + ")"
            )
            errors += 1

        # Check 6: category in valid set
        category = entry.get("category")
        if not isinstance(category, str) or not category:
            fail(location + ": .category must be a non-empty string")
            errors += 1
        elif valid_categories and category not in valid_categories:
            fail(
                location + ": .category " + repr(category)
                + " is not in top-level categories "
                + str(sorted(valid_categories))
            )
            errors += 1

        # display_name must be non-empty string
        display_name = entry.get("display_name")
        if not isinstance(display_name, str) or not display_name:
            fail(location + ": .display_name must be a non-empty string")
            errors += 1

        # description must be non-empty string
        description = entry.get("description")
        if not isinstance(description, str) or not description:
            fail(location + ": .description must be a non-empty string")
            errors += 1

        # Check 7: env_var_keys[] must be a list of POSIX env-var-shaped strings
        env_var_keys = entry.get("env_var_keys")
        if not isinstance(env_var_keys, list):
            fail(location + ": .env_var_keys must be an array")
            errors += 1
        else:
            for vidx, env_key in enumerate(env_var_keys):
                if not isinstance(env_key, str):
                    fail(
                        location + ": .env_var_keys[" + str(vidx)
                        + "] must be a string, got " + type(env_key).__name__
                    )
                    errors += 1
                elif not ENV_VAR_RE.match(env_key):
                    fail(
                        location + ": .env_var_keys[" + str(vidx)
                        + "] " + repr(env_key)
                        + " must match POSIX env-var shape ^[A-Z_][A-Z0-9_]*$"
                    )
                    errors += 1

        # Check 8: install_args must be non-empty array of strings
        install_args = entry.get("install_args")
        if not isinstance(install_args, list) or len(install_args) == 0:
            fail(location + ": .install_args must be a non-empty array")
            errors += 1
        else:
            for aidx, arg in enumerate(install_args):
                if not isinstance(arg, str):
                    fail(
                        location + ": .install_args[" + str(aidx)
                        + "] must be a string, got " + type(arg).__name__
                    )
                    errors += 1

        # Check 9: requires_oauth must be a boolean
        requires_oauth = entry.get("requires_oauth")
        if not isinstance(requires_oauth, bool):
            fail(
                location + ": .requires_oauth must be a boolean, got "
                + type(requires_oauth).__name__
            )
            errors += 1

        # Check 11: default_scope must be "user" or "project" (Phase 36 / SCOPE-01)
        default_scope = entry.get("default_scope")
        if default_scope not in ("user", "project"):
            fail(
                location + ": .default_scope must be 'user' or 'project', got "
                + repr(default_scope)
            )
            errors += 1

    if errors > 0:
        print(
            "integrations-catalog.json validation FAILED ("
            + str(errors)
            + " error(s))",
            file=sys.stderr,
        )
        sys.exit(1)

    print(
        "integrations-catalog.json validation PASSED ("
        + str(len(seen_keys))
        + " mcp entries checked across "
        + str(len(valid_categories))
        + " categories)"
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
