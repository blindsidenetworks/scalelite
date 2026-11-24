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
        recording_unpublish_dir: publish_dir,
        recording_dir_per_tenant: false
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

    it 'leaves a format out whose files could not be moved into place' do
      allow(FileUtils).to receive(:mv).and_call_original
      allow(FileUtils).to receive(:mv).with(a_string_starting_with('video/'), anything).and_raise(Errno::ENOSPC)

      expect { described_class.import(build_tar) }.not_to raise_error

      expect(Recording.find_by(record_id: record_id).playback_formats.pluck(:format)).to contain_exactly('presentation')
      expect(File.exist?(File.join(publish_dir, 'video', record_id))).to be false
    end

    it 'puts the recording of a tenant where every recording goes while RECORDING_DIR_PER_TENANT is off', :redis do
      tenant = create(:tenant, name: 'tenant1', recording_dir: Dir.mktmpdir)

      described_class.import(build_tar(tenant_id: tenant.id))

      expect(Dir.children(publish_dir)).to contain_exactly('presentation', 'video')
      expect(File.symlink?(File.join(publish_dir, 'presentation', record_id))).to be false
      expect(File.file?(File.join(publish_dir, 'presentation', record_id, 'metadata.xml'))).to be true
      expect(Dir.children(tenant.recording_dir)).to be_empty
    ensure
      FileUtils.rm_rf(tenant.recording_dir)
    end

    context 'with RECORDING_DIR_PER_TENANT', :redis do
      let(:own_dir) { Dir.mktmpdir }
      let(:tenant) { create(:tenant, name: 'tenant1', recording_dir: own_dir) }

      before do
        allow(Rails.configuration.x).to receive(:recording_dir_per_tenant).and_return(true)
      end

      after do
        FileUtils.rm_rf(own_dir)
      end

      it 'puts the recording of a tenant into the directory it was given, linked from where every recording goes' do
        described_class.import(build_tar(tenant_id: tenant.id))

        %w[presentation video].each do |format|
          files = File.join(own_dir, 'published', format, record_id)
          expect(File.file?(File.join(files, 'metadata.xml'))).to be true
          expect(File.readlink(File.join(publish_dir, format, record_id))).to eq files
        end
        # What the web server is asked for has not changed
        expect(File.file?(File.join(publish_dir, 'presentation', record_id, 'metadata.xml'))).to be true
      end

      it 'leaves the recording of a tenant that was not given a directory where every recording goes' do
        other = create(:tenant, name: 'tenant2')

        described_class.import(build_tar(tenant_id: other.id))

        expect(Dir.children(publish_dir)).to contain_exactly('presentation', 'video')
        expect(File.symlink?(File.join(publish_dir, 'presentation', record_id))).to be false
        expect(Dir.children(own_dir)).to be_empty
      end

      it 'leaves a recording without a tenant where every recording goes' do
        described_class.import(build_tar)

        expect(Dir.children(publish_dir)).to contain_exactly('presentation', 'video')
        expect(File.symlink?(File.join(publish_dir, 'presentation', record_id))).to be false
      end

      it 'keeps the tar and the database as they were while the directory of the tenant is not there' do
        tenant.recording_dir = File.join(publish_dir, 'not-mounted')
        tenant.save!
        tar = build_tar(tenant_id: tenant.id)

        expect { described_class.import(tar) }.to raise_error(RecordingDirectoryService::Unavailable)

        expect(File.file?(tar)).to be true
        expect(Recording.find_by(record_id: record_id)).to be_nil
        expect(Dir.children(publish_dir)).to be_empty
        expect(PostImporterScripts).not_to have_received(:run)
      end
    end

    private

    # tenant_id is what Scalelite puts on every meeting a tenant creates, and what a recording belongs to it by
    def metadata_xml(format:, tenant_id: nil)
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <recording>
          <id>#{record_id}</id>
          <state>published</state>
          <published>true</published>
          <meta>
            <meetingId>meeting-1</meetingId>
            <meetingName>Test Meeting</meetingName>#{"\n    <tenant-id>#{tenant_id}</tenant-id>" if tenant_id}
          </meta>
          <playback>
            <format>#{format}</format>
            <link>https://example.com/playback/#{format}/2.3/#{record_id}</link>
          </playback>
        </recording>
      XML
    end

    # Builds a tar containing two valid formats: "presentation" and "video".
    def build_tar(tenant_id: nil)
      src = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(src, 'presentation', record_id))
      File.write(File.join(src, 'presentation', record_id, 'metadata.xml'), metadata_xml(format: 'presentation', tenant_id: tenant_id))

      FileUtils.mkdir_p(File.join(src, 'video', record_id))
      File.write(File.join(src, 'video', record_id, 'metadata.xml'), metadata_xml(format: 'video', tenant_id: tenant_id))

      tar_path = File.join(Dir.mktmpdir, "#{record_id}.tar")
      Dir.chdir(src) { system('tar', '--create', '--file', tar_path, 'presentation', 'video') }
      tar_path
    end
  end
end
