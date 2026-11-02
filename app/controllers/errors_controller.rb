class ErrorsController < ApplicationController
  def route_not_found
    render_error(:not_found, code: "route_not_found", message: "Route not found")
  end
end
