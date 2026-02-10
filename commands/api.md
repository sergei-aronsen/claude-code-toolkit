# /api — API Design Assistant

## Purpose

Design REST APIs, generate OpenAPI specs, and scaffold CRUD endpoints.

---

## Usage

```text
/api [action] [options]
```

**Actions:**

- `/api design <resource>` — Design endpoint structure
- `/api openapi` — Generate OpenAPI spec
- `/api crud <resource>` — Scaffold CRUD endpoints
- `/api validate` — Validate existing API design

---

## Examples

```text
/api design users               # Design /users endpoint
/api crud posts --auth          # CRUD with authentication
/api openapi                    # Generate spec from code
/api validate routes/api.php    # Check API consistency
```

---

## API Design Output

### For `/api design users`

```markdown
## API Design: Users

### Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | /api/v1/users | List users | Yes |
| POST | /api/v1/users | Create user | Yes |
| GET | /api/v1/users/{id} | Get user | Yes |
| PUT | /api/v1/users/{id} | Update user | Yes |
| DELETE | /api/v1/users/{id} | Delete user | Yes |

### Request/Response

For each endpoint, generate: query parameters table (page, limit, sort, search), request/response JSON with `data` + `pagination` wrapper, and error format:

\`\`\`json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [...] } }
\`\`\`
```

---

## OpenAPI Generation

Generates OpenAPI 3.0.3 spec with: paths per resource, `$ref` schemas, pagination schema, bearerAuth security scheme, and standard error responses (400, 401, 404, 500).

---

## CRUD Scaffolding

### For `/api crud posts --auth`

Generates:

| File | Purpose |
|------|---------|
| `routes/api/posts.ts` | Route definitions |
| `controllers/PostController.ts` | Request handlers |
| `schemas/post.ts` | Zod validation |
| `types/post.ts` | TypeScript types |

---

## Design Checklist

| Rule | Check |
|------|-------|
| Plural nouns for resources | `/users` not `/user` |
| HTTP verbs for actions | GET, POST, PUT, DELETE |
| Consistent naming | camelCase or snake_case |
| Versioning | `/api/v1/` |
| Pagination | All list endpoints |
| Error format | RFC 7807 or consistent |
| Status codes | 200, 201, 204, 400, 401, 403, 404, 422, 500 |

---

## Actions

1. Analyze existing routes/endpoints
2. Design resource structure
3. Generate request/response schemas
4. Create OpenAPI specification
5. Scaffold CRUD code if requested

---

## Related Commands

- `/test` — generate tests for your API endpoints
- `/e2e` — end-to-end testing for API flows
- `/verify` — verify build, types, and lint before committing API changes
- `/audit security` — check API for security vulnerabilities
