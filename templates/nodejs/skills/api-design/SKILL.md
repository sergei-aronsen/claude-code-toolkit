# API Design Skill

> Load this skill when designing REST APIs, creating endpoints, or working with OpenAPI.

---

## Rule

**DESIGN CONSISTENT, PREDICTABLE APIs!**

- Use nouns for resources, HTTP verbs for actions
- Return appropriate status codes
- Provide clear error messages

---

## REST Naming Conventions

### Resources (nouns, plural)

```text
GET    /users           # List users
POST   /users           # Create user
GET    /users/{id}      # Get user
PUT    /users/{id}      # Replace user
PATCH  /users/{id}      # Update user
DELETE /users/{id}      # Delete user
```

### Nested Resources

```text
GET    /users/{id}/posts        # User's posts
POST   /users/{id}/posts        # Create post for user
GET    /users/{id}/posts/{pid}  # Specific post
```

### Actions (when CRUD doesn't fit)

```text
POST   /users/{id}/activate     # Custom action
POST   /orders/{id}/cancel      # Custom action
POST   /reports/generate        # Non-resource action
```

---

## HTTP Status Codes

### Success (2xx)

| Code | When to Use |
|------|-------------|
| `200 OK` | GET success, PUT/PATCH success |
| `201 Created` | POST created new resource |
| `204 No Content` | DELETE success, no body |

### Client Errors (4xx)

| Code | When to Use |
|------|-------------|
| `400 Bad Request` | Invalid input/syntax |
| `401 Unauthorized` | Not authenticated |
| `403 Forbidden` | Authenticated but not allowed |
| `404 Not Found` | Resource doesn't exist |
| `409 Conflict` | Resource conflict (duplicate) |
| `422 Unprocessable Entity` | Validation failed |
| `429 Too Many Requests` | Rate limit exceeded |

### Server Errors (5xx)

| Code | When to Use |
|------|-------------|
| `500 Internal Server Error` | Unexpected error |
| `502 Bad Gateway` | Upstream service failed |
| `503 Service Unavailable` | Temporarily unavailable |

---

## Error Response Format (RFC 7807)

```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation Error",
  "status": 422,
  "detail": "The request body contains invalid fields",
  "instance": "/users/123",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format"
    },
    {
      "field": "age",
      "message": "Must be a positive number"
    }
  ]
}
```

### Simple Error Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "details": [
      { "field": "email", "message": "Invalid format" }
    ]
  }
}
```

---

## Pagination

### Offset-Based (simple, but inefficient for large datasets)

```text
GET /users?page=2&limit=20

Response:
{
  "data": [...],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

### Cursor-Based (efficient, recommended)

```text
GET /users?cursor=abc123&limit=20

Response:
{
  "data": [...],
  "pagination": {
    "nextCursor": "xyz789",
    "hasMore": true
  }
}
```

---

## Filtering and Sorting

### Filtering

```text
GET /users?status=active
GET /users?role=admin&status=active
GET /users?createdAt[gte]=2024-01-01
GET /users?search=john
```

### Sorting

```text
GET /users?sort=createdAt       # Ascending
GET /users?sort=-createdAt      # Descending
GET /users?sort=name,-createdAt # Multiple fields
```

### Field Selection

```text
GET /users?fields=id,name,email
GET /users/{id}?include=posts,comments
```

---

## Versioning Strategies

### URL Path (recommended)

```text
/api/v1/users
/api/v2/users
```

### Header

```text
Accept: application/vnd.api+json; version=1
```

### Query Parameter

```text
/api/users?version=1
```

---

## Rate Limiting Headers

```text
X-RateLimit-Limit: 100        # Max requests per window
X-RateLimit-Remaining: 95     # Remaining requests
X-RateLimit-Reset: 1640000000 # Unix timestamp when limit resets
Retry-After: 60               # Seconds to wait (on 429)
```

---

## Request/Response Examples

### Create Resource

```text
POST /api/v1/users
Content-Type: application/json

{
  "email": "user@example.com",
  "name": "John Doe"
}

Response: 201 Created
Location: /api/v1/users/123

{
  "id": 123,
  "email": "user@example.com",
  "name": "John Doe",
  "createdAt": "2024-01-15T10:30:00Z"
}
```

### List with Pagination

```text
GET /api/v1/users?page=1&limit=10&status=active

Response: 200 OK

{
  "data": [
    { "id": 1, "name": "John", "status": "active" },
    { "id": 2, "name": "Jane", "status": "active" }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 42,
    "totalPages": 5
  }
}
```

---

## OpenAPI Specification

### Basic Structure

```yaml
openapi: 3.0.3
info:
  title: My API
  version: 1.0.0
  description: API description

servers:
  - url: https://api.example.com/v1

paths:
  /users:
    get:
      summary: List users
      tags: [Users]
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserList'

components:
  schemas:
    User:
      type: object
      required: [id, email]
      properties:
        id:
          type: integer
        email:
          type: string
          format: email
        name:
          type: string
```

---

## Security Checklist

- [ ] Authentication on all protected endpoints
- [ ] Authorization checks (resource ownership)
- [ ] Input validation
- [ ] Rate limiting
- [ ] CORS configuration
- [ ] No sensitive data in URLs
- [ ] HTTPS only
- [ ] Audit logging

---

## Anti-Patterns to Avoid

```text
# Bad
GET  /getUsers              # Verb in URL
POST /users/delete/123      # Wrong verb
GET  /users?action=delete   # Actions via query params
POST /api                   # Generic endpoint

# Good
GET  /users
DELETE /users/123
POST /users/123/deactivate  # Custom action
```

---

## When to Use This Skill

- Designing new API endpoints
- Creating OpenAPI/Swagger specs
- Implementing error handling
- Adding pagination/filtering
- API versioning decisions
- Code review for API consistency
