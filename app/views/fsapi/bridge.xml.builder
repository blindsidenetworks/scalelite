# frozen_string_literal: true

xml.document(type: 'freeswitch/xml') do
  xml.section(name: 'dialplan', description: 'Bridge Call to BBB Server') do
    xml.context(name: 'public') do
      xml.extension(name: 'bridge_to_bbb_server') do
        xml.condition(field: 'destination_number', expression: "^#{fs_escape(Regexp.escape(@caller_dest_num))}$") do
          xml.action(application: 'set', data: "meeting_id=#{fs_escape(@meeting.id)}")
          xml.action(application: 'set', data: "effective_caller_id_name=#{fs_escape(@caller_id)}")
          xml.action(application: 'bridge', data: "sofia/external/#{fs_escape(@pin)}@#{URI(@server.url).host}")
        end
      end
    end
  end
end
