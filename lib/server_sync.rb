# frozen_string_literal: true

# Tools to synchronize cluster state with a list of servers. Used by the
# servers:sync an servers:yaml tasks.
class ServerSync
  SERVER_PARAMS = %w[url secret enabled load_multiplier].freeze
  PARAMS_IGNORE = %w[load state online].freeze
  SYNC_MODES = %w[keep cordon force].freeze

  class SyncError < StandardError
  end

  def self.logger
    Rails.logger
  end

  # Reads a YAML document containing a +servers+ hash from a file or stdin
  # (path='-') and synchronizes cluster state. The YAML document file must
  # contain a +servers+ hash mapping IDs to server parameters. For details,
  # see +ServerSync.sync+
  def self.sync_file(path, mode = 'cordon', dryrun = false)
    yaml = YAML.safe_load(path == '-' ? $stdin.read : File.read(path))
    raise(SyncError, 'Invalid YAML document') unless yaml.is_a?(Hash)

    servers = yaml['servers']
    sync(servers, mode, dryrun)
  end

  # Synchronizes cluster state with a server list. The servers parameter should
  # be a hash mapping server IDs to parameters. The +secret+ parameter is
  # required, the API +url+ is auto-derived from the server id if it looks like
  # a hostname, +enabled+ is true by defalt and +load_multiplier+ is +1.0+ by
  # default.
  # The +mode+ decides what happens to undesired servers. Valid values are
  # +keep+, +cordon+ (default) and +force+. The last option will end all
  # meetings before the server is removed.
  # A +dryrun+ logs the same output as a normal run, but does not persist
  # any changes.
  def self.sync(servers, mode = 'cordon', dryrun = false)
    include ApiHelper

    raise(SyncError, 'Servers parameter not a hash') unless servers.is_a?(Hash)
    raise(SyncError, "Unknown sync mode '#{mode}' (choose: #{SYNC_MODES.join(' ')})") \
      unless SYNC_MODES.include?(mode)

    mode = mode.presence || 'cordon'
    dryrun &&= !%w[n no false].include?(dryrun.to_s.downcase)

    # Validate server list and add missing parameters
    servers.each do |id, params|
      params['url'] = "https://#{id}/bigbluebutton/api" if params['url'].nil?
      params['enabled'] = params['enabled'].nil? || !!params['enabled']
      params['load_multiplier'] = 1.0 if params['load_multiplier'].nil?
      bad_params = params.keys - SERVER_PARAMS - PARAMS_IGNORE

      raise(SyncError, "Server id=#{id} contains invalid characters") unless /^[a-zA-Z0-9_.-]+$/.match?(id)
      raise(SyncError, "Server id=#{id} has no secret") if params['secret'].blank?
      raise(SyncError, "Server id=#{id} has bad parameters: #{bad_params}") unless bad_params.empty?
      raise(SyncError, "Server id=#{id} has invalid load_multiplier=#{params['load_multiplier']}") \
        if params['load_multiplier'].to_d <= 0

      begin
        uri = URI.parse(params['url'])
        raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && !uri.host.nil?
      rescue URI::InvalidURIError
        raise(SyncError, "Server id=#{id} has invalid url=#{params['url']}")
      end
    end

    # Create or update servers according to server list
    servers.each do |id, params|
      begin
        server = Server.find(id)
      rescue ApplicationRedisRecord::RecordNotFound
        unless dryrun
          server = Server.create!(
            id: id,
            url: params['url'],
            secret: params['secret'],
            load_multiplier: params['load_multiplier']
          )
        end
        logger.info("[#{id}] Server created")
        next if dryrun
      end

      unless server.url == params['url']
        server.url = params['url']
        logger.info("[#{id}] Server updated: url=#{params['url']}")
      end
      unless server.secret == params['secret']
        server.secret = params['secret']
        logger.info("[#{id}] Server updated: secret=*****")
      end
      unless server.load_multiplier.to_d == params['load_multiplier']
        server.load_multiplier = params['load_multiplier']
        logger.info("[#{id}] Server updated: load_multiplier=#{params['load_multiplier']}")
      end

      if params['enabled'] && !server.enabled?
        server.state = 'enabled'
        logger.info("[#{id}] Server enabled")
      elsif !params['enabled'] && server.enabled?
        server.state = 'cordoned'
        logger.info("[#{id}] Server disabled (cordoned)")
      end

      server.save! if server.changed? && !dryrun
    end

    # Remove servers not present in server list
    Server.all.each do |server|
      next if servers.key?(server.id)

      id = server.id

      if mode == 'keep'
        logger.info("[#{id}] Server not removed")
        next
      end

      meetings = Meeting.all.select { |m| m.server_id == id }

      if meetings.empty?
        server.destroy! unless dryrun
        logger.info("[#{id}] Server removed")
        next
      end

      if server.enabled?
        server.state = 'cordoned'
        server.save! unless dryrun
        logger.info("[#{id}] Server not empty. Cordoned for removal")
      end

      next if mode == 'cordon'

      logger.info("[#{id}] Server not empty. Ending meetings now...")

      meetings.each do |meeting|
        logger.info("[#{id}] Try to end meeting id=#{meeting.id}")
        unless dryrun
          begin
            get_post_req(
              encode_bbb_uri(
                'end',
                server.url,
                server.secret,
                meetingID: meeting.id,
                password: meeting.try(:moderator_pw)
              )
            )
          rescue StandardError => e
            # Not fatal (may have ended already)
            logger.warn("[#{id}] Failed to end meeting id=#{meeting.id}: #{e}")
          end
        end
        meeting.destroy! unless dryrun
      end

      # Check that no new meetings were created while we were busy
      raise(SyncError, "[#{id}] Server still not empty!") if Meeting.all.any? { |m| m.server_id == id }

      logger.info("[#{id}] Server removed")
      server.destroy! unless dryrun
    end
  end

  # Returns the current server list as an ID=>params hash. In verbose mode,
  # the hash contains additional fields (e.g. state, load, online).
  def self.dump(verbose)
    Server.all.to_h do |server|
      info = {
        url: server.url,
        secret: server.secret,
        load_multiplier: server.load_multiplier.to_d || 1.0,
        enabled: server.enabled,
      }
      if verbose
        info[:state] = server.state.presence || server.enabled ? 'enabled' : 'disabled'
        info[:load] = server.load.presence || -1.0
        info[:online] = server.online
      end
      [server.id, info]
    end
  end
end
