# frozen_string_literal: true

class DownloadFormatImporter
  class DownloadFormatError < StandardError
  end

  def self.run(record_id)
    # add download format to database (if video format present)
    system("/usr/local/bin/register-download-format #{record_id} $BBB_ENV") \
        || raise(DownloadFormatError, "Failed to create download format for recording id: #{record_id}")
  end
end
