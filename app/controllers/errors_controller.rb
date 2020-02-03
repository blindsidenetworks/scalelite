# frozen_string_literal: true

class ErrorsController < ApplicationController
  # Handles all unsupported requests (inccuding root)
  def unsupported_request
    raise UnsupportedRequestError
  end
end
