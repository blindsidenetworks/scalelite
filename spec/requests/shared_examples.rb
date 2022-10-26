RSpec.shared_examples 'returns unsupportedRequestError' do
  let(:response_xml) { Nokogiri::XML(response.body) }

  it 'returns success response code' do
    expect(response.status).to eq 200
  end

  it 'returns FAILED in xml return code' do
    expect( response_xml.at_xpath('/response/returncode').text ).to eq 'FAILED'
  end

  it 'returns proper messageKey' do
    expect( response_xml.at_xpath('/response/messageKey').text ).to eq 'unsupportedRequest'
  end

  it 'returns proper message' do
    expect( response_xml.at_xpath('/response/message').text ).to eq 'This request is not supported.'
  end
end

RSpec.shared_examples 'returns success XML response' do
  let(:response_xml) { Nokogiri::XML(response.body) }

  it 'returns correct return code' do
    expect(response_xml.at_xpath('/response/returncode').text ).to eq 'SUCCESS'
  end

  it 'returns correct version' do
    expect( response_xml.at_xpath('/response/version').text ).to eq '2.0'
  end
end
