# frozen_string_literal: true

FactoryBot.define do
  factory :meeting do
    sequence(:id) { |n| "test-meeting-#{n}" }
    association :server
    moderator_pw { 'pw' }

    # Tenant is optional by default
    # If you want the meeting to have a tenant, you need to instantiate it and pass it in the create call
    transient do
      tenant { nil }
    end

    initialize_with do
      Meeting.find_or_create_with_server(id, server, moderator_pw, nil, tenant&.id)
    end
  end
end
