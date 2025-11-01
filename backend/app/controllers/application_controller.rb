# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :set_request_id

  private

  def set_request_id
    # Store request ID in thread-local variable for logging correlation
    Thread.current[:request_id] = request.request_id
  end
end
