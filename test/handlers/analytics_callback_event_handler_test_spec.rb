RSpec.describe(AnalyticsCallbackEventHandler, :type => :model) do
  require("rails_helper")
  
  it("creates record in CallbackData") do
    params = { "meta_analytics-callback-url" => "https://test-1.example.com/" }
    EventHandler.new(params, "test-123").handle
    callbackdata = CallbackData.find_by(:meeting_id => "test-123")
    expect("https://test-1.example.com/").to(eq(callbackdata.callback_attributes[:analytics_callback_url]))
  end

  it("does not create record in CallbackData if meta_analytics-callback-url is nil") do
    params = { "meta_analytics-callback-url" => nil }
    EventHandler.new(params, "test-123").handle
    callbackdata = CallbackData.find_by(:meeting_id => "test-123")
    expect(callbackdata).to(be_nil)
  end
end