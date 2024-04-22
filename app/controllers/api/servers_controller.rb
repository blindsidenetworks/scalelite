# frozen_string_literal: true

module Api
  class ServersController < ApplicationController
    include ApiHelper

    skip_before_action :verify_authenticity_token

    before_action -> { verify_checksum(true) }
    before_action :set_server, only: [:get_server_info, :update_server, :delete_server, :panic_server]

    # Return a list of the configured BigBlueButton servers
    # GET /scalelite/api/servers
    #
    # Successful response:
    # [
    #   {
    #     "id": String,
    #     "url": String,
    #     "secret": String,
    #     "tag": String,
    #     "bbb_version": String,
    #     "state": String,
    #     "load": String,
    #     "load_multiplier": String,
    #     "online": String
    #   },
    #   ...
    # ]
    def get_servers
      servers = Server.all

      if servers.empty?
        render json: { error: 'No servers are configured' }, status: :not_found
      else
        server_list = servers.map { |server| server_to_json(server) }
        render json: server_list, status: :ok
      end
    end

    # Retrieve a single BigBlueButton server
    # GET /scalelite/api/getServerInfo?id=
    #
    # Expected params:
    # {
    #  "id" : String   # Required
    # }
    #
    # Successful response:
    #   {
    #     "id": String,
    #     "url": String,
    #     "secret": String,
    #     "tag": String,
    #     "bbb_version": String,
    #     "state": String,
    #     "load": String,
    #     "load_multiplier": String,
    #     "online": String
    #   }
    def get_server_info
      begin
        render json: server_to_json(@server), status: :ok
      rescue StandardError => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # Add a new BigBlueButton server (it will be added disabled)
    # POST /scalelite/api/addServer
    #
    # Expected params:
    # {
    #   "server": {
    #     "url": String,                 # Required: URL of the BigBlueButton server
    #     "secret": String,              # Required: Secret key of the BigBlueButton server
    #     "load_multiplier": Float       # Optional: A non-zero number, defaults to 1.0 if not provided or zero
    #     "tag": String                  # Optional: A special-purpose tag for the server (empty String to not set it)
    #   }
    # }
    def add_server
      if server_create_params[:url].blank? || server_create_params[:secret].blank?
        render json: { error: 'Server needs a URL and a secret' }, status: :bad_request
      else
        tmp_load_multiplier = server_create_params[:load_multiplier].presence&.to_d || 1.0
        tmp_load_multiplier = 1.0 if tmp_load_multiplier.zero?

        server = Server.create!(url: server_create_params[:url], secret: server_create_params[:secret],
                                load_multiplier: tmp_load_multiplier, tag: server_create_params[:tag].presence)
        render json: server_to_json(server), status: :created
      end
    end

    # Update a BigBlueButton server
    # POST /scalelite/api/updateServer
    #
    # Expected params:
    # {
    #   "id": String               # Required: the server ID
    #   "server": {
    #     "state": String,         # Optional: 'enable', 'cordon', or 'disable'
    #     "load_multiplier": Float # Optional: A non-zero number
    #     "secret": String         # Optional: Secret key of the BigBlueButton server
    #     "tag": String            # Optional: A special-purpose tag for the server, empty string to remove the tag
    #   }
    # }
    def update_server
      begin
        updated_server = ServerUpdateService.new(@server, server_update_params).call
        render json: server_to_json(updated_server), status: :ok
      rescue StandardError => e
        render json: { error: e.message }, status: :bad_request
      end
    end

    # Remove a BigBlueButton server
    #
    # POST /scalelite/api/deleteServer
    #
    # Required Params:
    # {
    #  "id" : String   # Required
    # }
    def delete_server
      begin
        @server.destroy!
        render json: { success: "Server id=#{@server.id} was destroyed" }, status: :ok
      rescue StandardError => e
        render json: { error: "Couldn't destroy server id=#{@server.id}: #{e.message}" }, status: :bad_request
      end
    end

    # Set a BigBlueButton server as unavailable and clear all meetings from it
    # POST /scalelite/api/panicServer
    #
    # Expected params:
    # {
    #   "id": String            # Required
    #   "server": {
    #     "keep_state": Boolean # Optional: Set to 'true' if you want to keep the server's state after panicking, defaults to 'false'
    #   }
    # }
    def panic_server
      begin
        keep_state = (server_panic_params[:keep_state].presence || false)
        meetings = Meeting.all.select { |m| m.server_id == @server.id }
        meetings.each do |meeting|
          moderator_pw = meeting.try(:moderator_pw)
          meeting.destroy!
          get_post_req(encode_bbb_uri('end', @server.url, @server.secret, meetingID: meeting.id, password: moderator_pw))
        end

        @server.state = 'disabled' unless keep_state
        @server.save!
        render json: { success: "Server id=#{@server.id} has been disabled and the meetings have been destroyed" }, status: :ok
      rescue StandardError
        render json: { error: "Couldn't disable server id=#{@server.id}" }, status: :bad_request
      end
    end

    private

    def set_server
      begin
        @server = Server.find(params[:id])
      rescue ApplicationRedisRecord::RecordNotFound
        render json: { error: "Couldn't find server with id=#{params[:id]}" }, status: :not_found
      end
    end

    def server_to_json(server)
      {
        id: server.id,
        url: server.url,
        secret: server.secret,
        tag: server.tag.nil? ? '' : server.tag,
        bbb_version: server.bbb_version.nil? ? '' : server.bbb_version,
        state: server.state.presence || (server.enabled ? 'enabled' : 'disabled'),
        load: server.load.presence || 'unavailable',
        load_multiplier: server.load_multiplier.nil? ? 1.0 : server.load_multiplier.to_d,
        online: server.online ? 'online' : 'offline'
      }
    end

    def server_create_params
      params.require(:server).permit(:url, :secret, :load_multiplier, :tag)
    end

    def server_update_params
      params.require(:server).permit(:state, :load_multiplier, :secret, :tag)
    end

    def server_panic_params
      params.permit(:keep_state)
    end
  end
end
