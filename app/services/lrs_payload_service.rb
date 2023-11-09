# frozen_string_literal: true

class LrsPayloadService
  def initialize(tenant:, secret:)
    @tenant = tenant
    @secret = secret
  end

  def call
    Rails.logger.debug { "Fetching LRS token from #{@tenant.kc_token_url}" }

    url = URI.parse(@tenant.kc_token_url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')

    payload = {
      client_id: @tenant.kc_client_id,
      client_secret: @tenant.kc_client_secret,
      username: @tenant.kc_username,
      password: @tenant.kc_password,
      grant_type: 'password'
    }

    request = Net::HTTP::Post.new(url.path)
    request.set_form_data(payload)

    response = http.request(request)

    if response.code.to_i != 200
      Rails.logger.warn("Error #{response.message} when trying to fetch LRS Access Token")
      return nil
    end

    parsed_response = JSON.parse(response.body)
    kc_access_token = parsed_response['access_token']

    lrs_payload = {
      lrs_endpoint: @tenant.lrs_endpoint,
      lrs_token: kc_access_token
    }

    # Generate a random salt
    salt = SecureRandom.random_bytes(8)

    # Generate a key and initialization vector (IV) using PBKDF2 with SHA-256
    key_iv = OpenSSL::PKCS5.pbkdf2_hmac(@secret, salt, 10_000, 48, OpenSSL::Digest.new('SHA256'))
    key = key_iv[0, 32]  # 32 bytes for the key
    iv = key_iv[32, 16]  # 16 bytes for the IV

    # Encrypt the data using AES-256-CBC
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv

    # Encrypt and Base64 encode the data
    Base64.strict_encode64(Random.random_bytes(8) + salt + cipher.update(lrs_payload.to_json) + cipher.final)
  rescue StandardError => e
    Rails.logger.warn("Error #{e} when trying to compute LRS Payload")

    nil
  end
end
