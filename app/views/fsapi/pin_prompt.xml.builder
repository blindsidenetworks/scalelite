# frozen_string_literal: true

xml.document(type: 'freeswitch/xml') do
  xml.section(name: 'dialplan', description: 'Match DID and Pin for Conference') do
    xml.context(name: 'public') do
      xml.extension(name: 'match_did_and_prompt_for_pin') do
        xml.condition(field: 'destination_number', expression: "^#{@caller_dest_num}$") do
          xml.action(application: 'answer')
          xml.action(application: 'sched_hangup', data: "+#{@allotted_timeout} normal_clearing") if @allotted_timeout.positive?
          xml.action(application: 'sleep', data: '500')
          xml.action(application: 'playback', data: 'ivr/ivr-welcome.wav')
          xml.action(application: 'sleep', data: '200')
          xml.action(
            application: 'play_and_get_digits',
            data: "#{Rails.configuration.x.voice_bridge_min} #{Rails.configuration.x.voice_bridge_max} " \
                  "3 7000 # conference/conf-enter_conf_pin.wav conference/conf-bad-pin.wav pin \d+"
          )
          xml.action(application: 'transfer', data: '${pin} XML public')
        end
      end
    end
  end
end
