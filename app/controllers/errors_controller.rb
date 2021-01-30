# frozen_string_literal: true

class ErrorsController < ApplicationController
  def unsupported_request
    raise UnsupportedRequestError
  end
end
