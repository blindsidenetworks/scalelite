# frozen_string_literal: true

class Init < ActiveRecord::Migration[6.0]
  def change
    create_table(:metadata, force: :cascade) do |t|
      t.bigint(:recording_id)
      t.string(:key)
      t.string(:value)
      t.index(%w[recording_id key], name: 'index_metadata_on_recording_id_and_key', unique: true)
    end

    create_table(:playback_formats, force: :cascade) do |t|
      t.bigint(:recording_id)
      t.string(:format)
      t.string(:url)
      t.integer(:length)
      t.integer(:processing_time)
      t.index(%w[recording_id format], name: 'index_playback_formats_on_recording_id_and_format', unique: true)
    end

    create_table(:recordings, force: :cascade) do |t|
      t.string(:record_id)
      t.string(:meeting_id)
      t.string(:name)
      t.boolean(:published)
      t.integer(:participants)
      t.string(:state)
      t.datetime(:starttime)
      t.datetime(:endtime)
      t.datetime(:deleted_at)
      t.index(%w[meeting_id], name: 'index_recordings_on_meeting_id')
      t.index(%w[record_id], name: 'index_recordings_on_record_id', unique: true)
    end

    create_table(:thumbnails, force: :cascade) do |t|
      t.bigint(:playback_format_id)
      t.integer(:width)
      t.integer(:height)
      t.string(:alt)
      t.string(:url)
      t.integer(:sequence)
      t.index(%w[playback_format_id], name: 'index_thumbnails_on_playback_format_id')
    end
  end
end
