# frozen_string_literal: true

class Recording < ApplicationRecord
  has_many :metadata, dependent: :destroy
  has_many :playback_formats, dependent: :destroy

  validates :record_id, presence: true
  validates :meeting_id, presence: true
  validates :state, inclusion: { in: %w[processing processed published unpublished deleted] }, allow_nil: true

  INTERNAL_METADATA = Set['isBreakout', 'meetingId', 'meetingName'].freeze

  def self.with_recording_id_prefixes(recording_ids)
    return none if recording_ids.empty?

    rid_prefixes = recording_ids.map { |rid| sanitize_sql_like(rid, '|') + '%' }
    query_string = Array.new(recording_ids.length, "record_id LIKE ? ESCAPE '|'").join(' OR ')

    where(query_string, *rid_prefixes)
  end

  # Create a new recording (and recursively playback format, meta, thumbnails) from a BigBlueButton metadata.xml
  def self.create_from_metadata_xml(metadata, overrides = {})
    metadata_xml = Nokogiri::XML(metadata)

    # Recording
    recording_params = {}
    recording_xml = metadata_xml.at_xpath('recording')
    meeting_xml = recording_xml.at_xpath('meeting')
    recording_params[:record_id] = meeting_xml['id']
    recording_params[:meeting_id] = meeting_xml['externalId']
    recording_params[:name] = meeting_xml['name']
    published = recording_xml.at_xpath('published')&.text
    recording_params[:published] = (published == 'true') if published.present?
    participants = recording_xml.at_xpath('participants')&.text
    recording_params[:participants] = participants.to_i if participants.present?
    state = recording_xml.at_xpath('state')&.text
    recording_params[:state] = state if state.present?
    # Workaround screenshare state bug
    recording_params[:state] = 'published' if recording_params[:state] == 'available'
    start_time = recording_xml.at_xpath('start_time')&.text
    recording_params[:starttime] = Time.at(Rational(start_time.to_i, 1000)).utc if start_time.present?
    end_time = recording_xml.at_xpath('end_time')&.text
    recording_params[:endtime] = Time.at(Rational(end_time.to_i, 1000)).utc if end_time.present?
    recording_params.merge!(overrides)

    # Metadata
    metadata_params = []
    meta_xml = recording_xml.at_xpath('meta')
    meta_xml.element_children.each do |meta_elem|
      next if INTERNAL_METADATA.member?(meta_elem.name)

      metadata_params << {
        key: meta_elem.name,
        value: meta_elem.text,
      }
    end

    # Playback format
    playback_format_params = {}
    playback_xml = recording_xml.at_xpath('playback')
    link_raw = playback_xml.at_xpath('link')&.text
    link = link_raw.strip
    playback_format_params[:format] = playback_xml.at_xpath('format')&.text
    duration = playback_xml.at_xpath('duration')&.text
    playback_format_params[:length] = (duration.to_f / 60_000).round if duration.present?
    playback_format_params[:url] = URI(link).request_uri if link.present?

    # Thumbnails
    images_xml = playback_xml.at_xpath('extensions/preview/images')
    thumbnails_params = []
    if images_xml.present?
      images_xml.element_children.each_with_index do |image_xml, i|
        thumbnails_params << {
          width: image_xml['width']&.to_i,
          height: image_xml['height']&.to_i,
          alt: image_xml['alt'],
          url: URI(image_xml.text.strip).path,
          sequence: i,
        }
      end
    end

    begin
      Recording.transaction do
        recording = Recording.find_or_initialize_by(record_id: recording_params[:record_id])
        recording.assign_attributes(recording_params)
        recording.save!
        logger.debug(recording.inspect)

        metadata_params.each do |metadatum_params|
          metadatum = recording.metadata.find_or_initialize_by(key: metadatum_params[:key])
          metadatum.assign_attributes(metadatum_params)
          metadatum.save!
          logger.debug(metadatum.inspect)
        end

        playback_format = recording.playback_formats.find_or_initialize_by(format: playback_format_params[:format])
        playback_format.assign_attributes(playback_format_params)
        playback_format.save!
        logger.debug(playback_format.inspect)

        playback_format.thumbnails = thumbnails_params.map do |thumbnail_params|
          thumbnail = playback_format.thumbnails.find_or_initialize_by(sequence: thumbnail_params[:sequence])
          thumbnail.assign_attributes(thumbnail_params)
          thumbnail.save!
          thumbnail
        end

        [recording, playback_format]
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
