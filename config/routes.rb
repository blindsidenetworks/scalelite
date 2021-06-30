# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  scope 'bigbluebutton/api', as: 'bigbluebutton_api', format: false, defaults: { format: 'xml' } do
    get '/', to: 'bigbluebutton_api#index'
    get 'isMeetingRunning', to: 'bigbluebutton_api#is_meeting_running', as: :is_meeting_running
    get 'getMeetingInfo', to: 'bigbluebutton_api#get_meeting_info', as: :get_meeting_info
    if 'true'.casecmp?(ENV['GET_MEETINGS_API_DISABLED'])
      get('getMeetings', to: 'bigbluebutton_api#get_meetings_disabled', as: :get_meetings)
    else
      get('getMeetings', to: 'bigbluebutton_api#get_meetings', as: :get_meetings)
    end
    match 'create', to: 'bigbluebutton_api#create', via: [:get, :post]
    get 'end', to: 'bigbluebutton_api#end'
    get 'join', to: 'bigbluebutton_api#join'
    post 'analytics_callback', to: 'bigbluebutton_api#analytics_callback', as: :analytics_callback
    if Rails.configuration.x.recording_disabled
      get('getRecordings', to: 'bigbluebutton_api#get_recordings_disabled', as: :get_recordings)
      get('publishRecordings', to: 'bigbluebutton_api#recordings_disabled', as: :publish_recordings)
      get('updateRecordings', to: 'bigbluebutton_api#recordings_disabled', as: :update_recordings)
      get('deleteRecordings', to: 'bigbluebutton_api#recordings_disabled', as: :delete_recordings)
    else
      get('getRecordings', to: 'bigbluebutton_api#get_recordings', as: :get_recordings)
      get('publishRecordings', to: 'bigbluebutton_api#publish_recordings', as: :publish_recordings)
      get('updateRecordings', to: 'bigbluebutton_api#update_recordings', as: :update_recordings)
      get('deleteRecordings', to: 'bigbluebutton_api#delete_recordings', as: :delete_recordings)
    end
  end

  get 'health_check', to: 'health_check#all'

  match '*any', via: :all, to: 'errors#unsupported_request'
  root to: 'errors#unsupported_request', via: :all
end
