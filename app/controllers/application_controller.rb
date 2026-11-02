class ApplicationController < ActionController::API
  before_action :refuse_null_bytes

  # Rails checks handlers from the last one declared, so this catch-all stays first.
  rescue_from StandardError do |error|
    logger.error(([ "#{error.class}: #{error.message}" ] + Array(error.backtrace)).join("\n"))
    render_error(:internal_server_error, code: "internal_error", message: "Something went wrong")
  end

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error(:bad_request, code: "invalid_json", message: "Request body is not valid JSON")
  end

  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error(:not_found, code: "not_found", message: "#{error.model || "Record"} not found")
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error(:unprocessable_content, code: "parameter_missing", message: "#{error.param} is required", field: error.param)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_record_errors(error.record)
  end

  rescue_from ConflictError do |error|
    render_error(:conflict, code: error.code, message: error.message, field: error.field)
  end

  rescue_from InvalidInputError do |error|
    render_error(:unprocessable_content, code: error.code, message: error.message, field: error.field)
  end

  private

  # Rails reads the query string in its instrumentation layer, before rescue_from applies, so this rescue sits outside that layer.
  def process_action(*)
    super
  rescue ActionController::BadRequest
    render_error(:bad_request, code: "bad_request", message: "Request parameters could not be read")
  end

  # The Postgres driver raises ArgumentError on a null byte in any string it sends.
  def refuse_null_bytes
    # The body is checked too, because a path parameter overwrites a body field of the same name in params.
    return unless [ params.to_unsafe_h, request.request_parameters ].any? { |values| values.to_query.include?("%00") }

    render_error(:unprocessable_content, code: "invalid_characters", message: "Parameters must not contain null bytes")
  end

  def render_error(status, code:, message:, field: nil)
    render status: status, json: { errors: [ { code: code, message: message, field: field } ] }
  end

  def render_record_errors(record)
    errors = record.errors.map do |error|
      { code: error.type.to_s, message: error.full_message, field: (error.attribute unless error.attribute == :base) }
    end

    render status: :unprocessable_content, json: { errors: errors }
  end
end
