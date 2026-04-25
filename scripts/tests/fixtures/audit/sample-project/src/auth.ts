// AUDIT-PIPELINE REGRESSION-TEST FIXTURE — do not "fix" this file.
// The SQL string concatenation on line ~8 is INTENTIONAL.
// It exists to exercise the SEC-SQL-INJECTION surviving-finding path in
// scripts/tests/test-audit-pipeline.sh. See Plan 14-04 for full context.

import express from "express";

const app = express();
const db = { query: (sql: string) => sql }; // stub — never executed

// Deliberately-vulnerable route: user-supplied id flows into a
// string-concatenated SQL query without parameterization (SEC-SQL-INJECTION).
app.get("/users/:id", (req, res) => {
  const id = req.params.id;
  const sql = "SELECT * FROM users WHERE id=" + id;
  const result = db.query(sql);
  res.json({ data: result });
});

// Harmless health-check route (no finding expected here).
app.get("/healthz", (_req, res) => {
  res.json({ status: "ok" });
});

// Harmless list route — uses a parameterized-style approach for contrast.
app.get("/users", (_req, res) => {
  const sql = "SELECT id, name FROM users ORDER BY id LIMIT 50";
  const result = db.query(sql);
  res.json({ data: result });
});

export { app };
