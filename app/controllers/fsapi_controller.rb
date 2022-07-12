# frozen_string_literal: true

class FsapiController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate

  def index
    if params['section'] != 'dialplan'
      logger.warn('Request from freeswitch mod_xml_curl for non-dialplan section')
      return render 'reject'
    end
    if params['Caller-Destination-Number'].blank?
      logger.warn('Missing Caller-Destination-Number')
      return render 'reject'
    end

    @caller_dest_num = params['Caller-Destination-Number']
    @pin = params['variable_pin']
    @allotted_timeout = Rails.configuration.x.fsapi_max_duration * 60

    # The variable 'pin' is set once the caller has gone through the prompt
    # so if it's missing, send the meeting selection prompt.
    if @pin.blank?
      logger.info('Prompting for pin number')
      return render 'pin_prompt'
    end

    # Look up the meeting for this voice bridge number
    @meeting = begin
      Meeting.find_by_voice_bridge(@pin)
    rescue ApplicationRedisRecord::RecordNotFound
      begin
        # If no meeting was found, it might have been a breakout room pin, which adds one digit to the end
        Meeting.find_by_voice_bridge(@pin[0...-1]) if @pin.length > 5
      rescue ApplicationRedisRecord::RecordNotFound
        nil
      end
    end

    # Prompt for a new pin if there was none found
    if @meeting.nil?
      logger.info("Pin number #{@pin} does not match a running meeting, reprompting")
      return render 'pin_reprompt'
    end

    @server = @meeting.server

    # Do caller ID phone number masking
    cid_name = params['Caller-Caller-ID-Name']
    cid_hide_name = params['Caller-Privacy-Hide-Name']
    cid_hide_number = params['Caller-Privacy-Hide-Number']

    if cid_name.present? && /\A\d+\z/.match?(cid_name) # Caller-ID-Name actually a number
      if cid_hide_number.blank? || (cid_hide_number != 'true')
        masked_number = cid_name[0..-5]
        masked_number += 'X' * (cid_name.length - masked_number.length) if masked_number.length < cid_name.length
        @caller_id = masked_number
      end
    elsif cid_hide_name.blank? || (cid_hide_name != 'true')
      @caller_id = cid_name
    end
    @caller_id = 'Unavailable' if @caller_id.blank?

    logger.info("Bridging call into meeting #{@meeting.id} on server #{@server.id}")
    render 'bridge'
  end

  private

  def authenticate
    fsapi_password = Rails.configuration.x.fsapi_password
    return true if fsapi_password.blank?

    if authenticate_with_http_basic do |u, p|
      # Note that the secure_compare method reveals whether the length matches with a timing attack
      u == 'fsapi' && ActiveSupport::SecurityUtils.secure_compare(p, Rails.configuration.x.fsapi_password)
    end
    else
      request_http_basic_authentication(Rails.configuration.x.url_host)
    end
  end
end
