# frozen_string_literal: true

FactoryBot.define do
  sequence :key do |n|
    "key#{n}"
  end

  sequence :value do |n|
    "Metadata Value ##{n}"
  end

  factory :metadatum do
    key
    value
  end
end
