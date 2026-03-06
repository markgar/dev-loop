# Feature Specification: Book Search and Filtering

**Feature Branch**: `002-book-search-filtering`
**Created**: 2026-03-06
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search Books by Title or Author (Priority: P1)

As a consumer of the bookstore API, I can search for books by title or author so I can find specific books without browsing the entire catalog.

**Why this priority**: Search is the most valuable discovery feature — users rarely want to scroll through every book to find what they need.

**Independent Test**: Can be fully tested by seeding books and issuing GET requests with a query parameter; delivers filtered results without any write operations.

**Acceptance Scenarios**:

1. **Given** books exist with "Gatsby" in the title, **When** I send `GET /books?search=gatsby`, **Then** I receive a 200 response with only books whose title or author contains "gatsby" (case-insensitive).
2. **Given** books exist by author "Orwell", **When** I send `GET /books?search=orwell`, **Then** I receive a 200 response containing those books.
3. **Given** no books match "zzzzz", **When** I send `GET /books?search=zzzzz`, **Then** I receive a 200 response with an empty array.

---

### User Story 2 - Filter Books by Genre (Priority: P2)

As a consumer of the bookstore API, I can filter books by genre so I can browse only the category I'm interested in.

**Why this priority**: Genre filtering is a natural complement to search — users often browse by category rather than searching for a specific title.

**Independent Test**: Can be tested by seeding books across multiple genres and filtering by one genre at a time.

**Acceptance Scenarios**:

1. **Given** books exist with genre "Fiction", **When** I send `GET /books?genre=Fiction`, **Then** I receive a 200 response with only books in that genre.
2. **Given** no books have genre "Romance", **When** I send `GET /books?genre=Romance`, **Then** I receive a 200 response with an empty array.
3. **Given** the genre parameter is an empty string, **When** I send `GET /books?genre=`, **Then** I receive a 200 response with all books (filter is ignored).

---

### User Story 3 - Filter Books by Price Range (Priority: P3)

As a consumer of the bookstore API, I can filter books by price range so I can find books within my budget.

**Why this priority**: Price filtering is useful but less common than search or genre browsing for a bookstore API.

**Independent Test**: Can be tested by seeding books at various price points and verifying min/max filtering.

**Acceptance Scenarios**:

1. **Given** books exist at various prices, **When** I send `GET /books?minPrice=10&maxPrice=20`, **Then** I receive a 200 response with only books priced between 10 and 20 inclusive.
2. **Given** only `minPrice` is provided, **When** I send `GET /books?minPrice=15`, **Then** I receive books priced at 15 or above.
3. **Given** `minPrice` is greater than `maxPrice`, **When** I send `GET /books?minPrice=20&maxPrice=5`, **Then** I receive a 400 response with a descriptive error.

---

### User Story 4 - Combine Search and Filters (Priority: P4)

As a consumer of the bookstore API, I can combine search and filter parameters in a single request so I can narrow results precisely.

**Why this priority**: Combining filters is a power-user feature that builds on the individual capabilities above.

**Independent Test**: Can be tested by issuing requests with multiple query parameters and verifying all conditions are applied.

**Acceptance Scenarios**:

1. **Given** books exist across genres and prices, **When** I send `GET /books?search=gatsby&genre=Fiction`, **Then** I receive only Fiction books matching "gatsby".
2. **Given** multiple filters are applied, **When** I send `GET /books?genre=Fiction&minPrice=10&maxPrice=15`, **Then** I receive only Fiction books in that price range.

---

### Edge Cases

- What happens when `minPrice` or `maxPrice` is negative?
- What happens when `minPrice` or `maxPrice` is not a valid number?
- What happens when search is a single character?
- What happens when multiple unknown query parameters are provided?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support a `search` query parameter on `GET /books` that matches against title and author (case-insensitive, partial match).
- **FR-002**: System MUST support a `genre` query parameter on `GET /books` that filters by exact genre (case-insensitive).
- **FR-003**: System MUST support `minPrice` and `maxPrice` query parameters on `GET /books` for price range filtering (inclusive bounds).
- **FR-004**: System MUST allow combining `search`, `genre`, `minPrice`, and `maxPrice` in a single request, applying all filters with AND logic.
- **FR-005**: System MUST return an empty array (not an error) when filters match no books.
- **FR-006**: System MUST return a 400 error when `minPrice` is greater than `maxPrice`.
- **FR-007**: System MUST return a 400 error when `minPrice` or `maxPrice` is not a valid positive number.
- **FR-008**: System MUST ignore empty or missing filter parameters (treat as "no filter").

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Search by title or author returns correct results for partial, case-insensitive matches.
- **SC-002**: Genre filter returns only books matching the specified genre.
- **SC-003**: Price range filter correctly applies inclusive min/max bounds.
- **SC-004**: Combined filters produce the intersection of all individual filter results.
- **SC-005**: Tests cover all happy paths, empty results, invalid inputs, and filter combinations.
