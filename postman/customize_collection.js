// Finishes the collection the converter writes, using the examples in the OpenAPI file:
// node postman/customize_collection.js <collection.json> <openapi.json>
const crypto = require("crypto");
const fs = require("fs");

const [ collectionFile, openapiFile ] = process.argv.slice(2);
const collection = JSON.parse(fs.readFileSync(collectionFile, "utf8"));
const openapi = JSON.parse(fs.readFileSync(openapiFile, "utf8"));

const BOOKS = "/api/v1/books";
const BOOK = "/api/v1/books/{serial_number}";
const STATUS = "/api/v1/books/{serial_number}/status";
const READERS = "/api/v1/readers";
const READER = "/api/v1/readers/{card_number}";
const READER_BOOKS = "/api/v1/readers/{card_number}/books";
const STATUS_TEXT = {
  200: "OK", 201: "Created", 204: "No Content", 400: "Bad Request", 404: "Not Found",
  409: "Conflict", 422: "Unprocessable Content", 500: "Internal Server Error"
};

const templates = collection.item.flatMap((folder) => folder.item);
const operation = (method, path) => openapi.paths[path][method.toLowerCase()];

const template = (method, path) => {
  const postmanPath = path.replace(/\{(\w+)\}/g, ":$1");
  const found = templates.find((item) => item.request.method === method && `/${item.request.url.path.join("/")}` === postmanPath);

  if (!found) throw new Error(`The converter wrote no request for ${method} ${path}`);
  return found;
};

const requestExample = (method, path, name) => {
  const example = operation(method, path).requestBody.content["application/json"].examples[name];

  if (!example) throw new Error(`${method} ${path} documents no request example called ${name}`);
  return example.value;
};

const savedResponse = (item, code, name, body) => ({
  name,
  originalRequest: structuredClone(item.request),
  status: STATUS_TEXT[code],
  code: Number(code),
  ...(body === undefined
    ? { header: [], cookie: [], body: "" }
    : { header: [ { key: "Content-Type", value: "application/json" } ], cookie: [], _postman_previewlanguage: "json", body: JSON.stringify(body, null, 2) })
});

// Every documented response of the operation, or only the named examples when `only` is given.
const savedResponses = (item, method, path, only) => {
  const responses = Object.entries(operation(method, path).responses).flatMap(([ code, response ]) => {
    const examples = response.content?.["application/json"]?.examples;

    if (!examples) return only ? [] : [ savedResponse(item, code, response.description) ];

    return Object.entries(examples)
      .filter(([ name ]) => !only || only.includes(name))
      .map(([ name, example ]) => ({ name, response: savedResponse(item, code, example.summary || name, example.value) }))
      .map((entry) => entry.response);
  });

  if (only && responses.length !== only.length) throw new Error(`${method} ${path} does not document all of ${only}`);
  return responses;
};

const script = (listen, lines) => ({ listen, script: { type: "text/javascript", exec: lines } });

const statusTest = (status, errorCode) => {
  const lines = [ `pm.test("returns ${status}", () => pm.response.to.have.status(${status}));` ];

  if (errorCode) {
    lines.push(`pm.test("reports ${errorCode}", () => pm.expect(pm.response.json().errors[0].code).to.eql("${errorCode}"));`);
  }
  return script("test", lines);
};

const buildRequest = ({ method, path, name, status, errorCode, identifier, body, search, examples, events = [] }) => {
  const item = structuredClone(template(method, path));

  item.name = name;
  if (identifier) item.request.url.variable[0].value = identifier;
  if (body) item.request.body.raw = JSON.stringify(body, null, 2);
  for (const parameter of item.request.url.query ?? []) {
    parameter.disabled = parameter.key !== search;
  }
  item.response = savedResponses(item, method, path, examples);
  item.event = [ ...events, statusTest(status, errorCode) ];
  return item;
};

// A query parameter stays off until a request turns it on, so these values replace the converter's placeholders.
const QUERY_VALUES = { author: "atwood", title: "omens", include_returned: "true" };
for (const parameter of templates.flatMap((item) => item.request.url.query ?? [])) {
  if (parameter.key in QUERY_VALUES) parameter.value = QUERY_VALUES[parameter.key];
}

// A new serial each time lets the add and delete pairs run again. 5xxxxx stays clear of the seeded books.
// A script sets it, because no dynamic variable gives six digits and the delete needs the same value as the add.
const NEW_SERIAL = "{{newSerial}}";
const RANDOM_TITLE = "{{$randomCatchPhrase}}";
const RANDOM_NAME = "{{$randomFullName}}";
const newSerial = script("prerequest", [
  'pm.environment.set("newSerial", String(500000 + Math.floor(Math.random() * 100000)));'
]);
const filledIn = script("test", [
  'pm.test("fills in the random values", () => pm.expect(pm.response.text()).to.not.include("{{"));'
]);

// Keeps the fields of the documented example and swaps its values for dynamic variables.
const randomBook = (example) => {
  const book = { ...example, serial_number: NEW_SERIAL, title: RANDOM_TITLE };

  if (book.author) book.author = RANDOM_NAME;
  if (book.authors) book.authors = book.authors.map(() => RANDOM_NAME);
  return book;
};

const addBook = (name, example) => buildRequest({
  method: "POST", path: BOOKS, name, status: 201, events: [ newSerial, filledIn ],
  body: randomBook(requestExample("POST", BOOKS, example))
});
const deleteNewBook = (name) => buildRequest({ method: "DELETE", path: BOOK, name, status: 204, identifier: NEW_SERIAL });

const NEW_CARD = "{{newCard}}";
const newCard = script("prerequest", [
  'pm.environment.set("newCard", String(600000 + Math.floor(Math.random() * 100000)));'
]);

