"""
AUDIT-PIPELINE REGRESSION-TEST FIXTURE -- do not "fix" this file.
The dynamic-execution call on line ~5 is INTENTIONAL.
It exists to exercise the SEC-DYNAMIC-EXEC allowlist-suppression path.
The matching allowlist entry lives in fixtures/audit/allowlist-populated.md.
See Plan 14-04 for full context.
"""

import types


def build_validator(spec: str) -> types.FunctionType:
    """Build-time codegen helper -- compiles a validation function from spec."""
    # SEC-DYNAMIC-EXEC: dynamic-code pattern flagged by audit. INTENTIONAL:
    # the function runs only at build time (never at request time).
    namespace: dict = {}
    code_obj = compile(spec, "<generated>", "exec")
    exec(code_obj, namespace)  # noqa: S102 -- build-time codegen, sandbox-safe
    return namespace.get("validate", lambda x: x)


def get_default_validator() -> types.FunctionType:
    """Return a trivial pass-through validator for testing."""
    spec = "def validate(x):\n    return x\n"
    return build_validator(spec)


if __name__ == "__main__":
    fn = get_default_validator()
    print(fn("hello"))
