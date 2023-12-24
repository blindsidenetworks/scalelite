# frozen_string_literal: true

class ServerUpdateService
  def initialize(server, params)
    @server = server
    @params = params
  end

  def call
    update_state if @params[:state].present?

    update_load_multiplier if @params[:load_multiplier].present?

    update_secret if @params[:secret].present?

    @server.save!
  end

  private

  def update_state
    case @params[:state]
    when 'enable'
      @server.state = 'enabled'
    when 'cordon'
      @server.state = 'cordoned'
    when 'disable'
      @server.state = 'disabled'
    else
      raise ArgumentError, "Invalid state parameter: #{@params[:state]}"
    end
  end

  def update_load_multiplier
    tmp_load_multiplier = @params[:load_multiplier].to_d
    if tmp_load_multiplier.zero?
      raise ArgumentError, "Load-multiplier must be a non-zero number"
    else
      @server.load_multiplier = tmp_load_multiplier
    end
  end

  def update_secret
    @server.secret = @params[:secret]
  end
end
