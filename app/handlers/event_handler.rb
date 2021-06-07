# frozen_string_literal: true

class EventHandler
  attr_accessor :params, :meeting_id

  def initialize(params, *args)
    @params = params
    @meeting_id = args[0]
  end

  def handle
    AnalyticsCallbackEventHandler.new(params, meeting_id).handle
    RecordingReadyEventHandler.new(params, meeting_id).handle
    params
  end
end
