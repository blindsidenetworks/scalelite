# frozen_string_literal: true

FactoryBot.define do
  factory :meeting do
    sequence(:id) { |n| "test-meeting-#{n}" }
    server
  end
end