const randomReader = (example) => ({
  ...example,
  card_number: NEW_CARD,
  full_name: RANDOM_NAME,
  email: "{{$randomEmail}}"
});

const addReader = (name) => buildRequest({
  method: "POST", path: READERS, name, status: 201, events: [ newCard, filledIn ],
  body: randomReader(requestExample("POST", READERS, "new_reader")),
  examples: [ "created", "invalid_fields", "taken" ]
});
const updateReader = (name) => buildRequest({
  method: "PATCH", path: READER, name, status: 200, identifier: NEW_CARD,
  body: { full_name: RANDOM_NAME }, events: [ filledIn ],
  examples: [ "renamed", "new_card", "taken" ]
});
const deleteNewReader = (name) => buildRequest({ method: "DELETE", path: READER, name, status: 204, identifier: NEW_CARD });

const lend = requestExample("PATCH", STATUS, "lend");
const giveBack = requestExample("PATCH", STATUS, "return");

const books = [
  buildRequest({ method: "PATCH", path: STATUS, name: "Lends a book to a reader", status: 200, identifier: "000101", body: lend, examples: [ "lent", "already_borrowed", "unknown_reader", "missing_card_number", "invalid_status", "parameter_missing" ] }),
  buildRequest({ method: "PATCH", path: STATUS, name: "Marks a book returned", status: 200, identifier: "000101", body: giveBack, examples: [ "returned", "already_available" ] }),
  buildRequest({ method: "GET", path: BOOKS, name: "Lists books with their status and current borrower", status: 200, examples: [ "books", "second_page", "invalid_pagination", "bad_request", "internal_error" ] }),
  buildRequest({ method: "GET", path: BOOKS, name: "Searches books by author", status: 200, search: "author", examples: [ "by_author" ] }),
  buildRequest({ method: "GET", path: BOOKS, name: "Searches books by title", status: 200, search: "title", examples: [ "by_title" ] }),
  buildRequest({ method: "GET", path: BOOK, name: "Shows a book with its full borrowing history", status: 200, identifier: "000101" }),
  addBook("Adds a book with two authors", "two_authors"),
  deleteNewBook("Deletes the book with two authors"),
  addBook("Adds a book with one author", "one_author"),
  deleteNewBook("Deletes the book with one author")
];

const readers = [
  buildRequest({ method: "GET", path: READER, name: "Shows a reader", status: 200, identifier: "100001" }),
  buildRequest({ method: "GET", path: READER_BOOKS, name: "Lists the books a reader has on loan", status: 200, identifier: "100001", examples: [ "on_loan", "not_found", "invalid_pagination", "bad_request", "internal_error" ] }),
  buildRequest({ method: "GET", path: READER_BOOKS, name: "Lists a reader's full borrowing history", status: 200, identifier: "100002", search: "include_returned", examples: [ "with_returned" ] }),
  addReader("Adds a reader"),
  updateReader("Updates a reader"),
  deleteNewReader("Deletes the reader")
];

const refused = [
  buildRequest({ method: "PATCH", path: STATUS, name: "Lends a book already on loan", status: 409, errorCode: "already_borrowed", identifier: "000102", body: lend, examples: [ "already_borrowed" ] }),
  buildRequest({ method: "PATCH", path: STATUS, name: "Lends to a card no reader has", status: 422, errorCode: "unknown_reader", identifier: "000101", body: { ...lend, card_number: "999999" }, examples: [ "unknown_reader" ] }),
  buildRequest({ method: "GET", path: BOOK, name: "Shows a book that does not exist", status: 404, errorCode: "not_found", identifier: "999999", examples: [ "not_found" ] }),
  buildRequest({ method: "GET", path: READER, name: "Shows a reader that does not exist", status: 404, errorCode: "not_found", identifier: "999999", examples: [ "not_found" ] }),
  buildRequest({ method: "GET", path: READER_BOOKS, name: "Lists the books of a card no reader has", status: 404, errorCode: "not_found", identifier: "999999", examples: [ "not_found" ] }),
  buildRequest({ method: "POST", path: BOOKS, name: "Adds a book with a bad serial and no title", status: 422, errorCode: "invalid", body: { serial_number: "12a456", title: "", author: "Sandi Metz" }, examples: [ "invalid_fields" ] }),
  buildRequest({ method: "DELETE", path: BOOK, name: "Deletes a book on loan", status: 409, errorCode: "already_borrowed", identifier: "000102", examples: [ "already_borrowed" ] }),
  buildRequest({ method: "DELETE", path: READER, name: "Deletes a reader with loans", status: 409, errorCode: "has_loans", identifier: "100001", examples: [ "has_loans" ] })
];

collection.item = [ { name: "Books", item: books }, { name: "Readers", item: readers }, { name: "Refused requests", item: refused } ];

// The converter writes random ids on every run. An id from each item's position keeps the file stable.
const stableId = (position) => {
  const hash = crypto.createHash("sha1").update(position).digest("hex");

  return [ hash.slice(0, 8), hash.slice(8, 12), hash.slice(12, 16), hash.slice(16, 20), hash.slice(20, 32) ].join("-");
};

const replaceIds = (node, position) => {
  if (Array.isArray(node)) {
    node.forEach((child, index) => replaceIds(child, `${position}/${index}`));
  } else if (node && typeof node === "object") {
    for (const [ key, value ] of Object.entries(node)) {
      if (key === "id" || key === "_postman_id") {
        node[key] = stableId(`${position}/${key}`);
      } else {
        replaceIds(value, `${position}/${key}`);
      }
    }
  }
};

for (const folder of collection.item) {
  folder.id = "";
  for (const item of folder.item) item.id = "";
}
replaceIds(collection, "");
fs.writeFileSync(collectionFile, `${JSON.stringify(collection, null, 2)}\n`);
