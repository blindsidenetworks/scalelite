# frozen_string_literal: true

FactoryBot.define do
  sequence :starttime do |n|
    Time.utc(2002, 10, 31, 2, 2, 2) + n.days
  end

  sequence :name do |n|
    "Meeting #{n}"
  end

  sequence :meeting_id do |n|
    "meeting#{n}"
  end

  factory :recording do
    meeting_id
    name
    starttime
    endtime { starttime + 30.minutes }
    record_id { "#{Digest::SHA256.hexdigest(meeting_id)}-#{starttime.strftime('%s%L')}" }

    trait :published do
      published { true }
      state { 'published' }
    end

    trait :unpublished do
      published { false }
      state { 'published' }
    end

    factory :recording_with_metadata do
      transient do
        meta_count { 3 }
        meta_params { {} }
      end

      after(:create) do |recording, evaluator|
        create_list(:metadatum, evaluator.meta_count, recording: recording)
        evaluator.meta_params.each do |key, value|
          create(:metadatum, recording: recording, key: key, value: value)
        end
      end
    end
  end
end
