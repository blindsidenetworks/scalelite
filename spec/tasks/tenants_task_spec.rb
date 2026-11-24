# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'tenants tasks', type: :task do
  before do
    stub_const('ENV', ENV.to_h.merge('MULTITENANCY_ENABLED' => 'true'))
    Rails.application.load_tasks
  end

  after do
    Rake::Task.clear
  end

  describe ':tenants' do
    let(:task) { Rake::Task['tenants'] }

    it 'lists all tenants' do
      tenant1 = create(:tenant)
      tenant2 = create(:tenant)

      # rubocop:disable Layout/LineLength
      expect { task.invoke }.to output(
        "id: #{tenant2.id}\n\tname: #{tenant2.name}\n\tsecrets: #{tenant2.secrets}\nid: #{tenant1.id}\n\tname: #{tenant1.name}\n\tsecrets: #{tenant1.secrets}\nTotal number of tenants: 2\n"
      ).to_stdout
      # rubocop:enable Layout/LineLength
    end

    it 'prints an API Mate link for each tenant when API_MATE_URL is set' do
      allow(Rails.configuration.x).to receive_messages(api_mate_url: 'https://api-mate.example.com/', url_host: 'scalelite.example.com')
      tenant = create(:tenant)

      expect { task.invoke }.to output(
        %r{\tapi_mate: https://api-mate\.example\.com/\?server=https://#{tenant.name}\.scalelite\.example\.com/bigbluebutton/api/&secret=#{tenant.secrets_array[0]}\n}
      ).to_stdout
    end

    it 'displays a message if there are no tenants' do
      expect { task.invoke }.to output(/Total number of tenants: 0\n/).to_stdout
    end

    it 'shows the directory a tenant was given for its recordings, and nothing for a tenant without one' do
      allow(Rails.configuration.x).to receive(:recording_dir_per_tenant).and_return(true)
      create(:tenant, name: 'tenant1')
      create(:tenant, name: 'tenant2', recording_dir: '/mnt/recordings/tenant2')

      expect { task.invoke }.to output(
        %r{\A(?:(?!recording dir).)*\tname: tenant2\n(?:\t.*\n)*\trecording dir: /mnt/recordings/tenant2\n(?:(?!recording dir).)*\z}m
      ).to_stdout
    end

    it 'says that a directory is not in use while RECORDING_DIR_PER_TENANT is off' do
      allow(Rails.configuration.x).to receive(:recording_dir_per_tenant).and_return(false)
      create(:tenant, name: 'tenant1')
      create(:tenant, name: 'tenant2', recording_dir: '/mnt/recordings/tenant2')

      line = %r{\trecording dir: /mnt/recordings/tenant2 \(not in use, RECORDING_DIR_PER_TENANT is off\)\n}
      expect { task.invoke }.to output(/\A(?:(?!recording dir).)*#{line}(?:(?!recording dir).)*\z/m).to_stdout
    end
  end

  describe ':add' do
    let(:task) { Rake::Task['tenants:add'] }

    it 'adds a new tenant' do
      tenant_name = 'tenant_name'
      tenant_secrets = 'tenant_secrets'
      expect {
        task.invoke(tenant_name, tenant_secrets)
      }.to change { Tenant.all.count }.by(1)
    end
  end

  describe ':update' do
    let(:task) { Rake::Task['tenants:update'] }
    let(:tenant) { create(:tenant) }

    it 'updates an existing tenant' do
      tenant_name = 'new_tenant_name'
      tenant_secrets = 'new_tenant_secrets'

      task.invoke(tenant.id, tenant_name, tenant_secrets)

      reload_tenant = Tenant.find(tenant.id)

      expect(reload_tenant.name).to eq(tenant_name)
      expect(reload_tenant.secrets).to eq(tenant_secrets)
    end
  end

  describe ':recording_dir' do
    let(:task) { Rake::Task['tenants:recording_dir'] }
    let(:dir) { File.realpath(Dir.mktmpdir) }

    after do
      FileUtils.rm_rf(dir)
    end

    it 'gives a tenant a directory of its own for its recordings' do
      allow(Rails.configuration.x).to receive(:recording_dir_per_tenant).and_return(true)
      tenant = create(:tenant)

      expect { task.invoke(tenant.id, "#{dir}/") }.to output(
        "OK\nrecording dir: #{dir}\n" \
        "The web server container needs #{dir}/published under the same path, or playback answers 404.\n" \
        "Move existing recordings with: rake recordings:relocate[#{tenant.id}]\n"
      ).to_stdout
      expect(Tenant.find(tenant.id).recording_dir).to eq dir
    end

    it 'does not ask for a mount when the directory lies inside the publish directory' do
      allow(Rails.configuration.x).to receive_messages(recording_dir_per_tenant: true, recording_publish_dir: dir)
      tenant = create(:tenant)
      FileUtils.mkdir_p("#{dir}/tenants/tenant1")

      expect { task.invoke(tenant.id, "#{dir}/tenants/tenant1") }.to output(
        "OK\nrecording dir: #{dir}/tenants/tenant1\nMove existing recordings with: rake recordings:relocate[#{tenant.id}]\n"
      ).to_stdout
    end

    it 'says so when the directory is not in use because RECORDING_DIR_PER_TENANT is off' do
      allow(Rails.configuration.x).to receive(:recording_dir_per_tenant).and_return(false)
      tenant = create(:tenant)

      expect { task.invoke(tenant.id, dir) }.to output(/recording dir: #{dir} \(not in use, RECORDING_DIR_PER_TENANT is off\)/).to_stdout
      expect(Tenant.find(tenant.id).recording_dir).to eq dir
    end

    it 'takes the directory away again when it is left empty, and keeps everything else' do
      allow(Rails.configuration.x).to receive_messages(recording_dir_per_tenant: true,
                                                       recording_publish_dir: '/var/bigbluebutton/published')
      tenant = create(:tenant, name: 'tenant1', recording_dir: dir, secrets: 'secret1')

      expect { task.invoke(tenant.id, '') }.to output(/\AOK\nrecording dir: none\nMove existing recordings with: /).to_stdout
      expect(Tenant.find(tenant.id).recording_dir).to be_nil
      expect(Tenant.find(tenant.id).secrets).to eq 'secret1'
    end

    it 'refuses a directory that is not there in the container, and keeps what the tenant had' do
      allow(Rails.configuration.x).to receive(:recording_publish_dir).and_return('/var/bigbluebutton/published')
      tenant = create(:tenant, recording_dir: dir)

      expect { task.invoke(tenant.id, "#{dir}/not-mounted") }.to raise_error(SystemExit).and(
        output("ERROR: #{dir}/not-mounted does not exist inside this container. Scalelite does not create it: create it on " \
               'the host, on a volume the containers have, and give the path as the containers see it. This one has the ' \
               "recordings below /var/bigbluebutton.\n").to_stderr
      )
      expect(Tenant.find(tenant.id).recording_dir).to eq dir
      expect(File.exist?("#{dir}/not-mounted")).to be false
    end

    it 'refuses a path that is not a directory' do
      tenant = create(:tenant)
      File.write("#{dir}/file", '')

      expect { task.invoke(tenant.id, "#{dir}/file") }.to raise_error(SystemExit).and(
        output("ERROR: #{dir}/file exists inside this container, but is not a directory.\n").to_stderr
      )
      expect(Tenant.find(tenant.id).recording_dir).to be_nil
    end

    it 'refuses a directory it cannot write to, and says to whom to hand it' do
      tenant = create(:tenant)
      allow(File).to receive(:writable?).and_call_original
      allow(File).to receive(:writable?).with(dir).and_return(false)

      expect { task.invoke(tenant.id, dir) }.to raise_error(SystemExit).and(
        output("ERROR: #{dir} is not writable for the user this task runs as (UID #{Process.uid}). Hand it to that user " \
               "on the host, as in: chown #{Process.uid} <directory>\n").to_stderr
      )
      expect(Tenant.find(tenant.id).recording_dir).to be_nil
    end

    context 'when the tenant had another directory before' do
      let(:shared) { File.realpath(Dir.mktmpdir) }
      let(:new_dir) { File.join(shared, 'tenant1-new') }
      let(:tenant) { create(:tenant, name: 'tenant1', recording_dir: dir) }

      before do
        FileUtils.mkdir_p([File.join(shared, 'published'), File.join(shared, 'unpublished'), new_dir])
        allow(Rails.configuration.x).to receive_messages(recording_dir_per_tenant: true,
                                                         recording_publish_dir: File.join(shared, 'published'),
                                                         recording_unpublish_dir: File.join(shared, 'unpublished'))
      end

      after do
        FileUtils.rm_rf(shared)
      end

      # A recording with one format whose files are in the given directory
      def recorded(dir, state = :unpublished, of_tenant: tenant)
        recording = create(:recording, state)
        create(:metadatum, recording: recording, key: 'tenant-id', value: of_tenant.id) if of_tenant
        create(:playback_format, recording: recording, format: 'presentation')
        files = File.join(dir, 'presentation', recording.record_id)
        FileUtils.mkdir_p(files)
        [recording, files]
      end

      it 'moves the unpublished recordings into the directory it has now, and leaves the published ones to relocate' do
        hidden, files = recorded(File.join(dir, 'unpublished'))
        _shown, published = recorded(File.join(dir, 'published'), :published)
        target = File.join(new_dir, 'unpublished', 'presentation', hidden.record_id)

        expect { task.invoke(tenant.id, new_dir) }.to output(
          "OK\nrecording dir: #{new_dir}\n" \
          "The web server container needs #{new_dir}/published under the same path, or playback answers 404.\n" \
          "#{files} -> #{target}\n" \
          "1 unpublished playback formats moved out of #{dir}/unpublished\n" \
          "Move existing recordings with: rake recordings:relocate[#{tenant.id}]\n"
        ).to_stdout
        expect(File.directory?(target)).to be true
        expect(File.exist?(files)).to be false
        expect(File.directory?(published)).to be true
      end

      it 'moves them to where all recordings are kept when the directory is taken away' do
        hidden, files = recorded(File.join(dir, 'unpublished'))
        target = File.join(shared, 'unpublished', 'presentation', hidden.record_id)

        expect { task.invoke(tenant.id, '') }.to output(/^#{files} -> #{target}$/).to_stdout
        expect(File.directory?(target)).to be true
      end

      it 'moves them to where all recordings are kept while RECORDING_DIR_PER_TENANT is off' do
        allow(Rails.configuration.x).to receive(:recording_dir_per_tenant).and_return(false)
        hidden, files = recorded(File.join(dir, 'unpublished'))
        target = File.join(shared, 'unpublished', 'presentation', hidden.record_id)

        expect { task.invoke(tenant.id, new_dir) }.to output(/^#{files} -> #{target}$/).to_stdout
      end

      it 'leaves what it cannot move where it is, and names each one' do
        unknown = File.join(dir, 'unpublished', 'presentation', 'unknown-record')
        FileUtils.mkdir_p(unknown)
        deleted, deleted_files = recorded(File.join(dir, 'unpublished'))
        deleted.mark_delete!
        _other, other_files = recorded(File.join(dir, 'unpublished'), of_tenant: create(:tenant, name: 'tenant2'))
        twice, twice_files = recorded(File.join(dir, 'unpublished'))
        copy = File.join(shared, 'unpublished', 'presentation', twice.record_id)
        FileUtils.mkdir_p(copy)

        expect { task.invoke(tenant.id, new_dir) }.to output(/\AOK\n/).to_stdout.and(
          output(
            a_string_including(
              "WARNING: #{unknown} is not known to Scalelite and was left where it is\n",
              "WARNING: #{deleted_files} belongs to a recording that was deleted in Scalelite and was left where it is: " \
              "remove it by hand\n",
              "WARNING: #{other_files} is not a recording of tenant tenant1 and was left where it is\n",
              "WARNING: #{twice_files} was left where it is: the recording has its presentation files in #{copy} as well, " \
              "and nothing can tell which copy is the good one\n",
              "WARNING: 4 unpublished playback formats are left in #{dir}/unpublished, see above\n"
            )
          ).to_stderr
        )
        [unknown, deleted_files, other_files, twice_files, copy].each { |kept| expect(File.directory?(kept)).to be true }
      end

      it 'says so when the directory it had before is not there, and what to do once it is' do
        FileUtils.rm_rf(dir)

        expect { task.invoke(tenant.id, new_dir) }.to output(/\AOK\n/).to_stdout.and(
          output("WARNING: #{dir}, the directory the tenant had before, is not there, so its unpublished recordings could " \
                 "not be moved. Once it is mounted again, move #{dir}/unpublished/<format>/<record id> to " \
                 "#{new_dir}/unpublished/<format>/<record id> by hand: nothing else finds them, neither to publish nor " \
                 "to delete them.\n").to_stderr
        )
        expect(Tenant.find(tenant.id).recording_dir).to eq new_dir
      end

      it 'leaves the recordings of everybody else alone when the directory it had held where all recordings are kept' do
        owner = create(:tenant, name: 'tenant3', recording_dir: shared)
        _others, files = recorded(File.join(shared, 'unpublished'), of_tenant: create(:tenant, name: 'tenant2'))

        expect { task.invoke(owner.id, new_dir) }.not_to output.to_stderr
        expect(File.directory?(files)).to be true
      end
    end

    it 'refuses a directory that is not an absolute path' do
      tenant = create(:tenant)

      expect { task.invoke(tenant.id, 'recordings/tenant1') }.to raise_error(SystemExit).and(
        output(/ERROR: Recording directory must be an absolute path/).to_stderr
      )
      expect(Tenant.find(tenant.id).recording_dir).to be_nil
    end

    it 'says so when there is no tenant with that id' do
      expect { task.invoke('no-such-tenant', dir) }.to raise_error(SystemExit).and(
        output(/ERROR: No tenant found with id: no-such-tenant/).to_stderr
      )
    end
  end

  describe ':remove' do
    let(:task) { Rake::Task['tenants:remove'] }

    it 'removes an existing tenant' do
      tenant = create(:tenant)
      expect {
        task.invoke(tenant.id)
      }.to change { Tenant.all.count }.by(-1)
    end
  end
end
