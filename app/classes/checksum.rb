# frozen_string_literal: true

class Checksum
  CHECKSUM_LENGTH_SHA1 = 40
  CHECKSUM_LENGTH_SHA256 = 64
  CHECKSUM_LENGTH_SHA512 = 128

  private :initialize

  def initialize
  end

  def self.get_algorithm(checksum = nil)
    case ENV['ENFORCE_CHECKSUM_ALGORITHM']
    when nil
      return ChecksumSha256.new if checksum.nil?
      case checksum.size
      when CHECKSUM_LENGTH_SHA1
          ChecksumSha1.new
      when CHECKSUM_LENGTH_SHA256
          ChecksumSha256.new
      when CHECKSUM_LENGTH_SHA512
          ChecksumSha512.new
      else
          raise ChecksumError
      end
    when 'SHA1'
      ChecksumSha1.new
    when 'SHA256'
      ChecksumSha256.new
    when 'SHA512'
      ChecksumSha512.new
    else
      raise ChecksumError
    end
  end

  def self.verify(data, checksum)
    get_algorithm(checksum).verify(data, checksum)
  end

  def self.generate(data)
    get_algorithm.generate(data)
  end
end
