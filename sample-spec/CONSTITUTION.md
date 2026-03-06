# Bookstore API Constitution

## Core Principles

### I. Simplicity First
Every design decision favors the simplest viable solution. No external database servers, no unnecessary abstractions, no premature optimization. Start with in-memory storage and only add complexity when a spec explicitly requires it.

### II. REST Conventions
All endpoints follow standard REST conventions: proper HTTP methods, meaningful status codes, consistent JSON response structure. The API should be unsurprising to any developer familiar with REST.

### III. Validation at the Boundary
All input validation happens at the API boundary. Invalid requests are rejected with clear, actionable error messages before touching any business logic or storage.

### IV. Test-First
Every endpoint must have tests covering both happy paths and error cases. Tests run without external dependencies — no database servers, no network calls.

### V. Seed Data for Exploration
The application seeds sample data on startup so developers and reviewers can immediately explore the API without setup steps.

## Tech Stack

- .NET 10 with C#
- In-memory or SQLite storage (no external database server)
- Built-in test framework

## Governance

This constitution defines product constraints only. It does not dictate spec structure, build order, or development process.

**Version**: 1.0 | **Ratified**: 2026-03-06
