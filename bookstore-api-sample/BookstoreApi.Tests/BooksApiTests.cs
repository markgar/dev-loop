using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookstoreApi.Models;
using Microsoft.AspNetCore.Mvc.Testing;

namespace BookstoreApi.Tests;

public sealed class BooksApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _client;

    public BooksApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task SeedData_IsPopulatedOnStartup()
    {
        var books = await _client.GetFromJsonAsync<List<Book>>("/books", JsonOptions);

        Assert.NotNull(books);
        Assert.Equal(3, books.Count);
        Assert.Contains(books, b => b.Title == "The Great Gatsby");
        Assert.Contains(books, b => b.Title == "Clean Code");
        Assert.Contains(books, b => b.Title == "Dune");
    }

    [Fact]
    public async Task GetBooks_ReturnsAllSeededBooks()
    {
        var response = await _client.GetAsync("/books");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var books = await response.Content.ReadFromJsonAsync<List<Book>>(JsonOptions);
        Assert.NotNull(books);
        Assert.True(books.Count >= 3);
    }

    [Fact]
    public async Task GetBookById_ValidId_ReturnsBook()
    {
        var response = await _client.GetAsync("/books/1");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var book = await response.Content.ReadFromJsonAsync<Book>(JsonOptions);
        Assert.NotNull(book);
        Assert.Equal(1, book.Id);
        Assert.Equal("The Great Gatsby", book.Title);
        Assert.Equal("F. Scott Fitzgerald", book.Author);
        Assert.Equal("978-0-7432-7356-5", book.ISBN);
        Assert.Equal(12.99m, book.Price);
        Assert.Equal("Fiction", book.Genre);
    }

    [Fact]
    public async Task GetBookById_InvalidId_Returns404WithError()
    {
        var response = await _client.GetAsync("/books/999");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<JsonElement>(JsonOptions);
        Assert.Equal("Book not found", body.GetProperty("error").GetString());
    }
}
