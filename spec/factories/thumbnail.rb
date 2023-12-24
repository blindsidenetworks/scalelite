# frozen_string_literal: true

FactoryBot.define do
  sequence :thumb_seq do |n|
    n
  end

  factory :thumbnail do
    width { 320 }
    height { 240 }
    add_attribute(:sequence) { thumb_seq }
    alt { "Thumbnail ##{sequence}" }
  end
end
