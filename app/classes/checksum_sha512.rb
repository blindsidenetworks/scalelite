# frozen_string_literal: true

class ChecksumSha512 < ChecksumSha1
  def generate(data)
    Digest::SHA512.hexdigest data
  end
end
