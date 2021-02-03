# frozen_string_literal: true

require 'net/http'

module ApiHelper
  extend ActiveSupport::Concern
  include BBBErrors

  REQUEST_TIMEOUT = 10
  CHECKSUM_LENGTH = 40

  # Verify checksum
  def verify_checksum
    raise ChecksumError unless params[:checksum].present? && params[:checksum].length == CHECKSUM_LENGTH

    # Camel case (ex) get_meetings to getMeetings to match BBB server
    check_string = action_name.camelcase(:lower)
    check_string += request.query_string.gsub(
      /&checksum=#{params[:checksum]}|checksum=#{params[:checksum]}&|checksum=#{params[:checksum]}/, ''
    )

    return if Rails.configuration.x.loadbalancer_secrets.any? do |secret|
      checksum = Digest::SHA1.hexdigest(check_string + secret)
      ActiveSupport::SecurityUtils.fixed_length_secure_compare(checksum, params[:checksum])
    end

    raise ChecksumError
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

  # GET/POST request
  def get_post_req(uri, body = '')
    # If body is passed and has a value, setup POST request
    if body.present?
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-Type'] = 'application/xml'
      req.body = body
    else
      req = Net::HTTP::Get.new(uri.request_uri)
    end

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: REQUEST_TIMEOUT, read_timeout: REQUEST_TIMEOUT) do |http|
      res = http.request(req)
      doc = Nokogiri::XML(res.body)
      returncode = doc.at_xpath('/response/returncode')
      raise InternalError, 'Response did not include returncode' if returncode.nil?
      if returncode.content != 'SUCCESS'
        raise BBBError.new(doc.at_xpath('/response/messageKey').content, doc.at_xpath('/response/message').content)
      end

      doc
    end
  end
end
