# Feature Specification: Bookstore REST API

**Feature Branch**: `001-bookstore-rest-api`
**Created**: 2026-03-06
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 - List and View Books (Priority: P1)

As a consumer of the bookstore API, I can retrieve the full catalog of books or look up a single book by ID, so I can browse what's available.

**Why this priority**: Read access is the foundation — every other operation depends on being able to verify the data.

**Independent Test**: Can be fully tested by seeding books on startup and issuing GET requests; delivers a browsable catalog with no writes required.

**Acceptance Scenarios**:

1. **Given** the API is running with seeded data, **When** I send `GET /books`, **Then** I receive a 200 response with a JSON array of all books.
2. **Given** a book with ID 1 exists, **When** I send `GET /books/1`, **Then** I receive a 200 response with that book's full details (title, author, ISBN, price, genre).
3. **Given** no book with ID 999 exists, **When** I send `GET /books/999`, **Then** I receive a 404 response with `{"error": "Book not found"}`.

---

### User Story 2 - Create a Book (Priority: P2)

As a consumer of the bookstore API, I can add a new book to the catalog so the inventory grows over time.

**Why this priority**: Creating data is the next most valuable operation after reading — it enables the catalog to be populated.

**Independent Test**: Can be tested by POSTing a valid book and confirming it appears in subsequent GET requests.

**Acceptance Scenarios**:

1. **Given** a valid book payload, **When** I send `POST /books`, **Then** I receive a 201 response with the created book including a generated ID.
2. **Given** a payload missing the title field, **When** I send `POST /books`, **Then** I receive a 400 response with a descriptive validation error.
3. **Given** a payload with an ISBN that already exists, **When** I send `POST /books`, **Then** I receive a 409 response indicating a conflict.

---

### User Story 3 - Update a Book (Priority: P3)

As a consumer of the bookstore API, I can update an existing book's details so the catalog stays accurate.

**Why this priority**: Updates are needed to correct mistakes or change prices, but are less critical than creating and reading.

**Independent Test**: Can be tested by updating a seeded book and verifying the changes via a subsequent GET.

**Acceptance Scenarios**:

1. **Given** a book with ID 1 exists, **When** I send `PUT /books/1` with a valid updated payload, **Then** I receive a 200 response with the updated book.
2. **Given** no book with ID 999 exists, **When** I send `PUT /books/999`, **Then** I receive a 404 response.
3. **Given** a payload with a negative price, **When** I send `PUT /books/1`, **Then** I receive a 400 response with a validation error.

---

### User Story 4 - Delete a Book (Priority: P4)

As a consumer of the bookstore API, I can remove a book from the catalog so discontinued titles can be cleaned up.

**Why this priority**: Deletion is the least critical CRUD operation — the catalog functions without it.

**Independent Test**: Can be tested by deleting a seeded book and confirming a subsequent GET returns 404.

**Acceptance Scenarios**:

1. **Given** a book with ID 1 exists, **When** I send `DELETE /books/1`, **Then** I receive a 200 response and the book is no longer retrievable.
2. **Given** no book with ID 999 exists, **When** I send `DELETE /books/999`, **Then** I receive a 404 response.

---

### Edge Cases

- What happens when the request body is empty or malformed JSON?
- What happens when price is zero or a string?
- What happens when ISBN contains invalid characters?
- What happens when title or author is an empty string vs. missing entirely?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST expose `GET /books` returning all books as a JSON array.
- **FR-002**: System MUST expose `GET /books/:id` returning a single book or 404.
- **FR-003**: System MUST expose `POST /books` to create a new book, returning 201 on success.
- **FR-004**: System MUST expose `PUT /books/:id` to update an existing book, returning 200 on success.
- **FR-005**: System MUST expose `DELETE /books/:id` to remove a book, returning 200 on success.
- **FR-006**: System MUST validate that title is a required, non-empty string.
- **FR-007**: System MUST validate that author is a required, non-empty string.
- **FR-008**: System MUST validate that ISBN is required and unique across all books.
- **FR-009**: System MUST validate that price is required and a positive number.
- **FR-010**: System MUST treat genre as an optional string field.
- **FR-011**: System MUST return proper HTTP status codes: 200, 201, 400, 404, 409.
- **FR-012**: System MUST return JSON responses with a consistent structure.
- **FR-013**: System MUST seed 2–3 sample books on startup.

### Key Entities

- **Book**: Represents a single book in the catalog. Attributes: id (auto-generated), title, author, ISBN, price, genre.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All five endpoints respond correctly for valid inputs as defined in the acceptance scenarios.
- **SC-002**: All validation rules reject invalid input with appropriate 400/409 status codes and descriptive error messages.
- **SC-003**: Unit/integration tests cover all happy paths and error cases for every endpoint.
- **SC-004**: The API starts and is usable with zero external dependencies — no database server setup required.
- **SC-005**: Seed data is present on first `GET /books` call after startup without any manual steps.
