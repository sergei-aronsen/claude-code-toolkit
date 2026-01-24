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

#### GET /api/v1/users

**Query Parameters:**

| Param | Type | Description |
|-------|------|-------------|
| page | int | Page number (default: 1) |
| limit | int | Items per page (default: 20, max: 100) |
| sort | string | Sort field (e.g., -createdAt) |
| search | string | Search in name, email |

**Response 200:**

\`\`\`json
{
  "data": [
    {
      "id": "usr_123",
      "email": "user@example.com",
      "name": "John Doe",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
\`\`\`

#### POST /api/v1/users

**Request Body:**

\`\`\`json
{
  "email": "user@example.com",
  "name": "John Doe",
  "password": "securePassword123"
}
\`\`\`

**Response 201:**

\`\`\`json
{
  "id": "usr_123",
  "email": "user@example.com",
  "name": "John Doe",
  "createdAt": "2024-01-15T10:30:00Z"
}
\`\`\`

### Error Responses

**400 Bad Request:**

\`\`\`json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request body",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ]
  }
}
\`\`\`

**404 Not Found:**

\`\`\`json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "User not found"
  }
}
\`\`\`
```

---

## OpenAPI Generation

### For `/api openapi`

```yaml
openapi: 3.0.3
info:
  title: Project API
  version: 1.0.0

servers:
  - url: https://api.example.com/v1

paths:
  /users:
    get:
      summary: List users
      tags: [Users]
      security:
        - bearerAuth: []
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserList'
        '401':
          $ref: '#/components/responses/Unauthorized'

components:
  schemas:
    User:
      type: object
      required: [id, email, name]
      properties:
        id:
          type: string
        email:
          type: string
          format: email
        name:
          type: string
        createdAt:
          type: string
          format: date-time

    UserList:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/User'
        pagination:
          $ref: '#/components/schemas/Pagination'

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  responses:
    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

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
