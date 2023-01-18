# frozen_string_literal: true

xml.document(type: 'freeswitch/xml') do
  xml.section(name: 'dialplan', description: 'Reprompt Pin for Conference') do
    xml.context(name: 'public') do
      xml.extension(name: 'reprompt_for_pin') do
        xml.condition(field: 'destination_number', expression: "^#{@caller_dest_num}$") do
          xml.action(application: 'playback', data: 'conference/conf-bad-pin.wav')
          xml.action(application: 'sleep', data: '500')
          xml.action(
            application: 'play_and_get_digits',
            data: '5 9 3 7000 # conference/conf-enter_conf_pin.wav conference/conf-bad-pin.wav pin \d+'
          )
          xml.action(application: 'transfer', data: '${pin} XML public')
        end
      end
    end
  end
end
