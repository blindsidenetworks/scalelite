# frozen_string_literal: true

FactoryBot.define do
  factory :tenant_settings do
    name { Faker::Creature::Animal.name }
    value { Faker::Creature::Animal.name }
  end
end
