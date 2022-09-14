# frozen_string_literal: true

require 'digest'
require 'active_support'
require 'bbb_errors'

class ChecksumSha1
  include BBBErrors

  def generate(data)
    Digest::SHA1.hexdigest data
  end

  def verify(data, checksum)
    return true if Rails.configuration.x.loadbalancer_secrets.any? do |secret|
      generated_checksum = generate(data + secret)
      ActiveSupport::SecurityUtils.secure_compare(generated_checksum, checksum)
    end
    raise ChecksumError
  end
end
