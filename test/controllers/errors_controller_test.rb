# frozen_string_literal: true

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test 'returns unsupportedRequestError if request url is root' do
    get root_url

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal 'unsupportedRequest', response_xml.at_xpath('/response/messageKey').text

    assert_response :success
  end

  test 'returns unsupportedRequestError if the url is invalid' do
    get '/unsupportedRequest'

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal 'unsupportedRequest', response_xml.at_xpath('/response/messageKey').text

    assert_response :success
  end

  test 'returns unsupportedRequestError for unknown Scalelite api commands' do
    get '/scalelite/api/unsupportedRequest'

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal 'unsupportedRequest', response_xml.at_xpath('/response/messageKey').text

    assert_response :success
  end
end
