RSpec.describe(RecordingReadyEventHandler) do
  require("spec_helper")
  it("creates record in CallbackData") do
    params = { "meta_bn-recording-ready-url" => "https://test-1.example.com/" }
    EventHandler.new(params, "test-123").handle
    callbackdata = CallbackData.find_by(:meeting_id => "test-123")
    expect("https://test-1.example.com/").to(eq(callbackdata.callback_attributes[:recording_ready_url]))
  end
  it("does not create record in CallbackData if meta_bn-recording-ready-url is nil") do
    params = { "meta_bn-recording-ready-url" => nil }
    EventHandler.new(params, "test-123").handle
    callbackdata = CallbackData.find_by(:meeting_id => "test-123")
    expect(callbackdata).to(be_nil)
  end
  it("returns params after removing meta_bn-recording-ready-url") do
    params = { "meta_bn-recording-ready-url" => "https://test-1.example.com/" }
    new_params = EventHandler.new(params, "test-1234").handle
    expect({}).to(eq(new_params))
  end
end