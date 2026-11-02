class ApplicationController < ActionController::API
  before_action :refuse_null_bytes

  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error(:not_found, code: "not_found", message: "#{error.model || "Record"} not found")
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(:unprocessable_content, code: "parameter_missing", message: "#{error.param} is required", field: error.param)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_record_errors(error.record)
  end

  private

  # Rails parses the body before rescue_from applies, so this rescue sits outside that layer.
  def process_action(*)
    super
  rescue ActionDispatch::Http::Parameters::ParseError
    render_error(:bad_request, code: "invalid_json", message: "Request body is not valid JSON")
  end

  # The Postgres driver raises ArgumentError on a null byte in any string it sends.
  def refuse_null_bytes
    return unless params.to_unsafe_h.to_query.include?("%00")

    render_error(:unprocessable_content, code: "invalid_characters", message: "Parameters must not contain null bytes")
  end

  def render_error(status, code:, message:, field: nil)
    render status: status, json: { errors: [ { code: code, message: message, field: field } ] }
  end

  def render_record_errors(record, status: :unprocessable_content)
    errors = record.errors.map do |error|
      { code: error.type.to_s, message: error.full_message, field: (error.attribute unless error.attribute == :base) }
    end

    render status: status, json: { errors: errors }
  end
end
