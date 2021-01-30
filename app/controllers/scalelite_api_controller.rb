# frozen_string_literal: true

class ScaleliteApiController < ApplicationController
  include ApiHelper

  before_action :verify_checksum, except: :index

  def index
    # Return the scalelite build number if passed as an env variable
    build_number = Rails.configuration.x.build_number

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('2.0')
        xml.build(build_number) if build_number.present?
      end
    end
    render(xml: builder)
  end

  def get_servers
    begin
      servers = Server.all
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Internal server error'
    end

    builder = if servers.empty?
                Nokogiri::XML::Builder.new do |xml|
                  xml.response do
                    xml.returncode('SUCCESS')
                    xml.messageKey('noServers')
                    xml.message('No servers were found')
                  end
                end
              else
                Nokogiri::XML::Builder.new do |xml|
                  xml.response do
                    xml.returncode('SUCCESS')
                    xml.version('2.0')
                    xml.servers do
                      servers.each do |server|
                        xml.server do
                          xml.serverID(server.id)
                          xml.serverURL(server.url)
                          xml.online(server.online)
                          xml.loadMultiplier(server.load_multiplier)
                          xml.enabled(server.enabled)
                          xml.load(server.load)
                        end
                      end
                    end
                  end
                end
              end
    render(xml: builder)
  end

  def get_server_info
    params.require(:serverID)

    begin
      server = Server.find(params['serverID'])
    rescue ApplicationRedisRecord::RecordNotFound
      raise ServerNotFoundError
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('2.0')
        xml.server do
          xml.serverID(server.id)
          xml.serverURL(server.url)
          xml.online(server.online)
          xml.loadMultiplier(server.load_multiplier)
          xml.enabled(server.enabled)
          xml.load(server.load)
        end
      end
    end
    render(xml: builder)
  end

  def add_server
    params.require(:serverURL)
    params.require(:serverSecret)

    load_multiplier = normalize_load_multiplier(params['loadMultiplier'])

    begin
      server = Server.create!(url: params['serverURL'], secret: params['serverSecret'], load_multiplier: load_multiplier)
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error adding the server'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.server do
          xml.serverID(server.id)
          xml.serverURL(server.url)
          xml.loadMultiplier(server.load_multiplier)
        end
      end
    end
    render(xml: builder)
  end

  def remove_server
    params.require(:serverID)

    begin
      server = Server.find(params['serverID'])
      server.destroy!
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error removing the server'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
      end
    end

    render(xml: builder)
  end

  def enable_server
    params.require(:serverID)

    begin
      server = Server.find(params['serverID'])
      server.enabled = true
      server.save!
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error enabling the server'
    end

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
      end
    end

    render(xml: builder)
  end

  def disable_server
    params.require(:serverID)

    begin
      server = Server.find(params['serverID'])
      server.enabled = false
      server.save!
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Error disabling the server'
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

    load_multiplier = normalize_load_multiplier(params['loadMultiplier'])

    begin
      server = Server.find(params['serverID'])
      server.load_multiplier = load_multiplier
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

  private

  def normalize_load_multiplier(load_multiplier)
    tmp_load_multiplier = 1.0
    unless load_multiplier.nil?
      tmp_load_multiplier = load_multiplier.to_d
      tmp_load_multiplier = 1.0 if tmp_load_multiplier.zero?
    end
    tmp_load_multiplier
  end
end
