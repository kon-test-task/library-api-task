require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def missing_param
      params.require(:status)
      head :ok
    end

    def invalid_record
      Book.create!(serial_number: "bad", title: "")
    end

    def missing_record
      Book.find_by!(serial_number: "999999")
    end

    def missing_record_without_model
      raise ActiveRecord::RecordNotFound
    end

    def state_conflict
      raise Class.new(ConflictError) {
        def self.name = "Shelf::AlreadyFull"
        def message = "Shelf is full"
      }
    end

    def bad_input
      raise Class.new(InvalidInputError) {
        def self.name = "Shelf::UnknownLabel"
        def message = "No such label"
        def field = :label
      }
    end

    def unparsable_body
      raise ActionDispatch::Http::Parameters::ParseError, "bad body"
    end

    def unexpected_failure
      raise "boom"
    end

    def fine
      head :ok
    end
  end

  before do
    routes.draw do
      %w[missing_param invalid_record missing_record missing_record_without_model state_conflict bad_input unparsable_body unexpected_failure fine].each do |action|
        get action => "anonymous##{action}"
      end
    end
  end

  let(:errors) { JSON.parse(response.body)["errors"] }

  it "renders a missing parameter as 422 and names the field" do
    get :missing_param

    expect(response).to have_http_status(:unprocessable_content)
    expect(errors).to eq([ { "code" => "parameter_missing", "message" => "status is required", "field" => "status" } ])
  end

  it "renders every validation error from RecordInvalid as 422" do
    get :invalid_record

    expect(response).to have_http_status(:unprocessable_content)
    expect(errors.map { |error| error["field"] }).to contain_exactly("serial_number", "title", "authors")
    expect(errors.map { |error| error["code"] }).to contain_exactly("invalid", "blank", "blank")
  end

  it "names the model in a 404" do
    get :missing_record

    expect(response).to have_http_status(:not_found)
    expect(errors).to eq([ { "code" => "not_found", "message" => "Book not found", "field" => nil } ])
  end

  it "falls back to a generic name when the 404 has no model" do
    get :missing_record_without_model

    expect(errors.first["message"]).to eq("Record not found")
  end

  it "renders any ConflictError as 409, with the code from its class name" do
    get :state_conflict

    expect(response).to have_http_status(:conflict)
    expect(errors).to eq([ { "code" => "already_full", "message" => "Shelf is full", "field" => nil } ])
  end

  it "renders any InvalidInputError as 422, with its code and field" do
    get :bad_input

    expect(response).to have_http_status(:unprocessable_content)
    expect(errors).to eq([ { "code" => "unknown_label", "message" => "No such label", "field" => "label" } ])
  end

  it "renders an unparsable body as 400" do
    get :unparsable_body

    expect(response).to have_http_status(:bad_request)
    expect(errors.first).to include("code" => "invalid_json", "field" => nil)
  end

  it "does not swallow unexpected errors" do
    expect { get :unexpected_failure }.to raise_error(RuntimeError, "boom")
  end

  describe "null bytes" do
    it "stops the action and renders 422" do
      get :fine, params: { note: "a\u0000b" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(errors.first["code"]).to eq("invalid_characters")
    end

    it "finds one inside nested parameters" do
      get :fine, params: { outer: { inner: [ "a\u0000b" ] } }

      expect(errors.first["code"]).to eq("invalid_characters")
    end

    it "lets ordinary parameters through" do
      get :fine, params: { note: "100%00 sure" }

      expect(response).to have_http_status(:ok)
    end
  end
end
