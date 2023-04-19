# frozen_string_literal: true

require 'net/http'

# The following is necessary to fix a DNS resolution timeout bug see https://github.com/ruby/ruby/pull/597#issuecomment-40507119
require 'resolv-replace'

module ApiHelper
  extend ActiveSupport::Concern
  include BBBErrors

  CHECKSUM_LENGTH_SHA1 = 40
  CHECKSUM_LENGTH_SHA256 = 64
  CHECKSUM_LENGTH_SHA512 = 128

  # Verify checksum
  def verify_checksum
    secrets = Rails.configuration.x.loadbalancer_secrets

    raise ChecksumError if params[:checksum].blank?
    raise ChecksumError if secrets.empty?

    algorithm = case params[:checksum].length
                   when CHECKSUM_LENGTH_SHA1
                     'SHA1'
                   when CHECKSUM_LENGTH_SHA256
                     'SHA256'
                   when CHECKSUM_LENGTH_SHA512
                     'SHA512'
                   else
                     raise ChecksumError
                   end

    # Camel case (ex) get_meetings to getMeetings to match BBB server
    check_string = action_name.camelcase(:lower)
    check_string += request.query_string.gsub(
      /&checksum=#{params[:checksum]}|checksum=#{params[:checksum]}&|checksum=#{params[:checksum]}/, ''
    )

    allowed_checksum_algorithms = Rails.configuration.x.loadbalancer_checksum_algorithms
    raise ChecksumError unless allowed_checksum_algorithms.include? algorithm

    secrets.each do |secret|
      return true if ActiveSupport::SecurityUtils.secure_compare(get_checksum(check_string + secret, algorithm),
                                                                 params[:checksum])
    end

    raise ChecksumError
  end

  def get_checksum(check_string, checksum_algorithm)
    return Digest::SHA512.hexdigest(check_string) if checksum_algorithm == 'SHA512'
    return Digest::SHA256.hexdigest(check_string) if checksum_algorithm == 'SHA256'
    Digest::SHA1.hexdigest(check_string)
  end

  def checksum_algorithm
    # rubocop:disable Rails/EnvironmentVariableAccess
    # default to SHA256 unless explicitly specified
    return 'SHA256' if ENV['LOADBALANCER_CHECKSUM_ALGORITHM'].blank?
    # rubocop:enable Rails/EnvironmentVariableAccess

    algos = Rails.configuration.x.loadbalancer_checksum_algorithms

    if algos.include? "SHA512"
      "SHA512"
    elsif algos.include? "SHA256"
      "SHA256"
    else
      "SHA1"
    end
  end

  # Encode URI and append checksum
  def encode_bbb_uri(action, base_uri, secret, bbb_params = {})
    # Add slash at the end if its not there
    base_uri += '/' unless base_uri.ends_with?('/')

    bbb_params = add_additional_params(action, bbb_params)

    check_string = URI.encode_www_form(bbb_params)
    checksum = get_checksum(action + check_string + secret, checksum_algorithm)

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

  def decoded_token(token)
    Rails.configuration.x.loadbalancer_secrets.any? do |secret|
      JWT.decode(token, secret, true, algorithm: 'HS512')
    rescue JWT::DecodeError
      false
    end
  end

  def valid_token?(token)
    decoded_token(token)
  end

  def post_req(uri, body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    exp = Time.now.to_i + (24 * 3600)
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

  def add_additional_params(action, bbb_params)
    bbb_params = bbb_params.symbolize_keys

    case action
    when 'create'
      # Merge with the default (bbb_params takes precedence)
      final_params = Rails.configuration.x.default_create_params.merge(bbb_params)
      # Merge with the override (override takes precedence)
      final_params.merge(Rails.configuration.x.override_create_params)
    when 'join'
      # Merge with the default (bbb_params takes precedence)
      final_params = Rails.configuration.x.default_join_params.merge(bbb_params)
      # Merge with the override (override takes precedence)
      final_params.merge(Rails.configuration.x.override_join_params)
   else
     bbb_params
   end
  end
end
