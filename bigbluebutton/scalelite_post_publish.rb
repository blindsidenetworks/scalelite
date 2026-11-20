#!/usr/bin/ruby
# frozen_string_literal: true

# Scalelite recording transfer script
# Copyright © 2020 Blindside Networks
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

require "optparse"
require "psych"
require "fileutils"
require File.expand_path("../../lib/recordandplayback", __dir__)

puts("Recording transferring to Scalelite starts")

def truthy?(value)
  value == true || value.to_s.casecmp("true").zero?
end

def safe_component(value)
  value.to_s.gsub(/[^0-9A-Za-z_.-]/, "_")
end

# Use BBB's merged recording configuration with a compatibility fallback.
def effective_bbb_properties
  if BigBlueButton.respond_to?(:read_props)
    props = BigBlueButton.read_props
    return props if props.is_a?(Hash)
  end

  base_file = File.expand_path("../bigbluebutton.yml", __dir__)
  props = Psych.load_file(base_file) || {}

  override_file = "/etc/bigbluebutton/recording/recording.yml"
  if File.file?(override_file)
    override = Psych.load_file(override_file) || {}
    props = props.merge(override)
  end

  props
end

# Follow BaseWorker#schedule_next_step, including generic step fallback and
# filtering disabled formats before traversing their downstream steps.
def workflow_publish_formats(steps, disabled_formats = [])
  return [] unless steps.is_a?(Hash)

  disabled_formats = disabled_formats.map { |format| format.to_s.downcase }
  queue = ["archive"]
  visited = {}
  formats = []

  until queue.empty?
    step = queue.shift.to_s
    next if visited[step]

    visited[step] = true

    match = /\Apublish:([^:]+)\z/.match(step)
    formats << match[1].strip.downcase if match

    step_name = step.split(":", 2).first
    next_steps = steps[step] || steps[step.to_sym]
    next_steps = steps[step_name] || steps[step_name.to_sym] if next_steps.nil?

    Array(next_steps).compact.each do |next_step|
      next_step = next_step.to_s.strip
      next if next_step.empty?

      _next_name, next_format = next_step.split(":", 2)
      next if next_format && disabled_formats.include?(next_format.downcase)

      queue << next_step
    end
  end

  formats.uniq.sort
end

def publish_script_exists?(format)
  scripts_path = if BigBlueButton.respond_to?(:rap_scripts_path)
      BigBlueButton.rap_scripts_path
    else
      File.expand_path("..", __dir__)
    end

  File.file?(File.join(scripts_path, "publish", "#{format}.rb"))
end

# Metadata failures retain all formats, preventing early deletion.
def meeting_disabled_formats(recording_dir, meeting_id)
  events_xml = File.join(
    recording_dir,
    "raw",
    meeting_id,
    "events.xml"
  )

  return [] unless File.file?(events_xml)
  return [] unless defined?(BigBlueButton::Events)
  return [] unless BigBlueButton::Events.respond_to?(:get_meeting_metadata)

  metadata =
    BigBlueButton::Events.get_meeting_metadata(events_xml)

  value =
    metadata["bbb-disable-recording-formats"]

  raw_value = if value.nil?
      ""
    elsif value.respond_to?(:value)
      value.value.to_s
    else
      value.to_s
    end

  raw_value
    .delete("[]")
    .split(",")
    .map { |format| format.strip.downcase }
    .reject(&:empty?)
    .uniq
rescue StandardError => e
  puts(
    "WARNING: Failed to read bbb-disable-recording-formats metadata: " \
    "#{e.message}"
  )

  []
end

def status_path(recording_dir, stage, meeting_id, format, suffix)
  File.join(
    recording_dir,
    "status",
    stage,
    "#{meeting_id}-#{format}.#{suffix}"
  )
end

def completed_format?(recording_dir, meeting_id, format)
  File.file?(
    status_path(
      recording_dir,
      "published",
      meeting_id,
      format,
      "done"
    )
  )
end

def failed_format?(recording_dir, meeting_id, format)
  %w[published processed].any? do |stage|
    File.file?(status_path(recording_dir, stage, meeting_id, format, "fail"))
  end
end

def published_dirs_for_meeting(published_dir, meeting_id)
  dirs = []

  FileUtils.cd(published_dir) do
    dirs =
      Dir.glob("*/#{meeting_id}")
         .select { |path| File.directory?(path) }
  end

  dirs.sort
end

def validate_archive_dirs!(published_dir, dirs)
  dirs.each do |dir|
    metadata =
      File.join(
        published_dir,
        dir,
        "metadata.xml"
      )

    unless File.file?(metadata)
      raise(
        "Published recording format is missing metadata.xml: #{dir}"
      )
    end
  end
end

