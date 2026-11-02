require "rails_helper"

# The image has no Node, so bin/ci cannot regenerate the collection. This holds the committed file to swagger.yaml.
RSpec.describe "Postman collection" do
  let(:collection) { JSON.parse(Rails.root.join("postman/library-api.postman_collection.json").read) }
  let(:openapi) { YAML.safe_load_file(Rails.root.join("swagger/v1/swagger.yaml")) }
  let(:operations) { openapi["paths"].values.flat_map(&:values) }
  let(:folders) { collection["item"].to_h { |folder| [ folder["name"], folder["item"] ] } }
  let(:books) { folders.fetch("Books") }
  let(:readers) { folders.fetch("Readers") }
  let(:refused) { folders.fetch("Refused requests") }
  let(:book_requests) { books.pluck("request") }

  def path_values(items, key)
    items.flat_map { |item| item["request"]["url"]["variable"].to_a }.select { |variable| variable["key"] == key }.pluck("value")
  end

  def scripts(item, listen)
    item["event"].select { |event| event["listen"] == listen }.flat_map { |event| event["script"]["exec"] }.join("\n")
  end

  it "points at the local app through a baseUrl variable" do
    expect(collection["variable"]).to include("key" => "baseUrl", "value" => "http://localhost:3000")
  end

  it "ships a sample environment with the same baseUrl and a slot for the generated serial" do
    environment = JSON.parse(Rails.root.join("postman/library-api.postman_environment.json").read)

    expect(environment["values"]).to contain_exactly(
      a_hash_including("key" => "baseUrl", "value" => "http://localhost:3000", "enabled" => true),
      a_hash_including("key" => "newSerial", "value" => "", "enabled" => true)
    )
  end

  it "has a request for every documented operation" do
    documented = openapi["paths"].flat_map do |path, verbs|
      verbs.keys.map { |verb| [ verb.upcase, path.gsub(/\{(\w+)\}/, ':\1') ] }
    end
    collected = (books + readers).pluck("request").map { |request| [ request["method"], "/#{request['url']['path'].join('/')}" ] }

    expect(collected.uniq).to match_array(documented)
  end

  it "lends and returns a book" do
    bodies = book_requests.select { |request| request["method"] == "PATCH" }.map { |request| JSON.parse(request["body"]["raw"]) }

    expect(bodies).to eq([ { "status" => "borrowed", "card_number" => "100001" }, { "status" => "available" } ])
  end

  it "adds books with the documented fields and generated values" do
    documented = openapi.dig("paths", "/api/v1/books", "post", "requestBody", "content", "application/json", "examples").values.pluck("value")
    bodies = book_requests.select { |request| request["method"] == "POST" }.map { |request| JSON.parse(request["body"]["raw"]) }

    expect(bodies.map(&:keys)).to match_array(documented.map(&:keys))
    expect(bodies.pluck("serial_number")).to all(eq("{{newSerial}}"))
    expect(bodies.pluck("title")).to all(eq("{{$randomCatchPhrase}}"))
    expect(bodies.flat_map { |body| Array(body["author"]) + Array(body["authors"]) }).to all(eq("{{$randomFullName}}"))
  end

  it "deletes each new book straight after adding it" do
    methods = book_requests.map { |request| request["method"] }
    additions = methods.each_index.select { |index| methods[index] == "POST" }

    expect(additions.size).to eq(2)
    additions.each do |index|
      expect(scripts(books[index], "prerequest")).to include('pm.environment.set("newSerial"')
      expect(methods[index + 1]).to eq("DELETE")
      expect(path_values([ books[index + 1] ], "serial_number")).to eq([ "{{newSerial}}" ])
    end
  end

  it "uses serial and card numbers the seeds create" do
    Rails.application.load_seed

    serials = path_values(books + refused, "serial_number").grep(/\A\d{6}\z/) - [ "999999" ]
    cards = path_values(readers, "card_number") +
      book_requests.filter_map { |request| request.dig("body", "raw") }.filter_map { |raw| JSON.parse(raw)["card_number"] }

    expect(serials).not_to be_empty
    expect(Book.where(serial_number: serials).count).to eq(serials.uniq.size)
    expect(Reader.where(card_number: cards).count).to eq(cards.uniq.size)
  end

  it "sends no optional query parameter on the plain list" do
    plain = books.find { |item| item["name"].start_with?("Lists books") }

    expect(plain["request"]["url"]["query"]).to all(include("disabled" => true))
  end

  it "has one search request for each search parameter, and each finds a seeded book" do
    Rails.application.load_seed

    enabled = book_requests.flat_map { |request| request["url"]["query"].to_a }.reject { |parameter| parameter["disabled"] }
    values = enabled.to_h { |parameter| [ parameter["key"], parameter["value"] ] }

    expect(enabled.size).to eq(2)
    expect(Book.by_author(values.fetch("author")).pluck(:serial_number)).to eq([ "000101" ])
    expect(Book.by_title(values.fetch("title")).pluck(:serial_number)).to eq([ "000102" ])
  end

  it "turns on the returned loans only for the reader history request" do
    query = readers.to_h { |item| [ item["name"], item["request"]["url"]["query"].reject { |parameter| parameter["disabled"] } ] }

    expect(query.fetch("Lists the books a reader has on loan")).to be_empty
    expect(query.fetch("Lists a reader's full borrowing history")).to contain_exactly(a_hash_including("key" => "include_returned", "value" => "true"))
  end

  it "saves only responses the OpenAPI file documents" do
    documented = operations.flat_map { |operation| operation["responses"].values }
      .flat_map { |response| response.dig("content", "application/json", "examples").to_h.values.pluck("value") }
    saved = (books + readers + refused).flat_map { |item| item["response"] }
      .reject { |response| response["body"].empty? }
      .map { |response| JSON.parse(response["body"]) }

    expect(saved).not_to be_empty
    expect(documented).to include(*saved)
  end

  it "saves a response on every request and checks the status of each" do
    (books + readers + refused).each do |item|
      expect(item["response"]).not_to be_empty, "#{item['name']} has no saved response"
      expect(scripts(item, "test")).to include("pm.response.to.have.status")
    end
  end

  it "refuses every request in the refused folder with a documented error" do
    expect(refused.size).to eq(6)

    refused.each do |item|
      expect(item["response"].pluck("code")).to all(be_between(400, 499))
      expect(scripts(item, "test")).to include("errors[0].code")
    end
  end
end
