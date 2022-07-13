# frozen_string_literal: true

class Metadatum < ApplicationRecord
  belongs_to :recording

  def self.upsert_by_record_id(record_ids, metadata)
    record_ids = Array.try_convert(record_ids) || [record_ids]
    return if record_ids.empty? || metadata.empty?

    Recording.transaction do
      Recording.where(record_id: record_ids).ids.each do |recording_id|
        upsert_records = metadata.map { |key, value| { recording_id: recording_id, key: key, value: value } }
        # Safe in this case because there *are* no model validations.
        # rubocop:disable Rails/SkipsModelValidations
        Metadatum.upsert_all(upsert_records, returning: false, unique_by: [:recording_id, :key])
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end

  def self.delete_by_record_id(record_ids, metadata_keys)
    return if record_ids.empty? || metadata_keys.empty?

    Recording.transaction do
      Metadatum.where(recording_id: Recording.where(record_id: record_ids).ids, key: metadata_keys).delete_all
    end
  end
end
