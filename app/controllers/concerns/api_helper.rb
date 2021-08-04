# frozen_string_literal: true

require 'net/http'

module ApiHelper
  extend ActiveSupport::Concern
  include BBBErrors

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

  # Calculate a timeout based on server state to pass to get_post_req options
  def bbb_req_timeout(server)
    unless server.online
      # Use values that are 1/10 the normal values, but clamp to a minimum.
      # If the original configured timeout value is below the minimum, then use that instead.
      return {
        open_timeout: [[0.2, Rails.configuration.x.open_timeout].min, Rails.configuration.x.open_timeout / 10].max,
        read_timeout: [[0.5, Rails.configuration.x.read_timeout].min, Rails.configuration.x.read_timeout / 10].max,
      }
    end

    {}
  end

  def encoded_token(payload)
    secret = Rails.configuration.x.loadbalancer_secrets[0]
    JWT.encode(payload, secret, 'HS512', typ: 'JWT')
  end

  def post_req(uri, body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    exp = Time.now.to_i + 24 * 3600
    token = encoded_token(exp: exp)
    # Setup a request and attach our JWT token
    request = Net::HTTP::Post.new(uri.request_uri,
                                  'Content-Type' => 'application/json',
                                  'Authorization' => "Bearer #{token}",
                                  'User-Agent' => 'BigBlueButton Analytics Callback')
    # Send out data as json body
    request.body = body.to_json
    logger.info("Sending request to #{uri.scheme}://#{uri.host}#{uri.request_uri}")
    http.request(request)
  end

  # GET/POST request
  def get_post_req(uri, body = '', **options)
    # If body is passed and has a value, setup POST request
    if body.present?
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-Type'] = 'application/xml'
      req.body = body
    else
      req = Net::HTTP::Get.new(uri.request_uri)
    end

    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: options.fetch(:open_timeout) { Rails.configuration.x.open_timeout },
      read_timeout: options.fetch(:read_timeout) { Rails.configuration.x.read_timeout }
    ) do |http|
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
