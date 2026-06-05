# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecordingImporter do
  describe '.import' do
    let(:record_id) { "#{Digest::SHA256.hexdigest('meeting-1')}-1234567890123" }
    let(:work_dir)    { Dir.mktmpdir }
    let(:publish_dir) { Dir.mktmpdir }

    before do
      allow(Rails.configuration.x).to receive_messages(
        recording_work_dir: work_dir,
        recording_publish_dir: publish_dir,
        recording_unpublish_dir: publish_dir
      )
      allow(PostImporterScripts).to receive(:run)
    end

    after do
      FileUtils.rm_rf([work_dir, publish_dir])
    end

    it 'imports the other formats even when one format fails to import' do
      tar = build_tar

      # Simulate the "video" format failing to import, without crafting broken metadata.
      allow(Recording).to receive(:create_from_metadata_xml).and_call_original
      allow(Recording).to receive(:create_from_metadata_xml)
        .with(a_string_including('<format>video</format>'))
        .and_raise(StandardError, 'simulated format failure')

      expect { described_class.import(tar) }.not_to raise_error

      recording = Recording.find_by(record_id: record_id)
      expect(recording).to be_present
      expect(recording.playback_formats.pluck(:format)).to contain_exactly('presentation')
    end

    private

    def metadata_xml(format:)
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <recording>
          <id>#{record_id}</id>
          <state>published</state>
          <published>true</published>
          <meta>
            <meetingId>meeting-1</meetingId>
            <meetingName>Test Meeting</meetingName>
          </meta>
          <playback>
            <format>#{format}</format>
            <link>https://example.com/playback/#{format}/2.3/#{record_id}</link>
          </playback>
        </recording>
      XML
    end

    # Builds a tar containing two valid formats: "presentation" and "video".
    def build_tar
      src = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(src, 'presentation', record_id))
      File.write(File.join(src, 'presentation', record_id, 'metadata.xml'), metadata_xml(format: 'presentation'))

      FileUtils.mkdir_p(File.join(src, 'video', record_id))
      File.write(File.join(src, 'video', record_id, 'metadata.xml'), metadata_xml(format: 'video'))

      tar_path = File.join(Dir.mktmpdir, "#{record_id}.tar")
      Dir.chdir(src) { system('tar', '--create', '--file', tar_path, 'presentation', 'video') }
      tar_path
    end
  end
end
