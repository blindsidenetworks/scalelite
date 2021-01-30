# frozen_string_literal: true

class ApplicationController < ActionController::Metal
  # These includes are based on ActionController::API but with the full rendering stack re-enabled
  include AbstractController::Rendering

  include ActionController::UrlFor
  include ActionController::Redirecting
  include ActionView::Layouts
  include ActionController::Rendering
  include ActionController::Renderers::All
  include ActionController::ConditionalGet
  include ActionController::ImplicitRender
  include ActionController::StrongParameters

  include ActionController::ForceSSL
  include ActionController::DataStreaming
  include ActionController::DefaultHeaders

  include AbstractController::Callbacks
  include ActionController::Rescue
  include ActionController::Instrumentation
  include ActionController::ParamsWrapper

  ActiveSupport.run_load_hooks(:action_controller_api, self)
  ActiveSupport.run_load_hooks(:action_controller, self)
  # Controller setup done, applications stuff is below

  include ApplicationErrors

  rescue_from ApplicationError do |e|
    render(xml: build_error(e.message_key, e.message))
  end

  rescue_from ActionController::ParameterMissing do |e|
    # Raise specific Missing Meeting ID error if thats the missing param
    error = if e.param == :serverID
              MissingServerIDError.new
            elsif e.param == :serverURL
              MissingServerURLError.new
            elsif e.param == :serverSecret
              MissingServerSecretError.new
            elsif e.param == :loadMultiplier
              MissingLoadMultiplierError.new
            else
              InternalError.new(e.message)
            end

    render(xml: build_error(error.message_key, error.message))
  end

  private

  # Generic XML builder for errors
  def build_error(key, message)
    Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('FAILED')
        xml.messageKey(key)
        xml.message(message)
      end
    end
  end
end
