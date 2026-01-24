---
name: Go Expert
description: Deep expertise in Go - Gin/Chi patterns, concurrency, error handling, testing
---

# Go Expert Skill

This skill provides deep Go expertise including Gin/Chi patterns, goroutines, error handling, table-driven tests, and security best practices.

---

## Error Handling

### Always Check Errors

```go
// ✅ Correct - check and wrap
user, err := repo.GetByID(ctx, id)
if err != nil {
    return nil, fmt.Errorf("failed to get user %s: %w", id, err)
}

// ❌ Wrong - ignoring error
user, _ := repo.GetByID(ctx, id)  // Never do this!
```

### Custom Error Types

```go
type AppError struct {
    StatusCode int    `json:"-"`
    Code       string `json:"code"`
    Message    string `json:"message"`
    Err        error  `json:"-"`
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("%s: %v", e.Message, e.Err)
    }
    return e.Message
}

func (e *AppError) Unwrap() error {
    return e.Err
}

// Constructors
func ErrNotFound(resource string) *AppError {
    return &AppError{
        StatusCode: http.StatusNotFound,
        Code:       "NOT_FOUND",
        Message:    fmt.Sprintf("%s not found", resource),
    }
}

func ErrBadRequest(message string) *AppError {
    return &AppError{
        StatusCode: http.StatusBadRequest,
        Code:       "BAD_REQUEST",
        Message:    message,
    }
}
```

### Error Checking

```go
// Check specific error types
func handleError(err error) {
    var appErr *AppError
    if errors.As(err, &appErr) {
        // Handle app error
        log.Printf("App error: %s", appErr.Code)
        return
    }

    if errors.Is(err, context.DeadlineExceeded) {
        // Handle timeout
        log.Println("Request timed out")
        return
    }

    if errors.Is(err, sql.ErrNoRows) {
        // Handle not found
        return
    }

    // Unknown error
    log.Printf("Unexpected error: %v", err)
}
```

---

## Concurrency Patterns

### Worker Pool

```go
func ProcessItems(ctx context.Context, items []Item, workers int) error {
    jobs := make(chan Item, len(items))
    results := make(chan error, len(items))

    // Start workers
    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range jobs {
                select {
                case <-ctx.Done():
                    results <- ctx.Err()
                    return
                default:
                    results <- processItem(ctx, item)
                }
            }
        }()
    }

    // Send jobs
    for _, item := range items {
        jobs <- item
    }
    close(jobs)

    // Wait and close results
    go func() {
        wg.Wait()
        close(results)
    }()

    // Collect errors
    var errs []error
    for err := range results {
        if err != nil {
            errs = append(errs, err)
        }
    }

    return errors.Join(errs...)
}
```

### Context Propagation

```go
// ✅ Always pass context
func (s *UserService) Create(ctx context.Context, req *CreateUserRequest) (*User, error) {
    // Check context before expensive operations
    select {
    case <-ctx.Done():
        return nil, ctx.Err()
    default:
    }

    // Pass context to all operations
    user, err := s.repo.Create(ctx, req)
    if err != nil {
        return nil, err
    }

    // For fire-and-forget, use WithoutCancel
    go s.sendWelcomeEmail(context.WithoutCancel(ctx), user.Email)

    return user, nil
}

// ✅ Handler with timeout
func (h *UserHandler) Create(c *gin.Context) {
    ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
    defer cancel()

    user, err := h.service.Create(ctx, &req)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            c.JSON(http.StatusRequestTimeout, gin.H{"error": "request timeout"})
            return
        }
        // handle other errors
    }
}
```

### Fan-out/Fan-in

```go
func FetchAll(ctx context.Context, urls []string) ([]Result, error) {
    results := make(chan Result, len(urls))
    errs := make(chan error, len(urls))

    // Fan-out
    for _, url := range urls {
        go func(url string) {
            result, err := fetch(ctx, url)
            if err != nil {
                errs <- err
                return
            }
            results <- result
        }(url)
    }

    // Fan-in
    var allResults []Result
    var allErrs []error

    for i := 0; i < len(urls); i++ {
        select {
        case result := <-results:
            allResults = append(allResults, result)
        case err := <-errs:
            allErrs = append(allErrs, err)
        case <-ctx.Done():
            return nil, ctx.Err()
        }
    }

    if len(allErrs) > 0 {
        return allResults, errors.Join(allErrs...)
    }
    return allResults, nil
}
```

