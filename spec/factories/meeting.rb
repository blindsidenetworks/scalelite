# frozen_string_literal: true

FactoryBot.define do
  factory :meeting do
    initialize_with { Meeting.find_or_create_with_server(id, server, moderator_pw) }

    sequence(:id) { |n| "test-meeting-#{n}" }
    association :server
    moderator_pw { 'pw' }
  end
end
