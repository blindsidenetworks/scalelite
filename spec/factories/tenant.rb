# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    name { Faker::Creature::Animal.name }
    secret { Faker::Crypto.sha512 }
  end
end
