#!/usr/bin/env python3
"""validate-commands.py — Validate commands/*.md for required headings (HARDEN-A-01).

Derived from AUDIT-12: commands/*.md files lack enforced structure.

Checks performed:
  1. Every commands/*.md (except README.md) must contain a "## Purpose" H2 heading.
  2. Every commands/*.md (except README.md) must contain a "## Usage" H2 heading.

Exit 0 on pass. Exit 1 with stderr messages on any failure.
"""

import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
COMMANDS_DIR = os.path.join(REPO_ROOT, "commands")

REQUIRED_HEADINGS = ["## Purpose", "## Usage"]


def fail(message):
    print("ERROR: " + message, file=sys.stderr)


def main():
    errors = 0

    if not os.path.isdir(COMMANDS_DIR):
        fail("commands/ directory not found at: " + COMMANDS_DIR)
        sys.exit(1)

    command_files = sorted(
        name
        for name in os.listdir(COMMANDS_DIR)
        if name.endswith(".md") and name != "README.md"
    )

    if not command_files:
        fail("No command files found in: " + COMMANDS_DIR)
        sys.exit(1)

    for name in command_files:
        filepath = os.path.join(COMMANDS_DIR, name)
        try:
            with open(filepath, "r", encoding="utf-8") as fh:
                content = fh.read()
        except OSError as exc:
            fail("Could not read " + name + ": " + str(exc))
            errors += 1
            continue

        # Check each required heading as a line-anchored H2 (## followed by exactly the text)
        for heading in REQUIRED_HEADINGS:
            # Match the heading at the start of a line
            pattern = re.compile(r"^" + re.escape(heading) + r"\b", re.MULTILINE)
            if not pattern.search(content):
                fail("Missing '" + heading + "' heading: commands/" + name)
                errors += 1

    if errors > 0:
        print(
            "commands/ validation FAILED (" + str(errors) + " error(s))",
            file=sys.stderr,
        )
        sys.exit(1)

    print(
        "commands/ validation PASSED ("
        + str(len(command_files))
        + " files checked)"
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
