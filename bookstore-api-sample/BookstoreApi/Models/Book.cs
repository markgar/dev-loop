namespace BookstoreApi.Models;

public sealed record Book
{
    public int Id { get; init; }
    public required string Title { get; init; }
    public required string Author { get; init; }
    public required string ISBN { get; init; }
    public required decimal Price { get; init; }
    public string? Genre { get; init; }
}
