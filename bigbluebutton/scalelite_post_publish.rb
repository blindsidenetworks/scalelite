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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

require 'optparse'
require 'psych'
require 'fileutils'
require File.expand_path('../../lib/recordandplayback', __dir__)

puts('Recording transferring to Scalelite starts')

meeting_id = nil
format = nil
OptionParser.new do |opts|
  opts.on('-m', '--meeting-id MEETING_ID', 'Internal Meeting ID') do |v|
    meeting_id = v
  end
  opts.on('-f', '--format FORMAT', 'Recording Format') do |v|
    format = v
  end
end.parse!

unless meeting_id
  msg = 'Meeting ID was not provided'
  puts(msg) && raise(msg)
end

unless format
  msg = 'Recording format was not provided'
  puts(msg) && raise(msg)
end

props = Psych.load_file(File.join(__dir__, '../bigbluebutton.yml'))
published_dir = props['published_dir'] || raise('Unable to determine published_dir from bigbluebutton.yml')
recording_dir = props['recording_dir'] || raise('Unable to determine recording_dir from bigbluebutton.yml')

scalelite_props = Psych.load_file(File.join(__dir__, '../scalelite.yml'))
work_dir = scalelite_props['work_dir'] || raise('Unable to determine work_dir from scalelite.yml')
spool_dir = scalelite_props['spool_dir'] || raise('Unable to determine spool_dir from scalelite.yml')
extra_rsync_opts = scalelite_props['extra_rsync_opts'] || []
delete_recording = scalelite_props['delete_recording']
wait_for_all_formats = scalelite_props['wait_for_all_formats']

if wait_for_all_formats
  publish_scripts_dir = File.expand_path('../publish', __dir__)
  active_formats = Dir.glob("#{publish_scripts_dir}/*.rb").map { |f| File.basename(f, '.rb') }

  if active_formats.empty?
    puts('Warning: No publish format scripts found in publish directory, proceeding with transfer')
  else
    puts("Active recording formats: #{active_formats.join(', ')}")
    pending_formats = active_formats.reject do |fmt|
      File.exist?("#{recording_dir}/status/published/#{meeting_id}-#{fmt}.done")
    end

    unless pending_formats.empty?
      puts("Formats not yet published: #{pending_formats.join(', ')}")
      puts("Skipping transfer - waiting for all formats to finish (triggered by format: #{format})")
      exit
    end

    puts('All recording formats are published, proceeding with transfer')
  end

  puts("Transferring recording for #{meeting_id} to Scalelite")
  tar_dirs = []
  FileUtils.cd(published_dir) do
    tar_dirs = Dir.glob("*/#{meeting_id}")
  end
  if tar_dirs.empty?
    puts('No published recording formats found')
    exit
  end
  tar_dirs.each do |fmt_dir|
    puts("Found recording format: #{fmt_dir}")
  end

  archive_file = "#{work_dir}/#{meeting_id}.tar"
else
  puts("Transferring recording for #{meeting_id} (format: #{format}) to Scalelite")
  format_dir = "#{format}/#{meeting_id}"
  unless File.directory?("#{published_dir}/#{format_dir}")
    puts("No published recording found at #{published_dir}/#{format_dir}")
    exit
  end

  tar_dirs = [format_dir]
  archive_file = "#{work_dir}/#{meeting_id}-#{format}.tar"
end

begin
  puts('Creating recording archive')
  FileUtils.mkdir_p(work_dir)
  FileUtils.cd(published_dir) do
    system('tar', '--create', '--file', archive_file, *tar_dirs) \
      || raise('Failed to create recording archive')
  end

  puts("Transferring recording archive to #{spool_dir}")
  system('rsync', '--verbose', '--remove-source-files', '--protect-args', *extra_rsync_opts, archive_file, spool_dir) \
    || raise('Failed to transfer recording archive')

  # Delete recording after transfer
  if delete_recording
    puts('Deleting local recording')
    system('bbb-record', '--delete', meeting_id) || raise('Failed to delete local recording')
  end

  puts('Create sender.done file')
  File.write("#{recording_dir}/status/published/#{meeting_id}-sender.done", "Published #{meeting_id}")

  puts('Recording transferring to Scalelite ends')
end
