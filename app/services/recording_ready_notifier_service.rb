# frozen_string_literal: true

require 'jwt'
require 'net/http'

class RecordingReadyNotifierService
  class << self
    include ApiHelper

    def execute(recording_id)
      recording = Recording.find(recording_id)
      meeting_id = recording.meeting_id
      callback_data = CallbackData.find_by(meeting_id: meeting_id)
      return if callback_data.nil?

      callback_url = callback_data.callback_attributes[:recording_ready_url]

      tenant_id = Metadatum.find_by(recording_id: recording.id, key: 'tenant-id')&.value
      tenant_name = tenant_id.present? ? Tenant.find(tenant_id)&.name : nil

      notify(callback_url, meeting_id, recording.record_id, tenant_name) if callback_url
    end

    def encoded_payload(meeting_id, record_id, secret)
      payload = { meeting_id: meeting_id, record_id: record_id }
      JWT.encode(payload, secret)
    end

    def notify(callback_url, meeting_id, record_id, tenant_name)
      logger.info("Recording Ready Notify for [#{meeting_id}] starts")
      logger.info('Making callback for recording ready notification')

      secrets = fetch_secrets(tenant_name: tenant_name)
      success = false

      secrets.each do |secret|
        payload = encoded_payload(meeting_id, record_id, secret)

        uri = URI.parse(callback_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        logger.info("Sending request to #{uri.scheme}://#{uri.host}#{uri.request_uri}")
        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data(signed_parameters: payload)

        response = http.request(request)
        code = response.code.to_i

        if code == 410
          logger.info("Notified for deleted meeting: #{meeting_id}")
          break
        elsif code == 404
          logger.info("404 error when notifying for recording: #{meeting_id}, ignoring")
          break
        elsif code < 200 || code >= 300
          logger.info("Callback HTTP request failed: #{response.code} #{response.message} (code #{code})")
        else
          logger.info("Recording notifier successful: #{meeting_id} (code #{code})")
          success = true
          break
        end
      end

      success
    rescue StandardError => e
      logger.info('Rescued')
      logger.info(e.to_s)
      false
    end

    def logger
      Rails.logger
    end
  end
end
