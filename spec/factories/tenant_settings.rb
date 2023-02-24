# frozen_string_literal: true

FactoryBot.define do
  factory :tenant_settings do
    name { 'setting_name'  }
    value { Faker::Internet.device_token }
  end
end
