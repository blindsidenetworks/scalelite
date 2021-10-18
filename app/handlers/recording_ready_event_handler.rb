# frozen_string_literal: true

class RecordingReadyEventHandler < EventHandler
  attr_accessor :callback_url

  def initialize(params, *args)
    super
  end

  def handle
    set_callback_url
    return if callback_url.nil?

    params.delete('meta_bbb-recording-ready-url')
    params.delete('meta_canvas-recording-ready-url')
    params.delete('meta_bn-recording-ready-url')

    callback_data = CallbackData.find_or_create_by!(meeting_id: meeting_id)
    callback_attributes = callback_data.callback_attributes || {}
    callback_data.callback_attributes = callback_attributes.merge!(recording_ready_url: callback_url)
    callback_data.save!
  end

  def set_callback_url
    # For compatibility with some 3rd party implementations, look up for meta_bbb-recording-ready-url or
    # meta_canvas-recording-ready, when meta_bn-recording-ready-url is not included.
    @callback_url = params['meta_bn-recording-ready-url']
    @callback_url ||= params['meta_bbb-recording-ready-url']
    @callback_url || params['meta_canvas-recording-ready-url']
  end
end
