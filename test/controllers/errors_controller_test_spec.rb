class ErrorsControllerTest < ActionDispatch::IntegrationTest
  it("returns unsupportedRequestError if request url is root") do
    get(root_url)
    assert_response(:success)
  end

  it("returns unsupportedRequestError if the url is invalid") do
    get("/unsupportedRequest")
    response_xml = Nokogiri.XML(@response.body)
    
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq("unsupportedRequest"))
    expect(response_xml.at_xpath("/response/message").text).to(eq("This request is not supported."))

    assert_response(:success)
  end
  
  it("returns unsupportedRequestError for unknown BBB api commands") do
    get("/bigbluebutton/api/unsupportedRequest")
    response_xml = Nokogiri.XML(@response.body)
    
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq("unsupportedRequest"))
    expect(response_xml.at_xpath("/response/message").text).to(eq("This request is not supported."))
    
    assert_response(:success)
  end
end