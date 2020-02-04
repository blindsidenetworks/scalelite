# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  scope format: false, defaults: { format: 'xml' } do
    scope 'bigbluebutton/api', as: 'bigbluebutton_api' do
      get '/', to: 'bigbluebutton_api#index'
      get 'getMeetingInfo', to: 'bigbluebutton_api#get_meeting_info'
      get 'isMeetingRunning', to: 'bigbluebutton_api#is_meeting_running', as: :is_meeting_running
    end

    match '*any', via: :all, to: 'errors#unsupported_request'
  end

  root to: 'errors#unsupported_request', via: :all
end
