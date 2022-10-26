# frozen_string_literal: true

FactoryBot.define do
  sequence :format do |n|
    "playbackformat#{n}"
  end

  factory :playback_format do
    format
    url { "/#{format}/index.html?#{recording.id}" }
    length { 30 } # minutes
    processing_time { length / 2 }

    factory :playback_format_with_thumbnails do
      transient do
        thumbnails_count { 3 }
      end

      after(:create) do |playback_format, evaluator|
        create_list(:thumbnail, evaluator.thumbnails_count, playback_format: playback_format)
      end
    end
  end
end
