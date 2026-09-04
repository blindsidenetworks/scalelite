# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

class ScalelitePostPublishTest < Minitest::Test
  SCRIPT = File.expand_path("../../bigbluebutton/scalelite_post_publish.rb", __dir__)
  PRUNE_SCRIPT = File.expand_path("../../bigbluebutton/scalelite_prune_recordings", __dir__)

  def setup
    @root = Dir.mktmpdir("scalelite-post-publish")
    @scripts_dir = File.join(@root, "core", "scripts")
    @post_publish_dir = File.join(@scripts_dir, "post_publish")
    @publish_dir = File.join(@scripts_dir, "publish")
    @lib_dir = File.join(@root, "core", "lib")
    @published_dir = File.join(@root, "published")
    @recording_dir = File.join(@root, "recording")
    @work_dir = File.join(@root, "work")
    @spool_dir = File.join(@root, "spool")
    @bin_dir = File.join(@root, "bin")
    @command_log = File.join(@root, "commands.log")
    FileUtils.mkdir_p([@post_publish_dir, @publish_dir, @lib_dir, @published_dir, @recording_dir, @bin_dir])
    FileUtils.cp(SCRIPT, File.join(@post_publish_dir, "scalelite_post_publish.rb"))
    write_recordandplayback
    write_command("tar", <<~SH)
      #!/bin/bash
      set -eu
      printf 'tar %s\n' "$*" >> "$COMMAND_LOG"
      while [ "$#" -gt 0 ]; do
        if [ "$1" = '--file' ]; then touch "$2"; exit 0; fi
        shift
      done
    SH
    write_command("rsync", <<~SH)
      #!/bin/bash
      set -eu
      printf 'rsync %s\n' "$*" >> "$COMMAND_LOG"
      [ "${RSYNC_FAIL:-0}" != 1 ] || exit 1
      for arg in "$@"; do source="$arg"; done
      rm -f "$source"
    SH
    write_command("bbb-record", <<~SH)
      #!/bin/bash
      printf 'bbb-record %s\n' "$*" >> "$COMMAND_LOG"
      [ "${BBB_RECORD_FAIL:-0}" != 1 ] || exit 1
    SH
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_delete_waits_for_every_configured_format
    configure(delete_recording: true, formats: %w[presentation video])
    complete("presentation", output: true)

    run_script("-f", "presentation")
    assert_empty command_log

    complete("video", output: true)
    run_script("-f", "video")

    assert_includes command_log, "presentation/meeting video/meeting"
    assert_includes command_log, "bbb-record --delete meeting"
  end

  def test_disabled_format_does_not_block_cleanup
    configure(delete_recording: true, formats: %w[presentation video])
    FileUtils.mkdir_p(File.join(@recording_dir, "raw", "meeting"))
    File.write(File.join(@recording_dir, "raw", "meeting", "events.xml"), "DISABLE_VIDEO")
    complete("presentation", output: true)

    run_script("-f", "presentation")

    assert_includes command_log, "presentation/meeting"
    refute_includes command_log, "video/meeting"
    assert_includes command_log, "bbb-record --delete meeting"
  end

  def test_disabled_intermediate_format_blocks_its_downstream_publish_step
    steps = {
      "archive" => ["process:foo"],
      "process:foo" => ["publish:bar"],
    }
    configure(delete_recording: true, formats: %w[bar], steps: steps)
    FileUtils.mkdir_p(File.join(@recording_dir, "raw", "meeting"))
    File.write(File.join(@recording_dir, "raw", "meeting", "events.xml"), "DISABLE_FOO")
    complete("bar", output: true)

    run_script("-f", "bar", expect_success: false)

    assert_empty command_log
  end

  def test_workflow_uses_generic_step_fallback
    steps = {
      "archive" => ["process:foo"],
      "process" => ["publish:foo"],
    }
    configure(delete_recording: false, formats: %w[foo], steps: steps)
    complete("foo", output: true)

    run_script("-f", "foo")

    assert_includes command_log, "foo/meeting"
  end

  def test_missing_publish_script_prevents_cleanup
    configure(delete_recording: true, formats: %w[presentation], publish_scripts: [])

    run_script("-f", "presentation", expect_success: false)

    assert_empty command_log
    refute File.exist?(sender_done)
  end

  def test_completed_empty_format_does_not_block_transfer
    configure(delete_recording: true, formats: %w[notes presentation])
    complete("notes", output: false)
    complete("presentation", output: true)

    run_script("-f", "presentation")

    assert_includes command_log, "presentation/meeting"
    refute_includes command_log, "notes/meeting"
    assert_includes command_log, "bbb-record --delete meeting"
  end

  def test_empty_output_does_not_mark_or_delete_recording
    configure(delete_recording: true, formats: %w[notes])
    complete("notes", output: false)

    run_script("-f", "notes")

    assert_empty command_log
    refute File.exist?(sender_done)
  end

  def test_processed_failure_prevents_transfer_and_deletion
    configure(delete_recording: true, formats: %w[presentation])
    complete("presentation", output: true)
    failure_dir = File.join(@recording_dir, "status", "processed")
    FileUtils.mkdir_p(failure_dir)
    File.write(File.join(failure_dir, "meeting-presentation.fail"), "")

    run_script("-f", "presentation", expect_success: false)

    assert_empty command_log
    refute File.exist?(sender_done)
  end

  def test_per_format_mode_transfers_only_callback_format
    configure(delete_recording: false, formats: %w[presentation video])
    complete("presentation", output: true)
    complete("video", output: true)

    run_script("-f", "presentation")
    assert_includes command_log, "presentation/meeting"
    refute_includes command_log, "video/meeting"

    run_script("-f", "video")
    assert_includes command_log, "video/meeting"
    assert_match(/Scalelite-Transfer-Complete: true/, File.read(sender_done))
  end

  def test_per_format_mode_skips_a_repeated_callback
    configure(delete_recording: false, formats: %w[presentation video])
    complete("presentation", output: true)

    run_script("-f", "presentation")
    run_script("-f", "presentation")

    assert_equal 1, command_log.lines.count { |line| line.start_with?("rsync ") }
    refute File.exist?(sender_done)
  end

  def test_per_format_mode_rejects_an_unfinished_manual_transfer
    configure(delete_recording: false, formats: %w[presentation])
    complete("presentation", output: true, status: false)

    run_script("-f", "presentation", expect_success: false)

    assert_empty command_log
    refute File.exist?(sender_done)
  end

  def test_concurrent_post_publish_callbacks_create_one_archive
    configure(delete_recording: true, formats: %w[presentation video])
    complete("presentation", output: true)
    complete("video", output: true)

    threads = %w[presentation video].map { |format| Thread.new { run_script("-f", format) } }
    threads.each(&:value)

    assert_equal 1, command_log.lines.count { |line| line.start_with?("tar ") }
    assert_equal 1, command_log.lines.count { |line| line == "bbb-record --delete meeting\n" }
  end

  def test_batch_waits_for_all_required_formats_before_deletion
    configure(delete_recording: true, formats: %w[presentation video])
    complete("presentation", output: true)

    run_script
    assert_empty command_log

    complete("video", output: true)
    run_script

    assert_includes command_log, "presentation/meeting video/meeting"
    assert_includes command_log, "bbb-record --delete meeting"
    assert_match(/Scalelite-Transfer-Complete: true/, File.read(sender_done))
  end

  def test_combined_checkpoint_recovers_normal_mode_after_source_deletion
    configure(delete_recording: true, formats: %w[presentation])
    write_combined_checkpoint

    run_script("-f", "presentation")

    assert_includes command_log, "bbb-record --delete meeting"
    assert_match(/Scalelite-Transfer-Complete: true/, File.read(sender_done))
  end

  def test_combined_checkpoint_recovers_batch_mode_after_source_deletion
    configure(delete_recording: true, formats: %w[presentation])
    write_combined_checkpoint

    run_script

    assert_includes command_log, "bbb-record --delete meeting"
    assert_match(/Scalelite-Transfer-Complete: true/, File.read(sender_done))
  end

  def test_combined_checkpoint_recovers_without_disabled_format_metadata
    configure(delete_recording: true, formats: %w[presentation video])
    write_combined_checkpoint(required_formats: %w[presentation])

    run_script("-f", "presentation")

    assert_includes command_log, "bbb-record --delete meeting"
    assert_match(/Formats: presentation/, File.read(sender_done))
    refute_match(/video/, File.read(sender_done))
  end

  def test_complete_sender_marker_removes_stale_transfer_state
    configure(delete_recording: true, formats: %w[presentation])
    write_combined_checkpoint
    FileUtils.mkdir_p(File.dirname(sender_done))
    File.write(sender_done, "Published meeting\nScalelite-Transfer-Complete: true\n")

    run_script("-f", "presentation")

    refute File.exist?(File.join(@work_dir, ".transfer-status", "meeting"))
    assert_empty command_log
  end

  def test_retries_cleanup_without_resending_a_transferred_archive
    configure(delete_recording: true, formats: %w[presentation])
    complete("presentation", output: true)
    @bbb_record_fail = true

    run_script("-f", "presentation", expect_success: false)
    refute File.exist?(sender_done)

    @bbb_record_fail = false
    run_script("-f", "presentation")

    assert_equal 1, command_log.lines.count { |line| line.start_with?("rsync ") }
    assert_equal 2, command_log.lines.count { |line| line == "bbb-record --delete meeting\n" }
    assert_match(/Scalelite-Transfer-Complete: true/, File.read(sender_done))
  end

  def test_failed_rsync_keeps_recording_for_retry
    configure(delete_recording: true, formats: %w[presentation])
    complete("presentation", output: true)
    @rsync_fail = true

    run_script("-f", "presentation", expect_success: false)
    refute File.exist?(sender_done)
    refute_includes command_log, "bbb-record --delete meeting"
    assert File.exist?(File.join(@work_dir, "meeting.tar"))

    @rsync_fail = false
    run_script("-f", "presentation")

    assert_equal 2, command_log.lines.count { |line| line.start_with?("rsync ") }
    assert_includes command_log, "bbb-record --delete meeting"
  end

  def test_prune_keeps_raw_without_complete_sender_marker
    events = create_old_raw_recording

    run_prune

    assert File.exist?(events)
    assert_empty command_log
  end

  def test_prune_allows_cleanup_with_complete_sender_marker
    events = create_old_raw_recording
    FileUtils.mkdir_p(File.dirname(sender_done))
    File.write(sender_done, "Published meeting\nScalelite-Transfer-Complete: true\n")
    old_time = Time.now - (6 * 24 * 60 * 60)
    File.utime(old_time, old_time, sender_done)

    run_prune

    refute File.exist?(events)
    assert_includes command_log, "bbb-record --delete meeting"
  end

  private

  def configure(delete_recording:, formats:, steps: nil, publish_scripts: formats)
    steps ||= { "archive" => formats.map { |format| "publish:#{format}" } }
    FileUtils.rm_rf(@publish_dir)
    FileUtils.mkdir_p(@publish_dir)
    publish_scripts.each { |format| File.write(File.join(@publish_dir, "#{format}.rb"), "") }
    File.write(File.join(@scripts_dir, "bigbluebutton.yml"), {
      "published_dir" => @published_dir,
      "recording_dir" => @recording_dir,
      "steps" => steps,
    }.to_yaml)
    File.write(File.join(@scripts_dir, "scalelite.yml"), {
      "work_dir" => @work_dir,
      "spool_dir" => @spool_dir,
      "extra_rsync_opts" => [],
      "delete_recording" => delete_recording,
    }.to_yaml)
  end

  def complete(format, output:, status: true)
    if status
      mark_completed(format)
    end
    return unless output

    output_dir = File.join(@published_dir, format, "meeting")
    FileUtils.mkdir_p(output_dir)
    File.write(File.join(output_dir, "metadata.xml"), "<recording/>")
  end

  def mark_completed(format)
    status_dir = File.join(@recording_dir, "status", "published")
    FileUtils.mkdir_p(status_dir)
    File.write(File.join(status_dir, "meeting-#{format}.done"), "")
  end

  def run_script(*args, expect_success: true)
    stdout, stderr, status = Open3.capture3(environment, "ruby", File.join(@post_publish_dir, "scalelite_post_publish.rb"), "-m", "meeting", *args)
    if expect_success
      assert status.success?, "#{stdout}\n#{stderr}"
    else
      refute status.success?, "#{stdout}\n#{stderr}"
    end
  end

  def environment
    {
      "BBB_PROPS" => File.join(@scripts_dir, "bigbluebutton.yml"),
      "COMMAND_LOG" => @command_log,
      "RSYNC_FAIL" => @rsync_fail ? "1" : "0",
      "BBB_RECORD_FAIL" => @bbb_record_fail ? "1" : "0",
      "PATH" => "#{@bin_dir}:#{ENV.fetch("PATH")}",
    }
  end

  def command_log
    File.exist?(@command_log) ? File.read(@command_log) : ""
  end

  def sender_done
    File.join(@recording_dir, "status", "published", "meeting-sender.done")
  end

  def write_combined_checkpoint(required_formats: %w[presentation])
    checkpoint = File.join(@work_dir, ".transfer-status", "meeting", "combined.done")
    FileUtils.mkdir_p(File.dirname(checkpoint))
    formats = required_formats.join(", ")
    File.write(checkpoint, "Scalelite-Transfer-Complete: true\nRequired-Formats: #{formats}\nArchive-Formats: #{formats}\n")
  end

  def create_old_raw_recording
    events = File.join(@recording_dir, "raw", "meeting", "events.xml")
    FileUtils.mkdir_p(File.dirname(events))
    File.write(events, "<recording/>")
    old_time = Time.now - (6 * 24 * 60 * 60)
    File.utime(old_time, old_time, events)
    events
  end

  def run_prune
    env = environment.merge(
      "RECORDING_DIR" => @recording_dir,
      "LOGFILE" => File.join(@root, "prune.log"),
    )
    stdout, stderr, status = Open3.capture3(env, "bash", PRUNE_SCRIPT)
    assert status.success?, "#{stdout}\n#{stderr}"
  end

  def write_command(name, contents)
    path = File.join(@bin_dir, name)
    File.write(path, contents)
    FileUtils.chmod(0o755, path)
  end

  def write_recordandplayback
    File.write(File.join(@lib_dir, "recordandplayback.rb"), <<~RUBY)
      require 'psych'

      module BigBlueButton
        def self.read_props
          Psych.load_file(ENV.fetch('BBB_PROPS'))
        end

        def self.rap_scripts_path
          File.dirname(ENV.fetch('BBB_PROPS'))
        end

        module Events
          def self.get_meeting_metadata(path)
            return { 'bbb-disable-recording-formats' => 'video' } if File.read(path).include?('DISABLE_VIDEO')
            return { 'bbb-disable-recording-formats' => 'foo' } if File.read(path).include?('DISABLE_FOO')

            {}
          end
        end
      end
    RUBY
  end
end
