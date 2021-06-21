# frozen_string_literal: true

module BBBErrors
  class BBBError < StandardError
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
end
