# frozen_string_literal: true

class ServersController < ApplicationController
  def index
    # Return the scalelite build number if passed as an env variable
    build_number = Rails.configuration.x.build_number

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('2.0')
      end
    end

    render(xml: builder)
  end

  def all
    begin
      servers = get_servers
      
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.response do
          xml.returncode('SUCCESS')
          xml.version('2.0')
          xml.servers do
            servers.each do |server|
              xml.serverID(server.id)
              xml.serverUrl(server.url)
              xml.online(server.online)
              xml.loadMultiplier(server.load_multiplier)
              xml.enabled(server.enabled)
              xml.load(server.load)
            end
          end
        end
      end
  
    rescue StandardError => e
      return render(plain: "Servers get failure: #{e}")
    end

    render(xml: builder)
    # render(plain: servers)
  end

  private

  def get_servers
    servers = Server.all
    return servers
  end
end
