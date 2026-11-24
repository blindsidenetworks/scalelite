# frozen_string_literal: true

# Where the files of a recording are kept on disk, and the moves between those places. See
# docs/recording-directories.md.
#
# Upstream keeps every recording in one place: a published format in +RECORDING_PUBLISH_DIR/<format>/<record id>+,
# an unpublished one in the same path below +RECORDING_UNPUBLISH_DIR+. With +RECORDING_DIR_PER_TENANT+ a tenant
# can be given a directory of its own with +rake tenants:recording_dir+, which then holds a +published+ and an
# +unpublished+ directory for its recordings. Nothing moves by itself: the recordings of a tenant that was not
# given a directory, and the ones without a tenant, stay where upstream keeps them, setting or no setting.
#
# The web server, the playback URLs and the scripts that walk the publish directory all know a published
# recording by the path upstream gave it, called its address here. That address is kept: for a format whose
# files are in the directory of a tenant it is a symbolic link to them. Nothing that reads recordings has to
# learn about tenants that way, and a recording keeps playing when the directory of its tenant is changed and
# when the setting is switched off again.
#
# Where a recording belongs follows from the settings of the moment; where it is can be a place it belonged
# in before. So the files are always looked for, in every place Scalelite may have put them, and never assumed
# to be where the settings point today.
class RecordingDirectoryService
  # The format has no files in any place it is looked for.
  class NotFound < StandardError; end

  # The directory the files belong in cannot be used right now, which a mount or a restart puts right. Raised
  # instead of whatever the file system said, so that the importer can tell it from a broken recording and
  # keep the tar for another try.
  class Unavailable < StandardError; end

  LOOK_UP = Object.new.freeze
  private_constant :LOOK_UP

  class << self
    # @return [Boolean] whether the directory a tenant was given is used for its recordings.
    def enabled?
      Rails.configuration.x.recording_dir_per_tenant
    end

    # @return [Array(String, String)] where upstream keeps published and unpublished recordings, and where
    #   every recording stays that does not belong to a tenant with a directory of its own.
    def shared_roots
      [Rails.configuration.x.recording_publish_dir, Rails.configuration.x.recording_unpublish_dir]
    end

    # The two directories inside the one an operator gave a tenant, whether or not it is in use right now.
    #
    # @param [Tenant, nil] tenant
    # @return [Array(String, String), nil] where its published and its unpublished recordings go; nil for no
    #   tenant and for one that was not given a directory.
    def tenant_roots(tenant)
      dir = tenant&.recording_dir
      [File.join(dir, 'published'), File.join(dir, 'unpublished')] if dir.present?
    end

    # @param [Tenant, nil] tenant
    # @return [Array(String, String)] where the published and the unpublished recordings of the tenant belong
    #   under the settings of the moment.
    def roots(tenant)
      (tenant_roots(tenant) if enabled?) || shared_roots
    end
  end

  # @param [Recording] recording
  # @param [Tenant, nil] tenant the tenant of the recording, where the caller has it at hand. Looked up from
  #   the recording otherwise.
  def initialize(recording, tenant: LOOK_UP)
    @recording = recording
    @tenant = tenant
  end

  # @param [Boolean] published
  # @return [String] the directory the formats of the recording belong in.
  def root(published:)
    @roots ||= self.class.roots(tenant)
    published ? @roots.first : @roots.last
  end

  # @param [String] format
  # @param [Boolean] published
  # @return [String] the directory the files of a format belong in.
  def path(format, published:)
    File.join(root(published: published), format, @recording.record_id)
  end

  # Every directory that holds the files of a format, the one they belong in first. More than one is what a
  # move that failed half way, or a copy made by hand, leaves behind.
  #
  # Whatever else stands in the shared directories is only gone through when the files are in none of the
  # places known for this recording, see {#stray_roots}.
  #
  # @param [String] format a playback format, or '*' for all of them.
  # @param [Boolean] everywhere go through those other directories in any case, for a caller that is about to
  #   remove what it finds.
  # @return [Array<String>] real paths, each directory once however many links lead to it.
  def copies(format = '*', everywhere: false)
    found = existing(known_roots, format)
    found |= existing(stray_roots, format) if everywhere || found.empty?
    found
  end

  # Put the files of a format that was just extracted where they belong, in place of whatever was kept of an
  # earlier import of it.
  #
  # @param [String] source the directory the format was extracted to.
  # @param [String] format
  # @param [Boolean] published
  # @raise [Unavailable] the directory of the tenant cannot be used; nothing was touched.
  def import(source, format, published:)
    available!
    target = path(format, published: published)
    copies(format, everywhere: true).each { |dir| FileUtils.rm_r(dir) }
    move(source, target)
    link(format, published ? target : nil)
  end

  # Move the files of a format to where they belong once the recording is published or unpublished. This is
  # what publishRecordings does, in upstream's order: files that are in place already stay, files that are
  # elsewhere are moved, and a copy left where they were is removed.
  #
  # @param [String] format
  # @param [Boolean] published the state the recording is about to have.
  # @raise [NotFound] the format has no files anywhere.
  # @raise [Unavailable] the directory of the tenant cannot be used; nothing was touched.
  def place(format, published:)
    target = path(format, published: published)
    found = copies(format)
    raise NotFound, 'Recording has no recording files' if found.empty?

    if real_directory?(target)
      kept = File.realpath(target)
    else
      available!
      kept = found.first
      move(kept, target)
    end
    (found - [kept]).each do |dir|
      Rails.logger.info("Recording #{@recording.record_id} has its #{format} files in more than one place. Removing #{dir}")
      FileUtils.rm_r(dir)
    end
    link(format, published ? target : nil)
  end

  # Move the files of a format to where they belong under the settings of the moment, for
  # +rake recordings:relocate+. Unlike {#place} this never removes anything: files that are in more than one
  # place are left for somebody to look at, since nothing here can tell which copy is the good one.
  #
  # @param [String] format
  # @param [Boolean] dry_run report what would be done without doing it.
  # @return [Array(Symbol, Array<String>)] +:moved+ with where from and where to, +:relinked+ or +:in_place+
  #   with where the files are, +:scattered+ with every place they are in, +:missing+ with nothing.
  # @raise [Unavailable] the directory of the tenant cannot be used; nothing was touched.
  def relocate(format, dry_run: false)
    target = path(format, published: @recording.published)
    found = copies(format)
    return [:missing, []] if found.empty?
    return [:scattered, found] if found.size > 1

    moved = !real_directory?(target)
    if moved && !dry_run
      available!
      move(found.first, target)
    end
    relinked = link(format, @recording.published ? target : nil, dry_run: dry_run)

    return [:moved, [found.first, target]] if moved

    [relinked ? :relinked : :in_place, [target]]
  end

  # Move the files of a format out of a directory nothing else looks in, the directory the tenant had before,
  # to where they belong now. For +rake tenants:recording_dir+, which takes that directory away: a published
  # format there is still found through its link, an unpublished one only by this. Like {#relocate} it never
  # removes anything.
  #
  # @param [String] source the directory of the format there.
  # @param [String] format
  # @return [Array(Symbol, Array<String>)] +:moved+ with where from and where to; +:in_place+ with the source
  #   where Scalelite looks for the format anyway; +:scattered+ with the source and every other place the format
  #   is in already, which is left for somebody to look at.
  # @raise [Unavailable] the directory of the tenant cannot be used; nothing was touched.
  def adopt(source, format)
    source = File.realpath(source)
    found = copies(format)
    return [:in_place, [source]] if found.include?(source)
    return [:scattered, [source, *found]] if found.any?

    target = path(format, published: @recording.published)
    available!
    move(source, target)
    link(format, @recording.published ? target : nil)
    [:moved, [source, target]]
  end

  # Remove the files of the recording, in every format and from every place they are in, published or not,
  # together with the links to them.
  def delete
    copies('*', everywhere: true).each { |dir| FileUtils.rm_r(dir) }
    addresses.each { |address| File.unlink(address) if File.symlink?(address) }
  end

  private

  def tenant
    @tenant = @recording.tenant if @tenant.equal?(LOOK_UP)
    @tenant
  end

  # The directories a format directory of this recording is expected in: where it belongs, where upstream
  # keeps it, and the directory of its tenant while that is not in use, which is where it is after the setting
  # was switched off.
  def known_roots
    @known_roots ||= begin
      belonging = [root(published: true), root(published: false)]
      belonging.reverse! unless @recording.published
      (belonging + self.class.shared_roots + Array(self.class.tenant_roots(tenant))).uniq
    end
  end

  # Whatever else stands next to the playback formats in the shared directories, a directory named after a
  # tenant for example. A recording that lies in one of them is not where it belongs, and is still found there
  # to be published, deleted and moved back. Listed afresh every time, since it is the one answer here that
  # somebody else changes.
  def stray_roots
    formats = Rails.configuration.x.recording_playback_formats
    entries = self.class.shared_roots.flat_map do |root|
      Dir.children(root).reject { |entry| formats.include?(entry) }.sort.map { |entry| File.join(root, entry) }
    rescue SystemCallError
      [] # a shared directory that is not there has nothing in it
    end
    entries - known_roots
  end

  # Only a directory that carries the ID of the recording counts, where the path leads to in the end. A link
  # that points anywhere else was not made here, and what it points to is not this recording's to move or
  # remove; neither is whatever an ID that happens to be a glob pattern matches.
  def existing(roots, format)
    roots.flat_map { |root| Dir.glob(File.join(root, format, @recording.record_id)) }
         .select { |dir| File.directory?(dir) }
         .map { |dir| File.realpath(dir) }
         .select { |dir| File.basename(dir) == @recording.record_id }
         .uniq
  end

  # @return [String] the path upstream gave a published format.
  def address(format)
    File.join(self.class.shared_roots.first, format, @recording.record_id)
  end

  # @return [Array<String>] the addresses of this recording that have something at them, a link whose files
  #   are gone included.
  def addresses
    Dir.glob(address('*')).select { |address| File.basename(address) == @recording.record_id }
  end

  # A link to a directory is not the directory: the files are where it points.
  def real_directory?(path)
    File.directory?(path) && !File.symlink?(path)
  end

  # A directory an operator gave a tenant is never created. Where it is missing, the volume behind it is not
  # mounted, and creating it would put the recordings into the container, to be lost with it.
  def available!
    dir = tenant&.recording_dir
    return unless self.class.enabled? && dir.present?
    return if File.directory?(dir) && File.writable?(dir)

    raise Unavailable, "The recording directory #{dir} of tenant #{tenant.id} is not a writable directory here"
  end

  def move(source, target)
    # The address itself, when the files come back to it
    File.unlink(target) if File.symlink?(target)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.mv(source, target)
  end

  # Keep the address of a format pointing at its files: a link where they are published somewhere else, and
  # no link where they are at the address themselves or are not published at all.
  #
  # @param [String, nil] target the directory the published files are in, nil while they are unpublished.
  # @return [Boolean] whether the address had to be changed.
  def link(format, target, dry_run: false)
    address = address(format)
    current = File.readlink(address) if File.symlink?(address)
    wanted = link_target(address, target) if target && target != address
    return false if current == wanted
    return true if dry_run

    File.unlink(address) if current
    if wanted
      FileUtils.mkdir_p(File.dirname(address))
      File.symlink(wanted, address)
    end
    true
  rescue SystemCallError => e
    raise Unavailable, "Recording #{@recording.record_id} could not be linked at #{address}: #{e.message}"
  end

  # Relative inside the publish directory, so that the link holds wherever that directory is mounted: the web
  # server and the host see it under another path than this container does. A directory of its own has to be
  # mounted under the same path everywhere, and is linked to by that path.
  def link_target(address, target)
    return target unless target.start_with?("#{self.class.shared_roots.first}/")

    Pathname.new(target).relative_path_from(Pathname.new(File.dirname(address))).to_s
  end
end
