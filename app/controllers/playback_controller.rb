# frozen_string_literal: true

class PlaybackController < ApplicationController
  include ApiHelper
  def play
    recording = Recording.find_by(record_id: playback_params[:record_id])
    raise RecordingNotFoundError if recording.nil?

    if recording.protected
      begin
        raise RecordingNotFoundError if params[:token].blank?

        permit = recording.validate_token(params[:token])
        deliver_resource(permit)
      rescue JWT::DecodeError
        deliver_resource(false)
      end
    else
      # If recording isn't protected, don't check tokens
      deliver_resource(true)
    end
  end

  def resource
    deliver_resource(true)
  end

  private

  def playback_params
    params.permit(:playback_format, :player_version, :record_id, :meetingId, :token)
  end

  def deliver_resource(permit)
    if permit
      resource_path = request.fullpath
      static_resource_path = "/static-resource#{resource_path}"
      response.headers['X-Accel-Redirect'] = static_resource_path
      head(:ok)
    else
      response.headers['X-Accel-Redirect'] = '/static-resource'
      head(404)
    end
  end
end
