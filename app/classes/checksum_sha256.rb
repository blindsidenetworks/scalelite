# frozen_string_literal: true

class ChecksumSha256 < ChecksumSha1
  def generate(data)
    Digest::SHA256.hexdigest data
  end
end
