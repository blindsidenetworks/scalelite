# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    name { Faker::Creature::Animal.name }
    secrets { "#{Faker::Crypto.sha256}:#{Faker::Crypto.sha512}" }
    lrs_endpoint { nil }
    lrs_basic_token { nil }
    kc_token_url { nil }
    kc_client_id { nil }
    kc_client_secret { nil }
    kc_username { nil }
    kc_password { nil }
  end
end
