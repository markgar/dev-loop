using System.Collections.Concurrent;
using BookstoreApi.Models;

namespace BookstoreApi.Data;

public sealed class BookStore
{
    private readonly ConcurrentDictionary<int, Book> _books = new();
    private int _nextId;

    public IReadOnlyList<Book> GetAll() =>
        _books.Values.OrderBy(b => b.Id).ToList();

    public Book? GetById(int id) =>
        _books.GetValueOrDefault(id);

    public Book Add(Book book)
    {
        var id = Interlocked.Increment(ref _nextId);
        var created = book with { Id = id };
        _books[id] = created;
        return created;
    }

    public Book? Update(int id, Book book)
    {
        if (!_books.ContainsKey(id)) return null;
        var updated = book with { Id = id };
        _books[id] = updated;
        return updated;
    }

    public bool Delete(int id) => _books.TryRemove(id, out _);

    public bool IsbnExists(string isbn, int? excludeId = null) =>
        _books.Values.Any(b => b.ISBN == isbn && b.Id != excludeId);
}
