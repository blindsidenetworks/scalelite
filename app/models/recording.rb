# frozen_string_literal: true

class Recording < ApplicationRecord
  has_many :metadata, dependent: :destroy
  has_many :playback_formats, dependent: :destroy

  validates :state, inclusion: { in: %w[processing processed published unpublished deleted] }, allow_nil: true

  def self.with_recording_id_prefixes(recording_ids)
    return none if recording_ids.empty?

    rid_prefixes = recording_ids.map { |rid| sanitize_sql_like(rid, '|') + '%' }
    query_string = Array.new(recording_ids.length, "record_id LIKE ? ESCAPE '|'").join(' OR ')

    where(query_string, *rid_prefixes)
  end
end
