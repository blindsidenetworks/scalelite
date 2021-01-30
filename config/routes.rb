# frozen_string_literal: true

Rails.application.routes.draw do
  scope 'scalelite/api', as: 'scalelite_api', format: false, defaults: { format: 'xml' } do
    get '/', to: 'scalelite_api#index'
    get 'getServers', to: 'scalelite_api#get_servers'
    get 'getServerInfo', to: 'scalelite_api#get_server_info'
    get 'addServer', to: 'scalelite_api#add_server'
    get 'removeServer', to: 'scalelite_api#remove_server'
    get 'enableServer', to: 'scalelite_api#enable_server'
    get 'disableServer', to: 'scalelite_api#disable_server'
    get 'setLoadMultiplier', to: 'scalelite_api#set_load_multiplier'
  end

  match '*any', via: :all, to: 'errors#unsupported_request'
  root to: 'errors#unsupported_request', via: :all
end
