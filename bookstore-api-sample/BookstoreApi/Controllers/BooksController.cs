using BookstoreApi.Data;
using Microsoft.AspNetCore.Mvc;

namespace BookstoreApi.Controllers;

[ApiController]
[Route("books")]
public sealed class BooksController : ControllerBase
{
    private readonly BookStore _store;

    public BooksController(BookStore store) => _store = store;

    [HttpGet]
    public IActionResult GetAll() => Ok(_store.GetAll());

    [HttpGet("{id:int}")]
    public IActionResult GetById(int id)
    {
        var book = _store.GetById(id);
        return book is null
            ? NotFound(new { error = "Book not found" })
            : Ok(book);
    }
}
