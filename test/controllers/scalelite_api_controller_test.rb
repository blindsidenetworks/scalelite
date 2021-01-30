# frozen_string_literal: true

class BigBlueButtonApiControllerTest < ActionDispatch::IntegrationTest
  include ApplicationErrors
  include ApiHelper

  test 'responds with only success and version' do
    Rails.configuration.x.build_number = nil

    ScaleliteApiController.stub_any_instance(:verify_checksum, nil) do
      get scalelite_api_url
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal '2.0', response_xml.at_xpath('/response/version').text
    assert_not response_xml.at_xpath('/response/build').present?

    assert_response :success
  end

  test 'includes build in response if env variable is set' do
    Rails.configuration.x.build_number = 'alpha-1'

    ScaleliteApiController.stub_any_instance(:verify_checksum, nil) do
      get scalelite_api_url
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal '2.0', response_xml.at_xpath('/response/version').text
    assert_equal 'alpha-1', response_xml.at_xpath('/response/build').text

    assert_response :success
  end


  test 'responds with the correct server info' do
    url = 'https://server-1.example.com/bigbluebutton/api/' 
    secret = 'super-secret'

    url = 'http://localhost:3000/scalelite/api/addServer?checksum=0fed46b75fa8b6b7286174afd76884e58ef43f03&loadMultiplier&serverSecret=super-secret&serverURL=https://server-1.example.com/bigbluebutton/api/'

    stub_request(:get, url)
      .to_return(status: [200, ""])
  end
end
