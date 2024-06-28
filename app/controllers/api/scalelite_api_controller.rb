# frozen_string_literal: true

module Api
  class ScaleliteApiController < ApplicationController
    include ApiHelper

    skip_before_action :verify_authenticity_token

    before_action :verify_content_type
    before_action -> { verify_checksum(true) }

    def verify_content_type
      return unless request.post? && request.content_length.positive?

      raise UnsupportedContentType unless request.content_mime_type == Mime[:json]
    end
  end
end
