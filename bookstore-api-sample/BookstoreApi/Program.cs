using BookstoreApi.Data;
using BookstoreApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddSingleton<BookStore>();

var app = builder.Build();

// Seed sample data on startup (Constitution V: Seed Data)
var store = app.Services.GetRequiredService<BookStore>();
store.Add(new Book
{
    Title = "The Great Gatsby",
    Author = "F. Scott Fitzgerald",
    ISBN = "978-0-7432-7356-5",
    Price = 12.99m,
    Genre = "Fiction"
});
store.Add(new Book
{
    Title = "Clean Code",
    Author = "Robert C. Martin",
    ISBN = "978-0-13-235088-4",
    Price = 33.49m,
    Genre = "Technology"
});
store.Add(new Book
{
    Title = "Dune",
    Author = "Frank Herbert",
    ISBN = "978-0-441-17271-9",
    Price = 9.99m
});

app.MapControllers();

app.Run();

// Enable WebApplicationFactory access from test project
public partial class Program { }
