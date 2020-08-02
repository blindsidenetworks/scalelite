# frozen_string_literal: true

class ServersController < ApplicationController
  def index
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('development')
      end
    end
    render(xml: builder)
  end

  def all
    begin
      servers = Server.all
      
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.response do
          xml.returncode('SUCCESS')
          xml.version('2.0')
          xml.servers do
            servers.each do |server|
              xml.server do
                xml.serverID(server.id)
                xml.serverUrl(server.url)
                xml.serverSecret(server.secret) # TODO: this probably shouldn't be available unless the route is protected
                xml.online(server.online)
                xml.loadMultiplier(server.load_multiplier)
                xml.enabled(server.enabled)
                xml.load(server.load)
              end
            end
          end
        end
      end
  
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Could not find any available servers.'
    end

    render(xml: builder)
    # render(plain: servers) # TODO: remove debuggin
  end

  def add
    params.require(:serverUrl)
    params.require(:serverSecret)
    
    tmp_load_multiplier = 1.0
    unless params['loadMultiplier'].nil?
      tmp_load_multiplier = params['loadMultiplier'].to_d
      if tmp_load_multiplier.zero?
        puts('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end

    begin
      server = Server.create!(url: params['serverUrl'], secret: params['serverSecret'], load_multiplier: tmp_load_multiplier)
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error adding the server.'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.server do
          xml.serverID(server.id)
          xml.serverUrl(server.url)
          xml.serverSecret(server.secret) # TODO: this probably shouldn't be available unless the route is protected
          xml.online(server.online)
          xml.loadMultiplier(server.load_multiplier)
          xml.enabled(server.enabled)
          xml.load(server.load)       
        end
      end
    end
    render(xml: builder)
  end

  def remove
    params.require(:serverID)
    
    begin
      server = Server.find(params['serverID'])
      server.destroy!
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error removing the server.'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
      end
    end

    render(xml: builder)
  end

  def enable
    params.require(:serverID)
    
    begin
      server = Server.find(params['serverID'])
      server.enabled = true
      server.save!    
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error enabling the server.'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
      end
    end

    render(xml: builder)
  end


  def disable
    params.require(:serverID)
    
    begin
      server = Server.find(params['serverID'])
      server.enabled = false
      server.save!    
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error disabling the server.'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
      end
    end

    render(xml: builder)
  end

  def set_load_multiplier
    params.require(:serverID)
    params.require(:loadMultiplier)
    
    tmp_load_multiplier = 1.0
    unless params['loadMultiplier'].nil?
      tmp_load_multiplier = params['loadMultiplier'].to_d
      if tmp_load_multiplier.zero?
        puts('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end

    begin
      server = Server.find(params['serverID'])
      server.load_multiplier = tmp_load_multiplier
      server.save!  
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error changing load multiplier for the server.'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
      end
    end

    render(xml: builder)
  end
end
