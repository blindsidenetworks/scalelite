# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  scope 'bigbluebutton/api', as: 'bigbluebutton_api', format: false, defaults: { format: 'xml' } do
    get '/', to: 'bigbluebutton_api#index'
    get 'isMeetingRunning', to: 'bigbluebutton_api#is_meeting_running', as: :is_meeting_running
    get 'getMeetingInfo', to: 'bigbluebutton_api#get_meeting_info', as: :get_meeting_info
    get 'getMeetings', to: 'bigbluebutton_api#get_meetings', as: :get_meetings
    match 'create', to: 'bigbluebutton_api#create', via: [:get, :post]
    get 'end', to: 'bigbluebutton_api#end'
    get 'join', to: 'bigbluebutton_api#join'

    match '*any', via: :all, to: 'errors#unsupported_request'
  end

  root to: 'errors#unsupported_request', via: :all
end
