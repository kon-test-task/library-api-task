# Offset pagination for list endpoints: page and limit params, with the metadata in the body (D12).
module Paginated
  extend ActiveSupport::Concern
  include Pagy::Method

  MAX_LIMIT = 100
  META_KEYS = %i[count page limit last previous next].freeze

  included do
    rescue_from Pagy::OptionError do |error|
      render_error(:unprocessable_content, code: "invalid_pagination", message: "#{error.option} must be at least 1", field: error.option)
    end
  end

  private

  def paginate(scope)
    pagination, records = pagy(scope, client_limit: MAX_LIMIT)

    [ records, pagination.data_hash(data_keys: META_KEYS) ]
  end
end
