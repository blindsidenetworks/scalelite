# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'recordings tasks', type: :task do
  before do
    Rails.application.load_tasks
  end

  after do
    Rake::Task.clear
  end

  describe ':relocate', :redis do
    let(:task) { Rake::Task['recordings:relocate'] }
    let(:base) { File.realpath(Dir.mktmpdir) }
    let(:publish_dir) { File.join(base, 'published') }
    let(:unpublish_dir) { File.join(base, 'unpublished') }
    let(:per_tenant) { true }
    # The directory an operator gave the tenant
    let(:own_dir) { File.join(base, 'tenant1-volume') }
    let(:tenant) { create(:tenant, name: 'tenant1', recording_dir: own_dir) }
    let(:summary) { '0 linked again, 0 already in place, 0 not found, 0 in more than one place, 0 failed' }
    # What is typed when the task asks whether to go on
    let(:answer) { "y\n" }

    before do
      FileUtils.mkdir_p([publish_dir, unpublish_dir, own_dir])
      allow(Rails.configuration.x).to receive_messages(recording_publish_dir: publish_dir,
                                                       recording_unpublish_dir: unpublish_dir,
                                                       recording_dir_per_tenant: per_tenant)
      allow($stdin).to receive(:gets).and_return(answer)
    end

    after do
      FileUtils.rm_rf(base)
    end

    # A recording with one format, of the tenant unless told otherwise, and where all recordings are kept
    def recorded(state = :published, of_tenant: tenant)
      recording = create(:recording, state)
      create(:metadatum, recording: recording, key: 'tenant-id', value: of_tenant.id) if of_tenant
      create(:playback_format, recording: recording, format: 'presentation')
      [recording, File.join(state == :published ? publish_dir : unpublish_dir, 'presentation', recording.record_id)]
    end

    it 'moves the recordings of a tenant into the directory it was given and leaves all others where they are' do
      own, address = recorded
      FileUtils.mkdir_p(address)
      hidden, unpublished = recorded(:unpublished)
      FileUtils.mkdir_p(unpublished)
      _shared, shared_address = recorded(of_tenant: nil)
      FileUtils.mkdir_p(shared_address)
      _other, other_address = recorded(of_tenant: create(:tenant, name: 'tenant2'))
      FileUtils.mkdir_p(other_address)
      target = File.join(own_dir, 'published', 'presentation', own.record_id)

      expect { task.invoke }.to output(
        /^#{address} -> #{target}$.*^2 playback formats moved, 0 linked again, 2 already in place, 0 not found/m
      ).to_stdout
      expect(File.readlink(address)).to eq target
      expect(File.directory?(target)).to be true
      expect(File.exist?(unpublished)).to be false
      expect(File.directory?(File.join(own_dir, 'unpublished', 'presentation', hidden.record_id))).to be true
      [shared_address, other_address].each do |untouched|
        expect(File.directory?(untouched)).to be true
        expect(File.symlink?(untouched)).to be false
      end
      # Nothing but the playback formats in the directory all recordings are kept in
      expect(Dir.children(publish_dir)).to eq ['presentation']
    end

    it 'says how much it is about to move and asks before it does' do
      own, address = recorded
      FileUtils.mkdir_p(address)
      target = File.join(own_dir, 'published', 'presentation', own.record_id)

      expect { task.invoke }.to output(
        "1 playback formats will be moved and 0 linked again.\n" \
        "\t1 from #{publish_dir} to #{File.join(own_dir, 'published')}\n" \
        "WARNING: the web server container must see these directories under the same path, or the recordings answer 404:\n" \
        "\t#{File.join(own_dir, 'published')}\n" \
        "Continue? [y/N]\n" \
        "#{address} -> #{target}\n1 playback formats moved, #{summary}\n"
      ).to_stdout
      expect(File.readlink(address)).to eq target
    end

    it 'says from which directory into which, with one line for each pair however many recordings there are' do
      3.times { FileUtils.mkdir_p(recorded.last) }
      FileUtils.mkdir_p(recorded(:unpublished).last)

      expect { task.invoke }.to output(
        a_string_starting_with(
          "4 playback formats will be moved and 0 linked again.\n" \
          "\t3 from #{publish_dir} to #{File.join(own_dir, 'published')}\n" \
          "\t1 from #{unpublish_dir} to #{File.join(own_dir, 'unpublished')}\n" \
          'WARNING: the web server container must see these directories'
        )
      ).to_stdout
    end

    ["n\n", "\n", "maybe\n", nil].each do |refusal|
      context "when the answer is #{refusal.inspect}" do
        let(:answer) { refusal }

        it 'moves nothing' do
          _own, address = recorded
          FileUtils.mkdir_p(address)

          expect { task.invoke }.to raise_error(SystemExit).and(output(%r{Continue\? \[y/N\]\nNothing was moved\.\n\z}).to_stdout)
          expect(File.symlink?(address)).to be false
          expect(File.directory?(address)).to be true
          expect(Dir.children(own_dir)).to be_empty
        end
      end
    end

    context 'when the answer is YES' do
      let(:answer) { " YES \n" }

      it 'moves the recordings' do
        _own, address = recorded
        FileUtils.mkdir_p(address)

        expect { task.invoke }.to output(/^1 playback formats moved/).to_stdout
        expect(File.symlink?(address)).to be true
      end
    end

    it 'does not warn about the web server when the directory of the tenant lies inside the publish directory' do
      tenant.recording_dir = File.join(publish_dir, 'tenants', 'tenant1')
      tenant.save!
      FileUtils.mkdir_p(tenant.recording_dir)
      own, address = recorded
      FileUtils.mkdir_p(address)

      expect { task.invoke }.to output(
        "1 playback formats will be moved and 0 linked again.\n" \
        "\t1 from #{publish_dir} to #{File.join(tenant.recording_dir, 'published')}\n" \
        "Continue? [y/N]\n" \
        "#{address} -> #{File.join(tenant.recording_dir, 'published', 'presentation', own.record_id)}\n" \
        "1 playback formats moved, #{summary}\n"
      ).to_stdout
      expect(File.readlink(address)).to eq "../tenants/tenant1/published/presentation/#{own.record_id}"
    end

    it 'does not warn about the web server when the recordings are moved back to where all recordings are' do
      tenant.recording_dir = nil
      tenant.save!
      own, address = recorded
      files = File.join(own_dir, 'published', 'presentation', own.record_id)
      FileUtils.mkdir_p([files, File.dirname(address)])
      File.symlink(files, address)

      expect { task.invoke }.to output(
        "1 playback formats will be moved and 0 linked again.\n" \
        "\t1 from #{File.join(own_dir, 'published')} to #{publish_dir}\n" \
        "Continue? [y/N]\n#{files} -> #{address}\n1 playback formats moved, #{summary}\n"
      ).to_stdout
    end

    it 'does not ask when there is nothing to move' do
      _shared, shared_address = recorded(of_tenant: nil)
      FileUtils.mkdir_p(shared_address)

      expect { task.invoke }.to output(
        "0 playback formats moved, 0 linked again, 1 already in place, 0 not found, 0 in more than one place, 0 failed\n"
      ).to_stdout
      expect($stdin).not_to have_received(:gets)
    end

    it 'moves only the recordings of the tenant it is given' do
      other_dir = File.join(base, 'tenant2-volume')
      FileUtils.mkdir_p(other_dir)
      other = create(:tenant, name: 'tenant2', recording_dir: other_dir)
      own, address = recorded
      FileUtils.mkdir_p(address)
      _theirs, their_address = recorded(of_tenant: other)
      FileUtils.mkdir_p(their_address)
      target = File.join(own_dir, 'published', 'presentation', own.record_id)

      expect { task.invoke(tenant.id) }.to output(
        "1 playback formats of tenant tenant1 will be moved and 0 linked again.\n" \
        "\t1 from #{publish_dir} to #{File.join(own_dir, 'published')}\n" \
        "WARNING: the web server container must see these directories under the same path, or the recordings answer 404:\n" \
        "\t#{File.join(own_dir, 'published')}\n" \
        "Continue? [y/N]\n" \
        "#{address} -> #{target}\n1 playback formats moved, #{summary}\n"
      ).to_stdout
      expect(File.readlink(address)).to eq target
      expect(File.symlink?(their_address)).to be false
      expect(Dir.children(other_dir)).to be_empty
    end

    it 'says so when there is no tenant with the id it is given' do
      _own, address = recorded
      FileUtils.mkdir_p(address)

      expect { task.invoke('no-such-tenant') }.to raise_error(SystemExit).and(
        output(/ERROR: No tenant found with id: no-such-tenant/).to_stderr
      )
      expect(File.symlink?(address)).to be false
    end

    it 'refuses a second argument, instead of reading an empty first one as every tenant' do
      _own, address = recorded
      FileUtils.mkdir_p(address)

      expect { task.invoke('', tenant.id) }.to raise_error(SystemExit).and(
        output(/ERROR: rake recordings:relocate takes the ID of a tenant and nothing else/).to_stderr
      )
      task.reenable
      expect { task.invoke('true') }.to raise_error(SystemExit).and(output(/ERROR: No tenant found with id: true/).to_stderr)
      expect(File.symlink?(address)).to be false
      expect($stdin).not_to have_received(:gets)
    end

    it 'moves nothing when it is run a second time' do
      _own, address = recorded
      FileUtils.mkdir_p(address)
      expect { task.invoke }.to output(/^1 playback formats moved/).to_stdout

      task.reenable
      expect { task.invoke }.to output(
        "0 playback formats moved, 0 linked again, 1 already in place, 0 not found, 0 in more than one place, 0 failed\n"
      ).to_stdout
    end

    it 'moves back recordings that lie in a directory named after a tenant' do
      own, address = recorded(of_tenant: create(:tenant, name: 'tenant2'))
      files = File.join(publish_dir, 'tenant2', 'presentation', own.record_id)
      FileUtils.mkdir_p([files, File.dirname(address)])
      File.symlink("../tenant2/presentation/#{own.record_id}", address)
      hidden, hidden_target = recorded(:unpublished, of_tenant: Tenant.find_by_name('tenant2'))
      hidden_files = File.join(unpublish_dir, 'tenant2', 'presentation', hidden.record_id)
      FileUtils.mkdir_p(hidden_files)

      expect { task.invoke }.to output(
        /^#{files} -> #{address}$.*^#{hidden_files} -> #{hidden_target}$.*^2 playback formats moved, #{summary}$/m
      ).to_stdout
      expect(File.symlink?(address)).to be false
      expect(File.directory?(address)).to be true
      expect(File.directory?(hidden_target)).to be true
    end

    it 'leaves a recording alone that is in more than one place, and says so' do
      own, address = recorded
      copy = File.join(own_dir, 'published', 'presentation', own.record_id)
      FileUtils.mkdir_p([address, copy])

      expect { task.invoke }.to output(/1 in more than one place/).to_stdout.and(
        output(/WARNING: #{own.record_id} presentation is in more than one place and was left alone: #{copy}, #{address}/).to_stderr
      )
      expect(File.directory?(address)).to be true
      expect(File.symlink?(address)).to be false
    end

    it 'asks whether the recordings are mounted when it finds none of them' do
      recorded

      expect { task.invoke }.to output(/1 not found/).to_stdout.and(output(/not one recording was found/).to_stderr)
    end

    it 'goes on with the other recordings when the directory of a tenant is not there' do
      away = create(:tenant, name: 'tenant2', recording_dir: File.join(base, 'not-mounted'))
      _stuck, stuck_address = recorded(of_tenant: away)
      FileUtils.mkdir_p(stuck_address)
      _own, address = recorded
      FileUtils.mkdir_p(address)

      expect { task.invoke }.to output(/1 playback formats moved.* 1 failed/).to_stdout.and(
        output(/ERROR: .* could not be moved: The recording directory .*not-mounted of tenant #{away.id} is not a writable/).to_stderr
      )
      expect(File.symlink?(stuck_address)).to be false
      expect(File.directory?(stuck_address)).to be true
      expect(File.symlink?(address)).to be true
    end

    it 'has nothing to do where recordings are kept in S3' do
      stub_const('ENV', ENV.to_h.merge('S3_RECORDING' => 'true'))

      expect { task.invoke }.to raise_error(SystemExit).and(output(/nothing to relocate/).to_stderr)
    end

    context 'with RECORDING_DIR_PER_TENANT off' do
      let(:per_tenant) { false }

      it 'moves the recordings back to where all recordings are kept' do
        own, address = recorded
        files = File.join(own_dir, 'published', 'presentation', own.record_id)
        FileUtils.mkdir_p([files, File.dirname(address)])
        File.symlink(files, address)

        expect { task.invoke }.to output(/^#{files} -> #{address}\n1 playback formats moved, #{summary}\n\z/).to_stdout
        expect(File.symlink?(address)).to be false
        expect(File.directory?(address)).to be true
        expect(File.exist?(files)).to be false
      end

      it 'says that the directory of the tenant is not used, which is also what a forgotten setting looks like' do
        _own, address = recorded
        FileUtils.mkdir_p(address)

        expect { task.invoke(tenant.id) }.to output(
          'NOTE: RECORDING_DIR_PER_TENANT is off, so the directories given to tenants are not used: the recordings of ' \
          "tenant tenant1 belong in #{publish_dir} and #{unpublish_dir}.\n" \
          "0 playback formats moved, 0 linked again, 1 already in place, 0 not found, 0 in more than one place, 0 failed\n"
        ).to_stdout
      end

      it 'counts the tenants with a directory when it goes through all of them' do
        tenant
        create(:tenant, name: 'tenant2', recording_dir: File.join(base, 'tenant2-volume'))
        create(:tenant, name: 'tenant3')

        expect { task.invoke }.to output(/\ANOTE: .* the recordings of 2 tenants belong in /).to_stdout
      end

      it 'says nothing about it when no tenant has a directory' do
        create(:tenant, name: 'tenant2')

        expect { task.invoke }.not_to output(/NOTE/).to_stdout
      end
    end

    it 'says nothing about the setting while it is on' do
      tenant

      expect { task.invoke }.not_to output(/NOTE/).to_stdout
    end
  end
end
