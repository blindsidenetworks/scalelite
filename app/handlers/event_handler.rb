# frozen_string_literal: true

class EventHandler
  attr_accessor :params, :meeting_id, :event_data

  def initialize(params, *args)
    @params = params
    @meeting_id = args[0]
  end

  def handle
    @event_data = RecordingReadyEventHandler.new(params, meeting_id, event_data).handle
    return_values
  end

  def return_values
    [params, event_data]
  end
end
