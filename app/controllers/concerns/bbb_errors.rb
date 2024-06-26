# frozen_string_literal: true

module BBBErrors
  class BBBError < StandardError
    attr_accessor :return_code, :message_key, :message

    def initialize(message_key = '', message = '')
      super()
      @return_code = 'FAILED'
      @message_key = message_key if message_key.present?
      @message = message if message.present?
    end

    def to_s
      "#{@message_key}: #{@message}"
    end
  end

  class ChecksumError < BBBError
    def initialize
      super('checksumError', 'You did not pass the checksum security check')
    end
  end

  class MeetingNotFoundError < BBBError
    def initialize
      super('notFound', 'We could not find a meeting with that meeting ID - perhaps the meeting is not yet running?')
    end
  end

  class MissingMeetingIDError < BBBError
    def initialize
      super('missingParamMeetingID', 'You must specify a meeting ID for the meeting.')
    end
  end

  class UnsupportedRequestError < BBBError
    def initialize
      super('unsupportedRequest', 'This request is not supported.')
    end
  end

  class UnsupportedContentType < BBBErrors::BBBError
    def initialize
      super('unsupportedContentType', 'POST request Content-Type is missing or unsupported')
    end
  end

  class InternalError < BBBError
    def initialize(error)
      super('internalError', error)
    end
  end

  class ServerUnavailableError < BBBError
    def initialize
      super('serverUnavailable', 'The server for this meeting is disabled/offline.')
    end
  end

  class ServerTagUnavailableError < BBBError
    def initialize(tag)
      super('serverTagUnavailable', "There is no available server with the required tag=#{tag}.")
    end
  end
end
