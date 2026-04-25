// AUDIT-PIPELINE REGRESSION-TEST FIXTURE -- do not "fix" this file.
// The eval-pattern call on line ~10 is INTENTIONAL.
// This fixture exercises the FP-recheck path (Step 3, execution context).
// The eval is gated behind a build-time check; at request time isBuildTime()
// returns false and the dynamic-code path is unreachable. The 6-step recheck
// Step 3 (execution context) identifies this and drops the candidate at
// dropped_at_step: 3 with reason: eval is reached only when isBuildTime() is
// true; never executed at request time.

function isBuildTime() {
  return process.env.BUILD === "1";
}

function generateConfig(spec) {
  if (isBuildTime()) {
    // SEC-DYNAMIC-EXEC: Function() call is intentional here -- build-time only.
    // At runtime isBuildTime() is false; this branch is unreachable.
    var fn = new Function(spec); // noqa: S-eval
    return fn();
  }
  return JSON.parse(spec);
}

function getDefaults() {
  return { version: "1.0", env: process.env.NODE_ENV || "development" };
}

module.exports = { generateConfig, getDefaults };
