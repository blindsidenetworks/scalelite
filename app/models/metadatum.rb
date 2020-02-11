# frozen_string_literal: true

class Metadatum < ApplicationRecord
  belongs_to :recording

  def self.upsert_by_record_id(record_ids, metadata)
    # TODO: It might be possible to rewrite this in terms of the ActiveRecord upsert_all
    # method introduced in Rails 6

    record_ids = Array.try_convert(record_ids) || [record_ids]
    return if record_ids.empty? || metadata.empty?

    insert_records = []

    key_col = Metadatum.columns_hash['key']
    value_col = Metadatum.columns_hash['value']
    record_id_col = Recording.columns_hash['record_id']
    metadata.each do |key, value|
      insert_records << [key_col, key]
      insert_records << [value_col, value]
    end
    record_ids.each do |record_id|
      insert_records << [record_id_col, record_id]
    end

    Metadatum.connection.insert(
      'INSERT INTO "metadata" ("recording_id", "key", "value") '\
        'WITH "new_metadata" AS '\
            "(VALUES #{Array.new(metadata.length, '(?, ?)').join(', ')}) "\
          'SELECT "recordings"."id", "new_metadata".* FROM "recordings" JOIN "new_metadata" '\
          'WHERE "recordings"."record_id" '\
            "IN (#{Array.new(record_ids.length, '?').join(', ')}) "\
          'ON CONFLICT ("recording_id", "key") DO UPDATE SET "value" = EXCLUDED."value"',
      'Metadatum Upsert',
      nil,
      nil,
      nil,
      insert_records
    )
  end

  def self.delete_by_record_id(record_ids, metadata_keys)
    return if record_ids.empty? || metadata_keys.empty?

    Metadatum.joins(:recording).where(recordings: { record_id: record_ids }, key: metadata_keys).delete_all
  end
end
