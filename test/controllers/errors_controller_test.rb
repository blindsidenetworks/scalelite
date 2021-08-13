# frozen_string_literal: true

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test 'returns unsupportedRequestError if request url is root' do
    get root_url

    assert_response :success
  end

  test 'returns unsupportedRequestError if the url is invalid' do
    get '/unsupportedRequest'

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal 'unsupportedRequest', response_xml.at_xpath('/response/messageKey').text
    assert_equal 'This request is not supported.', response_xml.at_xpath('/response/message').text

    assert_response :success
  end

  test 'returns unsupportedRequestError for unknown BBB api commands' do
    get '/bigbluebutton/api/unsupportedRequest'

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal 'unsupportedRequest', response_xml.at_xpath('/response/messageKey').text
    assert_equal 'This request is not supported.', response_xml.at_xpath('/response/message').text

    assert_response :success
  end
end
