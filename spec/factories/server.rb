# frozen_string_literal: true

FactoryBot.define do
  factory :server do
    sequence(:url) { |n| "https://test-#{n}.example.com/bigbluebutton/api" }
    sequence(:secret) { |n| "test-#{n}-secret" }
    load { 1 }
    online { true }
    enabled { true }
  end
end
