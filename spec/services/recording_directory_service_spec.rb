# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecordingDirectoryService, :redis do
  let(:base) { File.realpath(Dir.mktmpdir) }
  let(:publish_dir) { File.join(base, 'published') }
  let(:unpublish_dir) { File.join(base, 'unpublished') }
  let(:per_tenant) { true }
  # The directory an operator gave the tenant, on a volume of its own
  let(:own_dir) { File.join(base, 'tenant1-volume') }
  let(:tenant) { create(:tenant, name: 'tenant1', recording_dir: own_dir) }
  let(:recording) { create(:recording, :published) }
  let(:record_id) { recording.record_id }
  let(:directories) { described_class.new(recording) }

  # The path upstream gives a published format, and the paths inside the directory of the tenant
  let(:address) { File.join(publish_dir, 'presentation', record_id) }
  let(:shared_unpublished) { File.join(unpublish_dir, 'presentation', record_id) }
  let(:tenant_published) { File.join(own_dir, 'published', 'presentation', record_id) }
  let(:tenant_unpublished) { File.join(own_dir, 'unpublished', 'presentation', record_id) }
  # A directory named after the tenant next to the playback formats, which is not where a recording belongs
  let(:named_published) { File.join(publish_dir, 'tenant1', 'presentation', record_id) }
  let(:named_link) { "../tenant1/presentation/#{record_id}" }

  before do
    FileUtils.mkdir_p([publish_dir, unpublish_dir, own_dir])
    allow(Rails.configuration.x).to receive_messages(recording_publish_dir: publish_dir,
                                                     recording_unpublish_dir: unpublish_dir,
                                                     recording_dir_per_tenant: per_tenant)
    create(:metadatum, recording: recording, key: 'tenant-id', value: tenant.id)
  end

  after do
    FileUtils.rm_rf(base)
  end

  # The files of a format in the given directory, one file that says where it was put
  def store(dir)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'metadata.xml'), dir)
    dir
  end

  # A link at the address of the format, as an import or a move leaves it
  def link_address(target)
    FileUtils.mkdir_p(File.dirname(address))
    File.symlink(target, address)
  end

  # What is played back under the address of the format, wherever the files are
  def served
    File.read(File.join(address, 'metadata.xml'))
  end

  describe '#path' do
    it 'is inside the directory an operator gave the tenant' do
      expect(directories.path('presentation', published: true)).to eq tenant_published
      expect(directories.path('presentation', published: false)).to eq tenant_unpublished
    end

    it 'is where all recordings are kept when the recording has no tenant' do
      untenanted = create(:recording, :published)

      expect(described_class.new(untenanted).path('presentation', published: true))
        .to eq File.join(publish_dir, 'presentation', untenanted.record_id)
    end

    it 'is where all recordings are kept when its tenant is gone' do
      tenant.destroy!

      expect(directories.path('presentation', published: true)).to eq address
    end

    context 'with a tenant that was not given a directory' do
      let(:tenant) { create(:tenant, name: 'tenant1') }

      it 'is where all recordings are kept' do
        expect(directories.path('presentation', published: true)).to eq address
        expect(directories.path('presentation', published: false)).to eq shared_unpublished
      end
    end

    context 'with RECORDING_DIR_PER_TENANT off' do
      let(:per_tenant) { false }

      it 'is where all recordings are kept, whatever directory its tenant was given' do
        expect(directories.path('presentation', published: true)).to eq address
        expect(directories.path('presentation', published: false)).to eq shared_unpublished
      end
    end
  end

  describe '#import' do
    let(:source) { store(File.join(base, 'work', 'presentation', record_id)) }

    it 'moves a published format into the directory of the tenant and links its address to it' do
      directories.import(source, 'presentation', published: true)

      expect(File.directory?(source)).to be false
      expect(File.read(File.join(tenant_published, 'metadata.xml'))).to eq source
      expect(File.readlink(address)).to eq tenant_published
      expect(served).to eq source
    end

    it 'moves an unpublished format into the unpublished directory of the tenant, with nothing at its address' do
      directories.import(source, 'presentation', published: false)

      expect(File.directory?(tenant_unpublished)).to be true
      expect(File.exist?(address)).to be false
      expect(File.symlink?(address)).to be false
    end

    it 'replaces what an earlier import left where all recordings are kept' do
      store(address)

      directories.import(source, 'presentation', published: true)

      expect(File.symlink?(address)).to be true
      expect(served).to eq source
    end

    it 'takes the link away when the recording is imported again as unpublished' do
      directories.import(store(File.join(base, 'earlier')), 'presentation', published: true)

      directories.import(source, 'presentation', published: false)

      expect(File.symlink?(address)).to be false
      expect(File.directory?(tenant_published)).to be false
      expect(File.read(File.join(tenant_unpublished, 'metadata.xml'))).to eq source
    end

    it 'links to a directory that lies inside the publish directory by a relative path' do
      tenant.recording_dir = File.join(publish_dir, 'tenants', 'tenant1')
      tenant.save!
      FileUtils.mkdir_p(tenant.recording_dir)

      directories.import(source, 'presentation', published: true)

      expect(File.readlink(address)).to eq "../tenants/tenant1/published/presentation/#{record_id}"
      expect(served).to eq source
    end

    it 'refuses to create the directory of the tenant, and touches nothing' do
      store(address)
      tenant.recording_dir = File.join(base, 'not-mounted')
      tenant.save!

      expect { directories.import(source, 'presentation', published: true) }.to raise_error(described_class::Unavailable, /not-mounted/)
      expect(File.directory?(source)).to be true
      expect(File.directory?(File.join(base, 'not-mounted'))).to be false
      expect(served).to eq address
    end

    context 'with a tenant that was not given a directory' do
      let(:tenant) { create(:tenant, name: 'tenant1') }

      it 'moves the format to where all recordings are kept, without a link' do
        directories.import(source, 'presentation', published: true)

        expect(File.symlink?(address)).to be false
        expect(served).to eq source
        expect(Dir.children(publish_dir)).to eq ['presentation']
        expect(Dir.children(unpublish_dir)).to be_empty
      end

      it 'replaces files and a link that lie in a directory named after the tenant' do
        store(named_published)
        link_address(named_link)

        directories.import(source, 'presentation', published: true)

        expect(File.symlink?(address)).to be false
        expect(served).to eq source
        expect(File.directory?(named_published)).to be false
      end
    end

    context 'with RECORDING_DIR_PER_TENANT off' do
      let(:per_tenant) { false }

      it 'moves the format to where all recordings are kept, without a link' do
        directories.import(source, 'presentation', published: true)

        expect(File.symlink?(address)).to be false
        expect(served).to eq source
        expect(Dir.children(own_dir)).to be_empty
      end

      it 'replaces the files and the link an import left while the setting was on' do
        store(tenant_published)
        link_address(tenant_published)

        directories.import(source, 'presentation', published: true)

        expect(File.symlink?(address)).to be false
        expect(served).to eq source
        expect(File.directory?(tenant_published)).to be false
      end
    end
  end

  describe '#place' do
    it 'moves the files to the unpublished directory of the tenant and takes the link away' do
      directories.import(store(File.join(base, 'work')), 'presentation', published: true)

      directories.place('presentation', published: false)

      expect(File.directory?(tenant_unpublished)).to be true
      expect(File.directory?(tenant_published)).to be false
      expect(File.symlink?(address)).to be false
    end

    it 'moves the files back and links them again' do
      directories.import(store(File.join(base, 'work')), 'presentation', published: false)

      directories.place('presentation', published: true)

      expect(File.directory?(tenant_unpublished)).to be false
      expect(File.readlink(address)).to eq tenant_published
      expect(served).to eq File.join(base, 'work')
    end

    it 'takes the files of a recording that was never relocated from where all recordings are kept' do
      store(address)

      directories.place('presentation', published: false)

      expect(File.exist?(address)).to be false
      expect(File.read(File.join(tenant_unpublished, 'metadata.xml'))).to eq address
    end

    it 'leaves files alone that are in place, and removes a copy left where they were' do
      store(tenant_unpublished)
      store(tenant_published)

      directories.place('presentation', published: false)

      expect(File.read(File.join(tenant_unpublished, 'metadata.xml'))).to eq tenant_unpublished
      expect(File.directory?(tenant_published)).to be false
    end

    it 'raises when the format has no files anywhere' do
      expect { directories.place('presentation', published: false) }
        .to raise_error(described_class::NotFound, 'Recording has no recording files')
    end

    context 'with a tenant that was not given a directory' do
      let(:tenant) { create(:tenant, name: 'tenant1') }

      it 'moves the files between the publish and the unpublish directory, as it always did' do
        store(address)

        directories.place('presentation', published: false)
        expect(File.exist?(address)).to be false
        expect(File.read(File.join(shared_unpublished, 'metadata.xml'))).to eq address

        directories.place('presentation', published: true)
        expect(File.exist?(shared_unpublished)).to be false
        expect(File.symlink?(address)).to be false
        expect(served).to eq address
        expect(Dir.children(publish_dir)).to eq ['presentation']
      end

      it 'brings back files that lie in a directory named after the tenant' do
        unpublished = store(File.join(unpublish_dir, 'tenant1', 'presentation', record_id))

        directories.place('presentation', published: true)

        expect(File.directory?(unpublished)).to be false
        expect(File.symlink?(address)).to be false
        expect(served).to eq unpublished
      end
    end

    context 'with RECORDING_DIR_PER_TENANT off' do
      let(:per_tenant) { false }

      it 'moves the files between the publish and the unpublish directory, as upstream does' do
        store(address)

        directories.place('presentation', published: false)
        expect(File.exist?(address)).to be false
        expect(File.read(File.join(shared_unpublished, 'metadata.xml'))).to eq address

        directories.place('presentation', published: true)
        expect(File.exist?(shared_unpublished)).to be false
        expect(File.symlink?(address)).to be false
        expect(served).to eq address
      end

      it 'removes the copy in the directory the recording is leaving when both have one' do
        store(address)
        store(shared_unpublished)

        directories.place('presentation', published: false)

        expect(File.exist?(address)).to be false
        expect(File.read(File.join(shared_unpublished, 'metadata.xml'))).to eq shared_unpublished
      end
    end
  end

  describe '#relocate' do
    it 'moves a format from where all recordings are kept into the directory of the tenant and links it' do
      store(address)

      expect(directories.relocate('presentation')).to eq [:moved, [address, tenant_published]]
      expect(File.readlink(address)).to eq tenant_published
      expect(served).to eq address
    end

    it 'moves an unpublished format into the unpublished directory of the tenant' do
      recording.update!(published: false)
      store(shared_unpublished)

      expect(directories.relocate('presentation')).to eq [:moved, [shared_unpublished, tenant_unpublished]]
      expect(File.exist?(address)).to be false
    end

    it 'only reports what it would do on a dry run' do
      store(address)

      expect(directories.relocate('presentation', dry_run: true)).to eq [:moved, [address, tenant_published]]
      expect(File.symlink?(address)).to be false
      expect(File.directory?(tenant_published)).to be false
    end

    it 'leaves a format alone that is where it belongs' do
      directories.import(store(File.join(base, 'work')), 'presentation', published: true)

      expect(directories.relocate('presentation')).to eq [:in_place, [tenant_published]]
    end

    it 'links a format again whose link is gone' do
      store(tenant_published)

      expect(directories.relocate('presentation')).to eq [:relinked, [tenant_published]]
      expect(served).to eq tenant_published
    end

    it 'follows the link into a directory the tenant had before' do
      former = store(File.join(base, 'former-volume', 'published', 'presentation', record_id))
      link_address(former)

      expect(directories.relocate('presentation')).to eq [:moved, [former, tenant_published]]
      expect(File.readlink(address)).to eq tenant_published
      expect(served).to eq former
    end

    it 'leaves a format alone that is in more than one place, and says where' do
      store(address)
      store(tenant_published)

      expect(directories.relocate('presentation')).to eq [:scattered, [tenant_published, address]]
      expect(File.directory?(address)).to be true
      expect(File.directory?(tenant_published)).to be true
    end

    it 'reports a format whose files are nowhere' do
      expect(directories.relocate('presentation')).to eq [:missing, []]
    end

    context 'with a tenant that was not given a directory' do
      let(:tenant) { create(:tenant, name: 'tenant1') }

      it 'leaves a format alone that is where all recordings are kept' do
        store(address)

        expect(directories.relocate('presentation')).to eq [:in_place, [address]]
        expect(File.symlink?(address)).to be false
        expect(Dir.children(publish_dir)).to eq ['presentation']
      end

      it 'moves back a format that lies in a directory named after the tenant' do
        store(named_published)
        link_address(named_link)

        expect(directories.relocate('presentation')).to eq [:moved, [named_published, address]]
        expect(File.symlink?(address)).to be false
        expect(served).to eq named_published
      end

      it 'moves back an unpublished format from a directory named after the tenant' do
        recording.update!(published: false)
        unpublished = store(File.join(unpublish_dir, 'tenant1', 'presentation', record_id))

        expect(directories.relocate('presentation')).to eq [:moved, [unpublished, shared_unpublished]]
        expect(File.directory?(shared_unpublished)).to be true
      end
    end

    context 'with RECORDING_DIR_PER_TENANT off' do
      let(:per_tenant) { false }

      it 'moves a format back to where all recordings are kept, in place of the link' do
        store(tenant_published)
        link_address(tenant_published)

        expect(directories.relocate('presentation')).to eq [:moved, [tenant_published, address]]
        expect(File.symlink?(address)).to be false
        expect(served).to eq tenant_published
      end

      it 'finds an unpublished format in the directory of the tenant, which no link leads to' do
        recording.update!(published: false)
        store(tenant_unpublished)

        expect(directories.relocate('presentation')).to eq [:moved, [tenant_unpublished, shared_unpublished]]
      end
    end
  end

  describe '#adopt' do
    # An unpublished format in a directory the tenant had before, which nothing else looks in
    let(:former) { File.join(base, 'former-volume', 'unpublished', 'presentation', record_id) }

    before do
      recording.update!(published: false)
    end

    it 'moves an unpublished format from a directory the tenant had before into the one it has now' do
      store(former)

      expect(directories.adopt(former, 'presentation')).to eq [:moved, [former, tenant_unpublished]]
      expect(File.read(File.join(tenant_unpublished, 'metadata.xml'))).to eq former
      expect(File.exist?(former)).to be false
      expect(File.exist?(address)).to be false
    end

    it 'puts a format of a published recording where it is published, and links it' do
      recording.update!(published: true)
      store(former)

      expect(directories.adopt(former, 'presentation')).to eq [:moved, [former, tenant_published]]
      expect(File.readlink(address)).to eq tenant_published
      expect(served).to eq former
    end

    it 'leaves both alone when the format is somewhere Scalelite looks already, and says where' do
      store(former)
      store(shared_unpublished)

      expect(directories.adopt(former, 'presentation')).to eq [:scattered, [former, shared_unpublished]]
      expect(File.directory?(former)).to be true
      expect(File.directory?(shared_unpublished)).to be true
    end

    it 'has nothing to do with a format that is where Scalelite looks for it anyway' do
      store(shared_unpublished)

      expect(directories.adopt(shared_unpublished, 'presentation')).to eq [:in_place, [shared_unpublished]]
      expect(File.directory?(shared_unpublished)).to be true
    end

    it 'touches nothing when the directory of the tenant is not there' do
      store(former)
      FileUtils.rm_rf(own_dir)

      expect { directories.adopt(former, 'presentation') }.to raise_error(described_class::Unavailable)
      expect(File.directory?(former)).to be true
      expect(File.exist?(own_dir)).to be false
    end

    context 'with a tenant that was not given a directory' do
      let(:tenant) { create(:tenant, name: 'tenant1') }

      it 'moves the format to where all recordings are kept' do
        store(former)

        expect(directories.adopt(former, 'presentation')).to eq [:moved, [former, shared_unpublished]]
      end
    end

    context 'with RECORDING_DIR_PER_TENANT off' do
      let(:per_tenant) { false }

      it 'moves the format to where all recordings are kept' do
        store(former)

        expect(directories.adopt(former, 'presentation')).to eq [:moved, [former, shared_unpublished]]
      end
    end
  end

  describe '#delete' do
    it 'removes every format from every place it is in, and the links to it' do
      directories.import(store(File.join(base, 'work')), 'presentation', published: true)
      video = store(File.join(own_dir, 'unpublished', 'video', record_id))
      shared = store(File.join(publish_dir, 'podcast', record_id))
      named = store(File.join(unpublish_dir, 'tenant1', 'notes', record_id))

      directories.delete

      expect([tenant_published, video, shared, named].select { |dir| File.exist?(dir) }).to be_empty
      expect(File.symlink?(address)).to be false
    end

    it 'removes a link whose files are gone' do
      link_address(tenant_published)

      directories.delete

      expect(File.symlink?(address)).to be false
    end

    it 'removes a link that leads somewhere else, and leaves what it leads to alone' do
      elsewhere = store(File.join(base, 'elsewhere'))
      link_address(elsewhere)

      directories.delete

      expect(File.symlink?(address)).to be false
      expect(File.directory?(elsewhere)).to be true
    end

    it 'removes nothing for a record ID that is a glob pattern' do
      other = store(File.join(publish_dir, 'presentation', 'another-record-id'))
      recording.update!(record_id: '*')

      described_class.new(recording).delete

      expect(File.directory?(other)).to be true
    end

    it 'leaves the other recordings of the tenant alone' do
      other = store(File.join(own_dir, 'published', 'presentation', 'another-record-id'))
      store(tenant_published)

      directories.delete

      expect(File.directory?(other)).to be true
      expect(File.directory?(tenant_published)).to be false
    end
  end

  describe '#copies' do
    it 'lists a directory once, however many links lead to it' do
      directories.import(store(File.join(base, 'work')), 'presentation', published: true)

      expect(directories.copies('presentation')).to eq [tenant_published]
    end

    it 'does not go through the other directories while the files are where they are expected' do
      store(tenant_published)
      store(named_published)

      expect(directories.copies('presentation')).to eq [tenant_published]
      expect(directories.copies('presentation', everywhere: true)).to eq [tenant_published, named_published]
    end
  end
end
