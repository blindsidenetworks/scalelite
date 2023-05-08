# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    id { SecureRandom.uuid }
    name { Faker::Creature::Animal.name }
    secrets { "#{Faker::Crypto.sha256}:#{Faker::Crypto.sha512}" }
  end
end
