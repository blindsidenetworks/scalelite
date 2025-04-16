# frozen_string_literal: true

class EventHandler
  attr_accessor :params, :meeting_id, :tenant

  def initialize(params, meeting_id, tenant = nil)
    @params = params
    @meeting_id = meeting_id
    @tenant = tenant
  end

  def handle
    AnalyticsCallbackEventHandler.new(params, meeting_id, tenant).handle
    RecordingReadyEventHandler.new(params, meeting_id).handle
    params
  end
end
