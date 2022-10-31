require("rails_helper")
class PlaybackControllerTest < ActionDispatch::IntegrationTest
  it("should get playback") do
    recording = create(:recording)

    get("/playback/presentation/2.0/#{recording.record_id}")
    
    assert_response(:success)
  end
  
  it("playback resource can serve js files") do
    recording = create(:recording, :published, :state => "published")
    playback_format = create(
      :playback_format, 
      :recording => recording, 
      :format => "capture", 
      :url => ("/capture/#{recording.record_id}/")
    )
    
    get("#{playback_format.url}capture.js")
    
    assert_response(:success)
    
    expect(@response.get_header("X-Accel-Redirect")).to(eq("/static-resource#{playback_format.url}capture.js"))
  end
  
  it("renders a 404 page if the recording url is invalid") do
    get("/recording/invalid_recording_id/invalid_format")
    assert_response(:not_found)
    assert_template("errors/recording_not_found")
  end

  it("protected recording without cookies blocks resource access if enabled") do
    recording = create(
      :recording, 
      :published, 
      :state => "published", 
      :protected => true
    )
    playback_format = create(
      :playback_format, 
      :recording => recording, 
      :format => "presentation", 
      :url => ("/playback/presentation/index.html?meetingID=#{recording.record_id}")
    )
    get("/#{playback_format.format}/#{recording.record_id}/slides.svg")
    assert_response(:success)
    Rails.configuration.x.protected_recordings_enabled = true
    get("/#{playback_format.format}/#{recording.record_id}/slides.svg")
    assert_response(:not_found)
    assert_not(@response.has_header?("X-Accel-Redirect"))
  end
end
