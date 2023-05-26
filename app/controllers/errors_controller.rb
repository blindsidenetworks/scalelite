# frozen_string_literal: true

class ErrorsController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Handles all unsupported requests (inccuding root)
  def unsupported_request
    raise UnsupportedRequestError
  end
end
