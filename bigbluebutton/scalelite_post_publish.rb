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

logger = Logger.new('/var/log/bigbluebutton/post_publish.log', 'weekly')
logger.level = Logger::INFO
BigBlueButton.logger = logger

BigBlueButton.logger.info('Recording transferring to Scalelite starts')

meeting_id = nil
OptionParser.new do |opts|
  opts.on('-m', '--meeting-id MEETING_ID', 'Internal Meeting ID') do |v|
    meeting_id = v
  end
  opts.on('-f', '--format FORMAT', 'Recording Format') do |v|
  end
end.parse!

unless meeting_id
  msg = 'Meeting ID was not provided'
  BigBlueButton.logger.info(msg) && raise(msg)
end

props = Psych.load_file(File.join(__dir__, '../bigbluebutton.yml'))
published_dir = props['published_dir'] || raise('Unable to determine published_dir from bigbluebutton.yml')
scalelite_props = Psych.load_file(File.join(__dir__, '../scalelite.yml'))
work_dir = scalelite_props['work_dir'] || raise('Unable to determine work_dir from scalelite.yml')
spool_dir = scalelite_props['spool_dir'] || raise('Unable to determine spool_dir from scalelite.yml')
extra_rsync_opts = scalelite_props['extra_rsync_opts'] || []

BigBlueButton.logger.info("Transferring recording for #{meeting_id} to Scalelite")
format_dirs = []
FileUtils.cd(published_dir) do
  format_dirs = Dir.glob("*/#{meeting_id}")
end
if format_dirs.empty?
  BigBlueButton.logger.info('No published recording formats found')
  exit
end

format_dirs.each do |format_dir|
  BigBlueButton.logger.info("Found recording format: #{format_dir}")
end

archive_file = "#{work_dir}/#{meeting_id}.tar"
begin
  BigBlueButton.logger.info('Creating recording archive')
  FileUtils.mkdir_p(work_dir)
  FileUtils.cd(published_dir) do
    system('tar', '--create', '--file', archive_file, *format_dirs) \
      || raise('Failed to create recording archive')
  end

  BigBlueButton.logger.info("Transferring recording archive to #{spool_dir}")
  system('rsync', '--verbose', '--protect-args', *extra_rsync_opts, archive_file, spool_dir) \
    || raise('Failed to transfer recording archive')

  BigBlueButton.logger.info('Recording transferring to Scalelite ends')
ensure
  FileUtils.rm_f(archive_file)
end
