class RecordingConstraint
  def self.matches?(request)
    /Recordings/ =~ request.path
  end
end
