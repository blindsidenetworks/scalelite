# frozen_string_literal: true

module ApplicationErrors
  class ApplicationError < StandardError
    attr_accessor :return_code
    attr_accessor :message_key
    attr_accessor :message

    def initialize(message_key = '', message = '')
      @return_code = 'FAILED'
      @message_key = message_key if message_key.present?
      @message = message if message.present?
    end

    def to_s
      "#{@message_key}: #{@message}"
    end
  end

  class ChecksumError < ApplicationError
    def initialize
      super('checksumError', 'Failed to pass the checksum security check')
    end
  end

  class ServerNotFoundError < ApplicationError
    def initialize
      super('notFound', 'Could not find server with this ID' )
    end
  end

  class MissingServerIDError < ApplicationError
    def initialize
      super('missingParamServerID', 'Server ID was not provided')
    end
  end

  class MissingServerURLError < ApplicationError
    def initialize
      super('missingParamServerURL', 'Server URL was not provided')
    end
  end

  class MissingServerSecretError < ApplicationError
    def initialize
      super('missingParamServerSecret', 'Server secret was not provided')
    end
  end

  class MissingLoadMultiplierError < ApplicationError
    def initialize
      super('missingParamLoadMutliplier', 'Server load multiplier was not provided')
    end
  end

  class UnsupportedRequestError < ApplicationError
    def initialize
      super('unsupportedRequest', 'Request is not supported')
    end
  end

  class InternalError < ApplicationError
    def initialize(error)
      super('internalError', error)
    end
  end
end
