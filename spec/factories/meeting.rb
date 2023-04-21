# frozen_string_literal: true

FactoryBot.define do
  factory :meeting do
    sequence(:id) { |n| "test-meeting-#{n}" }
    server
    moderator_pw { nil }
    voice_bridge { nil }
    tenant { nil }
  end
end
