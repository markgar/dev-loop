# Bookstore REST API — Implementation Plan

- [x] **Task 1: Project scaffold, Book model, and seed data** — Set up the .NET 10 project with the Book entity, in-memory store, and startup seed data.
  - Create solution + web API project + test project
  - `Book` model: Id (auto-generated int), Title, Author, ISBN, Price, Genre (optional)
  - In-memory book repository with thread-safe collection
  - Seed 2–3 sample books on startup (Constitution V: Seed Data)
  - Key files: `BookstoreApi/Program.cs`, `BookstoreApi/Models/Book.cs`, `BookstoreApi/Data/BookStore.cs`
  - Test: verify seed data is populated on startup

- [x] **Task 2: GET endpoints — list and view books** — Implement `GET /books` and `GET /books/{id}` with tests for happy paths and 404.
  - `GET /books` → 200 + JSON array of all books
  - `GET /books/{id}` → 200 + single book, or 404 `{"error": "Book not found"}`
  - Key files: `BookstoreApi/Controllers/BooksController.cs`
  - Tests: list returns all seeded books; get by valid ID returns correct book; get by invalid ID returns 404 with error body

- [ ] **Task 3: POST endpoint — create a book** — Implement `POST /books` with input validation, unique ISBN enforcement, and tests for 201/400/409.
  - `POST /books` → 201 + created book with generated ID
  - Validate: title required & non-empty, author required & non-empty, ISBN required & unique, price required & positive, genre optional
  - 400 on missing/invalid fields with descriptive message; 409 on duplicate ISBN
  - Tests: successful create; missing title → 400; missing author → 400; duplicate ISBN → 409; negative price → 400

- [ ] **Task 4: PUT endpoint — update a book** — Implement `PUT /books/{id}` with validation and tests for 200/400/404/409.
  - `PUT /books/{id}` → 200 + updated book
  - Same validation rules as POST (title, author, ISBN, price, genre); 404 if book not found; 409 if updated ISBN conflicts with another book
  - Tests: successful update returns modified book; update non-existent ID → 404; negative price → 400; changing ISBN to a duplicate → 409

- [ ] **Task 5: DELETE endpoint — delete a book** — Implement `DELETE /books/{id}` with tests for 200 and 404.
  - `DELETE /books/{id}` → 200 on success; 404 if not found
  - Subsequent `GET` for deleted ID must return 404
  - Tests: delete existing book → 200, then GET → 404; delete non-existent book → 404

- [ ] **Task 6: Edge-case handling and input hardening** — Cover malformed JSON, empty bodies, type mismatches, and boundary string validation.
  - Empty/malformed JSON body → 400
  - Price as zero or string → 400
  - ISBN with invalid characters → 400
  - Title/author as empty string vs. missing entirely → 400
  - Tests for each edge case listed above

All tasks are sequential — each builds on the prior commit.
