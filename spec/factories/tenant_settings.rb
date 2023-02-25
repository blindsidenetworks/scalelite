# frozen_string_literal: true

FactoryBot.define do
  factory :tenant_settings do
    name { Faker::Creature::Animal.unique.name  }
    value { Faker::Quote.yoda}
  end
end
