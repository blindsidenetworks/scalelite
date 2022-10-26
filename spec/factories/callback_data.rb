# frozen_string_literal: true

FactoryBot.define do
  factory :callback_data do
    meeting_id { 'MyString' }
    recording_id { 1 }
    callback_attributes { 'MyText' }
  end
end
