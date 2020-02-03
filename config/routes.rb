# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  scope format: false, defaults: { format: 'xml' } do
    scope 'bigbluebutton/api', as: 'bigbluebutton_api' do
      get '/', to: 'bigbluebutton_api#index'
    end
  end
end
