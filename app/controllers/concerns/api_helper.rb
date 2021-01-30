# frozen_string_literal: true

require 'net/http'

module ApiHelper
  extend ActiveSupport::Concern
  include ApplicationErrors

  REQUEST_TIMEOUT = 10
  CHECKSUM_LENGTH = 40

  # Verify checksum
  def verify_checksum
    raise ChecksumError unless params[:checksum].present? && params[:checksum].length == CHECKSUM_LENGTH

    check_string = request.query_string.gsub(
      /&checksum=#{params[:checksum]}|checksum=#{params[:checksum]}&|checksum=#{params[:checksum]}/,
      ''
    )

    # Camel case (ex) get_meetings to getMeetings to match BBB server
    checksum = Digest::SHA1.hexdigest(action_name.camelcase(:lower) + check_string + Rails.configuration.x.app_secret)

    raise ChecksumError unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(checksum, params[:checksum])
  end

  # Encode URI and append checksum
  def encode_bbb_uri(action, base_uri, secret, bbb_params = {})
    # Add slash at the end if its not there
    base_uri += '/' unless base_uri.ends_with?('/')
    check_string = URI.encode_www_form(bbb_params)
    checksum = Digest::SHA1.hexdigest(action + check_string + secret)
    uri = URI.join(base_uri, action)
    uri.query = URI.encode_www_form(bbb_params.merge(checksum: checksum))
    uri
  end
end
