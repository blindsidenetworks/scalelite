# frozen_string_literal: true

FactoryBot.define do
  factory :tenant_settings do
    name { TenantSettings::ALLOWED_SETTINGS.to_a.sample[0]  }
    value { 1..10 }
  end
end
