# Library API

A Rails API for library staff to track books, readers and loans. A daily job emails readers 3 days before a book is due and on the due date. Built with Ruby 4.0.9, Rails 8.1.4 and PostgreSQL 18.

## Running it

```bash
docker compose up
```

This starts Postgres, Redis, Rails and a Sidekiq worker. The first start creates the database and adds the seed data.

| What | Where |
|---|---|
| API reference | http://localhost:3000/docs |
| Email inbox | http://localhost:3000/letter_opener |
| Health check | http://localhost:3000/up |
| OpenAPI file | [swagger/v1/swagger.yaml](swagger/v1/swagger.yaml) |
| Postman collection | [postman/library-api.postman_collection.json](postman/library-api.postman_collection.json) |
| Postman environment | [postman/library-api.postman_environment.json](postman/library-api.postman_environment.json) |

In Postman, import both files and select the "Library API local" environment.

Seed data to try:

| Serial | Book | State |
|---|---|---|
| 000101 | Oryx and Crake | Available, one past loan |
| 000102 | Good Omens | On loan to card 100001 |
| 000103 | The Left Hand of Darkness | Available |
| 000104 | Dune | On loan to card 100002, due in 3 days |
| 000105 | Solaris | On loan to card 100003, due today |
| 000106 | Emma | On loan to card 100001, overdue |

The seeds create readers with cards 100001, 100002 and 100003. You can also add, update and delete readers through the API.

Run the tests and code checks:

```bash
docker compose run --rm web bin/ci
```

Check that the running app answers on every endpoint, with no Postman needed:

```bash
bin/smoke
```

Send the reminders now, then read them in the inbox. A second run sends nothing. The job logs one line per mail:

```bash
docker compose exec web bin/rails runner "DueDateReminderJob.perform_now"
# [Reminder] upcoming reminder to anna.nowak@example.com for book 000104
# [Reminder] due_today reminder to piotr.wisniewski@example.com for book 000105
```

Reset the demo data and move the loan dates to today:

```bash
docker compose exec web bin/rails db:seed:replant
# (no output)
```

## Design notes

### Gems

| Gem | Job |
|---|---|
| `blueprinter` | Turns models into JSON |
| `pagy` | Paginates lists |
| `rswag-specs`, `rswag-api` | Build `swagger.yaml` from the request specs and serve it |
| `scalar_ruby` | Shows the API reference |
| `committee-rails` | Checks API responses in specs against `swagger.yaml` |
| `sidekiq`, `sidekiq-cron` | Run the daily reminder job |
| `letter_opener_web` | Shows sent mail in the browser |
| `strong_migrations`, `bullet` | Catch unsafe migrations and N+1 queries |
| `rspec-rails`, `factory_bot_rails`, `shoulda-matchers` | Tests |
| `brakeman`, `bundler-audit`, `rubocop-rails-omakase` | Security and style checks |

I chose Sidekiq over Solid Queue because it is commonly used, and Redis plus a separate worker gives a better example of Dockerization. The cost is one more service to run.

### Errors

Every error has the same format. `code` is for machines and `field` names the bad input:

```bash
curl -X PATCH localhost:3000/api/v1/books/000101/status -H "Content-Type: application/json" \
  -d '{"status":"borrowed","card_number":"999999"}'
# 422 {"errors":[{"code":"unknown_reader","message":"No reader has that card number","field":"card_number"}]}
```

| Status | Meaning |
|---|---|
| 400 | The body or query string cannot be read |
| 404 | The book or reader in the URL does not exist, or the path has no route |
| 409 | The book's state refuses the request, such as lending a book already on loan |
| 422 | The input is wrong, such as a bad serial or an unknown card |
| 500 | Something unexpected failed. The log keeps the cause and the response hides it |

A client can retry a 409 after the state changes. A 422 needs a different request.

Each error is a class in `app/errors/books/`, and its name becomes the code. `ApplicationController` picks the status. A partial unique index also blocks a second open loan in the database, so two requests at once still give a 409.

### API documentation

The docs come from the request specs, so they cannot describe an API that no longer exists. The specs generate `swagger.yaml`, and `bin/postman` generates the Postman collection from that file. Three checks keep them correct:

- Each example in the docs must equal the real response in its spec.
- Every API response in the request specs must match `swagger.yaml`.
- `bin/ci` fails if `swagger.yaml` is out of date.

I chose Scalar over Swagger UI for its sidebar, search and code samples. The cost is that it loads from a CDN, so the page needs internet access.

### Pagination

lists are paginated with Pagy - optimized for thousands of books. `limit` defaults to 20 and stops at 100.

### Serialization

I chose Blueprinter because its views fit this API. A book has a short form in lists and a long form with its loan history. A book returns `author` as one string, which keeps the brief's field name, and `authors` as a list in display order.

### Other decisions

- **Serial and card numbers are strings.** An integer would turn `004219` into `4219`. A database check also rejects bad values.
- **Books have a status column, and overdue is computed.** The brief asks to update a status. Overdue comes from the due date, so no job has to keep it correct.
- **`PATCH /books/:serial_number/status` lends and returns.** It matches the brief. A separate loans resource is more RESTful, but further from the brief's wording.
- **Delete removes the book and its history.** Soft delete touches every query, which is too much for this task. A book on loan cannot be deleted.
- **One daily reminder job with sent-at columns.** An early return needs no cancelling, a second run sends nothing, and a run after downtime catches up.
- **`citext` for author names.** Rails' `find_or_create_by!` then handles two requests adding the same author, which replaced my custom code. A nondeterministic collation is the alternative.

### Beyond the brief

The brief lists five book operations. I added:

- `GET /api/v1/readers/:card_number`, `POST /api/v1/readers`, `PATCH /api/v1/readers/:card_number` and `DELETE /api/v1/readers/:card_number` manage readers. A reader with open or past loans cannot be deleted.
- `GET /api/v1/books?author=atwood&title=oryx` searches by part of an author's name or title.
- `GET /api/v1/readers/:card_number/books` lists a reader's loans. `?include_returned=true` adds their history.

### Limitations

- There is no authentication, as the brief allows.
- Deleting a book deletes its loan history.
- A reminder counts as sent when it is queued, so a mail that later fails is not sent again.
- Search scans the whole table, with no index.
- Invalid bytes in a URL path, such as `/api/v1/books/%E0`, still return the Rails error format.
- I have not run the app on Windows.

### Future improvements

- **Reservations and a waitlist.** A queue of readers per book. A return notifies the next reader.
- **Overdue fines.** Ledger entries computed from due dates, not a running balance.
- **Staff login and roles.** Devise or the Rails auth generator, plus Pundit.
- **Audit trail.** PaperTrail on books and loans, recording who changed what.
- **Lost and stolen books.** A resolution on the loan, and a daily job for loans overdue past 6 months.
- **Soft delete.** A `discarded_at` column that keeps the loan history.
- **Alba instead of Blueprinter.** It has no dependencies and supports typed attributes. Its README says it is faster than most alternatives, which I would benchmark first.
- **Monitoring tools.** - datadog, sentry, rollbar or rails internal stack: solid_errors, faultline, rails_pulse
- **Healthcheck.** custom endpoint: get "up" => "rails/health#show", as: :rails_health_check to connect with uptime monitor