---

## Table-Driven Tests

### Basic Pattern

```go
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {"valid email", "test@example.com", false},
        {"valid with subdomain", "test@mail.example.com", false},
        {"missing @", "testexample.com", true},
        {"missing domain", "test@", true},
        {"empty string", "", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateEmail(%q) error = %v, wantErr %v",
                    tt.email, err, tt.wantErr)
            }
        })
    }
}
```

### With Testify

```go
func TestUserService_GetByID(t *testing.T) {
    tests := []struct {
        name        string
        userID      string
        mockSetup   func(*MockUserRepository)
        want        *User
        wantErr     bool
        errContains string
    }{
        {
            name:   "returns user when found",
            userID: "1",
            mockSetup: func(m *MockUserRepository) {
                m.On("GetByID", mock.Anything, "1").
                    Return(&User{ID: "1", Email: "test@example.com"}, nil)
            },
            want:    &User{ID: "1", Email: "test@example.com"},
            wantErr: false,
        },
        {
            name:   "returns error when not found",
            userID: "999",
            mockSetup: func(m *MockUserRepository) {
                m.On("GetByID", mock.Anything, "999").Return(nil, ErrNotFound)
            },
            wantErr:     true,
            errContains: "not found",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockRepo := new(MockUserRepository)
            tt.mockSetup(mockRepo)
            service := NewUserService(mockRepo)

            got, err := service.GetByID(context.Background(), tt.userID)

            if tt.wantErr {
                require.Error(t, err)
                if tt.errContains != "" {
                    assert.Contains(t, err.Error(), tt.errContains)
                }
                return
            }

            require.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

---

## Validation with go-playground/validator

```go
import "github.com/go-playground/validator/v10"

type CreateUserRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Name     string `json:"name" validate:"required,min=2,max=100"`
    Age      *int   `json:"age" validate:"omitempty,gte=0,lte=150"`
    Password string `json:"password" validate:"required,min=8"`
}

var validate = validator.New()

func (r *CreateUserRequest) Validate() error {
    return validate.Struct(r)
}

// In handler
func (h *UserHandler) Create(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    if err := req.Validate(); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // proceed with creation
}
```

---

## Security Checklist

### SQL Injection Prevention

```go
// ✅ Parameterized query
rows, err := db.QueryContext(ctx,
    "SELECT * FROM users WHERE email = $1",
    userInput,
)

// ✅ With sqlx
user := User{}
err := db.GetContext(ctx, &user,
    "SELECT * FROM users WHERE id = $1", id)

// ❌ NEVER concatenate
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", userInput)  // SQL INJECTION!
```

### Input Validation

```go
// ✅ Validate with go-playground/validator
type Request struct {
    Email string `validate:"required,email"`
    Age   int    `validate:"gte=0,lte=150"`
}

// ✅ Custom validation
func validateEmail(email string) error {
    if email == "" {
        return errors.New("email required")
    }
    if !strings.Contains(email, "@") {
        return errors.New("invalid email format")
    }
    return nil
}
```

### Rate Limiting (Gin)

```go
import "github.com/ulule/limiter/v3"
import mgin "github.com/ulule/limiter/v3/drivers/middleware/gin"
import "github.com/ulule/limiter/v3/drivers/store/memory"

func RateLimitMiddleware() gin.HandlerFunc {
    rate := limiter.Rate{
        Period: 1 * time.Minute,
        Limit:  60,
    }
    store := memory.NewStore()
    instance := limiter.New(store, rate)
    return mgin.NewMiddleware(instance)
}
```

---

## Common Commands

```bash
# Development
go run cmd/api/main.go
air                          # Hot reload

# Testing
go test ./...
go test ./... -v
go test -cover ./...
go test -race ./...          # Race detection

# Code Quality
golangci-lint run
golangci-lint run --fix
go fmt ./...
go vet ./...

# Build
go build -o bin/api cmd/api/main.go
go mod tidy
```
