# frozen_string_literal: true

class AnalyticsCallbackEventHandler < EventHandler
  attr_accessor :analytics_callback_url

  def initialize(params, meeting_id, tenant = nil)
    super
    @analytics_callback_url = params['meta_analytics-callback-url']
  end

  def handle
    return if analytics_callback_url.nil?

    host_name = Rails.configuration.x.url_host

    params['meta_analytics-callback-url'] = if tenant.present?
      "https://#{tenant.name}.#{host_name}/bigbluebutton/api/analytics_callback"
    else
      "https://#{host_name}/bigbluebutton/api/analytics_callback"
    end

    callback_attributes = { analytics_callback_url: analytics_callback_url }
    callback_data = CallbackData.find_or_create_by!(meeting_id: meeting_id)
    callback_data.update!(callback_attributes: callback_attributes)
  end
end
