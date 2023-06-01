# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  scope 'bigbluebutton/api', as: 'bigbluebutton_api', format: false, defaults: { format: 'xml' } do
    match '/', to: 'bigbluebutton_api#index', via: [:get, :post]
    match 'isMeetingRunning', to: 'bigbluebutton_api#is_meeting_running', as: :is_meeting_running, via: [:get, :post]
    match 'getMeetingInfo', to: 'bigbluebutton_api#get_meeting_info', as: :get_meeting_info, via: [:get, :post]
    if 'true'.casecmp?(ENV['GET_MEETINGS_API_DISABLED'])
      match('getMeetings', to: 'bigbluebutton_api#get_meetings_disabled', as: :get_meetings, via: [:get, :post])
    else
      match('getMeetings', to: 'bigbluebutton_api#get_meetings', as: :get_meetings, via: [:get, :post])
    end
    match 'create', to: 'bigbluebutton_api#create', via: [:get, :post]
    match 'end', to: 'bigbluebutton_api#end', via: [:get, :post]
    match 'join', to: 'bigbluebutton_api#join', via: [:get, :post]
    post 'analytics_callback', to: 'bigbluebutton_api#analytics_callback', as: :analytics_callback
    post 'insertDocument', to: 'bigbluebutton_api#insert_document'
    if Rails.configuration.x.recording_disabled
      match('getRecordings', to: 'bigbluebutton_api#get_recordings_disabled', as: :get_recordings, via: [:get, :post])
      match('publishRecordings', to: 'bigbluebutton_api#recordings_disabled', as: :publish_recordings, via: [:get, :post])
      match('updateRecordings', to: 'bigbluebutton_api#recordings_disabled', as: :update_recordings, via: [:get, :post])
      match('deleteRecordings', to: 'bigbluebutton_api#recordings_disabled', as: :delete_recordings, via: [:get, :post])
    else
      match('getRecordings', to: 'bigbluebutton_api#get_recordings', as: :get_recordings, via: [:get, :post])
      match('publishRecordings', to: 'bigbluebutton_api#publish_recordings', as: :publish_recordings, via: [:get, :post])
      match('updateRecordings', to: 'bigbluebutton_api#update_recordings', as: :update_recordings, via: [:get, :post])
      match('deleteRecordings', to: 'bigbluebutton_api#delete_recordings', as: :delete_recordings, via: [:get, :post])
    end
  end

  scope 'scalelite/api', module: 'api', as: 'scalelite_api' do
    get '/getTenants', to: 'tenants#get_tenants', as: :get_tenants
    get '/getTenantInfo', to: 'tenants#get_tenant_info', as: :get_tenant_info
    post '/addTenant', to: 'tenants#add_tenant', as: :add_tenant
    post '/updateTenant', to: 'tenants#update_tenant', as: :update_tenant
    post '/deleteTenant', to: 'tenants#delete_tenant', as: :delete_tenant

    get '/getServers', to: 'servers#get_servers', as: :get_servers
    get '/getServerInfo', to: 'servers#get_server_info', as: :get_server_info
    post '/addServer', to: 'servers#add_server', as: :add_server
    post '/updateServer', to: 'servers#update_server', as: :update_server
    post '/deleteServer', to: 'servers#delete_server', as: :delete_server
    post '/panicServer', to: 'servers#panic_server', as: :panic_server
  end

  get('health_check', to: 'health_check#index')

  unless Rails.configuration.x.recording_disabled
    get('recording/:record_id/:playback_format', to: 'playback#play', format: false, as: :playback_play)
    Rails.configuration.x.recording_playback_formats.each do |playback_format|
      get(
        "#{playback_format}/:record_id(/*resource)",
        to: 'playback#resource',
        format: false,
        defaults: { playback_format: playback_format }
      )
    end
  end

  post('fsapi', to: 'fsapi#index', format: false, defaults: { format: 'xml' })

  match '*any', via: :all, to: 'errors#unsupported_request'
  root to: 'health_check#index', via: :all
end