# --remove-source-files preserves failed archives for retry and diagnosis.
def transfer_archive!(
  published_dir:,
  archive_file:,
  archive_dirs:,
  spool_dir:,
  extra_rsync_opts:
)
  validate_archive_dirs!(
    published_dir,
    archive_dirs
  )

  FileUtils.mkdir_p(
    File.dirname(archive_file)
  )

  FileUtils.rm_f(archive_file)

  puts(
    "Creating recording archive containing: #{archive_dirs.join(", ")}"
  )

  FileUtils.cd(published_dir) do
    system(
      "tar",
      "--create",
      "--file",
      archive_file,
          *archive_dirs
    ) || raise("Failed to create recording archive")
  end

  puts(
    "Transferring recording archive to #{spool_dir}"
  )

  system(
    "rsync",
    "--verbose",
    "--remove-source-files",
    "--protect-args",
      *extra_rsync_opts,
      archive_file,
    spool_dir
  ) || raise("Failed to transfer recording archive")

  puts("Recording archive transferred successfully")
end

def write_marker(path, contents)
  directory = File.dirname(path)
  FileUtils.mkdir_p(directory)
  temporary_path = File.join(directory, ".#{File.basename(path)}.#{Process.pid}.tmp")

  File.open(temporary_path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.write(contents)
    file.flush
    file.fsync
  end

  File.rename(temporary_path, path)
  File.open(directory, File::RDONLY) do |directory_file|
    directory_file.fsync
  end
ensure
  FileUtils.rm_f(temporary_path) if defined?(temporary_path)
end

# Legacy sender.done can represent one format, so require this marker signature.
def complete_sender_marker?(path)
  return false unless File.file?(path)

  File.read(path).include?(
    "Scalelite-Transfer-Complete: true"
  )
rescue StandardError
  false
end

def write_complete_sender_marker(path, meeting_id, formats = [])
  lines = [
    "Published #{meeting_id}",
    "Scalelite-Transfer-Complete: true",
  ]

  unless formats.empty?
    lines << "Formats: #{formats.join(", ")}"
  end

  write_marker(
    path,
    "#{lines.join("\n")}\n"
  )
end

def write_transfer_marker(path, required_formats, archive_dirs)
  archive_formats = archive_dirs.map { |dir| dir.split("/", 2).first }.uniq.sort
  contents = [
    "Scalelite-Transfer-Complete: true",
    "Required-Formats: #{required_formats.sort.join(", ")}",
    "Archive-Formats: #{archive_formats.join(", ")}",
  ]
  write_marker(path, "#{contents.join("\n")}\n")
end

def marker_field(path, field)
  line = File.foreach(path).find { |item| item.start_with?("#{field}: ") }
  line&.delete_prefix("#{field}: ")&.strip
end

meeting_id = nil
format = nil

OptionParser.new do |opts|
  opts.on(
    "-m",
    "--meeting-id MEETING_ID",
    "Internal Meeting ID"
  ) do |value|
    meeting_id = value
  end

  opts.on(
    "-f",
    "--format FORMAT",
    "Recording Format"
  ) do |value|
    format = value.to_s.strip.downcase
  end
end.parse!

unless meeting_id
  message = "Meeting ID was not provided"
  puts(message)
  raise(message)
end

unless meeting_id.match?(/\A[0-9A-Za-z_.-]+\z/) && ![".", ".."].include?(meeting_id)
  raise("Meeting ID contains invalid characters")
end

#
# BigBlueButton configuration
#
props = effective_bbb_properties

published_dir =
  props["published_dir"] ||
  raise(
    "Unable to determine published_dir from BigBlueButton configuration"
  )

recording_dir =
  props["recording_dir"] ||
  raise(
    "Unable to determine recording_dir from BigBlueButton configuration"
  )

#
# Scalelite transfer configuration
#
scalelite_props =
  Psych.load_file(
    File.expand_path(
      "../scalelite.yml",
      __dir__
    )
  ) || {}

work_dir =
  scalelite_props["work_dir"] ||
  raise(
    "Unable to determine work_dir from scalelite.yml"
  )

spool_dir =
  scalelite_props["spool_dir"] ||
  raise(
    "Unable to determine spool_dir from scalelite.yml"
  )

extra_rsync_opts =
  scalelite_props["extra_rsync_opts"] || []

delete_recording =
  truthy?(
    scalelite_props["delete_recording"]
  )

#
FileUtils.mkdir_p(work_dir)

status_dir =
  File.join(
    recording_dir,
    "status",
    "published"
  )

sender_done =
  File.join(
    status_dir,
    "#{meeting_id}-sender.done"
  )

# Persists transfer state across retries.
state_root =
  File.join(
    work_dir,
    ".transfer-status",
    safe_component(meeting_id)
  )

# Different formats can finish publishing concurrently.
lock_dir =
  File.join(
    work_dir,
    ".locks"
  )

lock_file =
  File.join(
    lock_dir,
    "#{safe_component(meeting_id)}.lock"
  )

# Keep lock paths: unlinking an active flock inode permits a locking race.
FileUtils.mkdir_p(lock_dir)

manual_or_batch_mode =
  format.nil? || format.empty?

File.open(
  lock_file,
  File::RDWR | File::CREAT,
  0o600
) do |lock|
  lock.flock(
    File::LOCK_EX
  )

  if complete_sender_marker?(sender_done)
    FileUtils.rm_rf(state_root)
    puts("Recording #{meeting_id} has already been completely transferred")
    exit(0)
  end

  combined_marker = File.join(state_root, "combined.done")
  if File.file?(combined_marker)
    checkpoint_formats = marker_field(combined_marker, "Required-Formats")&.split(", ") || []
    if checkpoint_formats.empty?
      raise("Combined transfer checkpoint is missing required formats")
    end

    system("bbb-record", "--delete", meeting_id) || raise("Failed to delete local recording") if delete_recording
    write_complete_sender_marker(sender_done, meeting_id, checkpoint_formats)
    FileUtils.rm_rf(state_root)
    exit(0)
  end

  if manual_or_batch_mode && !delete_recording
    archive_dirs = published_dirs_for_meeting(published_dir, meeting_id)
    if archive_dirs.empty?
      puts("No published recording formats found")
      exit(0)
    end

    transfer_archive!(
      published_dir: published_dir,
      archive_file: File.join(work_dir, "#{meeting_id}.tar"),
      archive_dirs: archive_dirs,
      spool_dir: spool_dir,
      extra_rsync_opts: extra_rsync_opts,
    )
    write_complete_sender_marker(
      sender_done,
      meeting_id,
      archive_dirs.map { |dir| dir.split("/", 2).first }.uniq.sort
    )
    puts("Recording transferring to Scalelite ends")
    exit(0)
  end

  disabled_formats = meeting_disabled_formats(recording_dir, meeting_id)
  required_formats = workflow_publish_formats(props["steps"], disabled_formats)
  if required_formats.empty?
    raise("Unable to determine required recording formats from the effective BigBlueButton workflow")
  end

  if delete_recording
    missing_scripts = required_formats.reject { |item| publish_script_exists?(item) }
    unless missing_scripts.empty?
      raise("Publish scripts are missing for required formats: #{missing_scripts.join(", ")}")
    end
  end

  unless manual_or_batch_mode || required_formats.include?(format)
    puts("Recording format #{format} is disabled or not part of the recording workflow")
    exit(0)
  end

  if delete_recording
    failed_formats = required_formats.select { |item| failed_format?(recording_dir, meeting_id, item) }
    unless failed_formats.empty?
      raise("Recording format publishing failed for: #{failed_formats.join(", ")}")
    end

    pending_formats = required_formats.reject { |item| completed_format?(recording_dir, meeting_id, item) }
    unless pending_formats.empty?
      puts("Formats not yet published: #{pending_formats.join(", ")}")
      exit(0)
    end

    archive_dirs = required_formats.filter_map do |item|
      dir = "#{item}/#{meeting_id}"
      if File.directory?(File.join(published_dir, dir))
        dir
      else
        puts("Recording format #{item} completed without published output")
      end
    end

    if archive_dirs.empty?
      puts(
        "All required formats completed, but no published output exists; " \
        "refusing to delete the local recording"
      )
      exit(0)
    end

    transfer_archive!(
      published_dir: published_dir,
      archive_file: File.join(work_dir, "#{meeting_id}.tar"),
      archive_dirs: archive_dirs,
      spool_dir: spool_dir,
      extra_rsync_opts: extra_rsync_opts,
    )
    write_transfer_marker(combined_marker, required_formats, archive_dirs)
    system("bbb-record", "--delete", meeting_id) || raise("Failed to delete local recording")
    write_complete_sender_marker(sender_done, meeting_id, required_formats)
    FileUtils.rm_rf(state_root)
    puts("Recording transferring to Scalelite ends")
    exit(0)
  end

  format_marker = File.join(state_root, "#{safe_component(format)}.done")
  if File.file?(format_marker)
    puts("Recording format #{format} was already transferred; skipping")
  else
    if failed_format?(recording_dir, meeting_id, format)
      raise("Recording format publishing failed: #{format}")
    end
    unless completed_format?(recording_dir, meeting_id, format)
      raise("Recording format has not completed publishing: #{format}")
    end

    format_dir = "#{format}/#{meeting_id}"
    if File.directory?(File.join(published_dir, format_dir))
      transfer_archive!(
        published_dir: published_dir,
        archive_file: File.join(work_dir, "#{meeting_id}-#{safe_component(format)}.tar"),
        archive_dirs: [format_dir],
        spool_dir: spool_dir,
        extra_rsync_opts: extra_rsync_opts,
      )
    else
      puts("Recording format #{format} completed without published output")
    end

    write_marker(format_marker, "Transferred #{meeting_id} format #{format}\n")
  end

  missing_transfers = required_formats.reject do |item|
    File.file?(File.join(state_root, "#{safe_component(item)}.done"))
  end
  if missing_transfers.empty?
    write_complete_sender_marker(sender_done, meeting_id, required_formats)
    FileUtils.rm_rf(state_root)
  end

  puts("Recording transferring to Scalelite ends")
end
