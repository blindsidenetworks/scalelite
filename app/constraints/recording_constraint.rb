# frozen_string_literal: true

class RecordingConstraint
  def self.matches?(request)
    /Recordings/ =~ request.path
  end
end
