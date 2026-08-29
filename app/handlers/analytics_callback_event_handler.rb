# frozen_string_literal: true

class AnalyticsCallbackEventHandler < EventHandler
  attr_accessor :analytics_callback_url

  def initialize(params, meeting_id, tenant = nil)
    super
    @analytics_callback_url = params['meta_analytics-callback-url']
  end

  def handle
    return if analytics_callback_url.nil?

    # Use ANALYTICS_CALLBACK_URL_HOST if set (for HA/proxy deployments)
    # Otherwise fall back to URL_HOST (for direct deployments)
    host_name = Rails.configuration.x.analytics_callback_url_host || Rails.configuration.x.url_host

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
