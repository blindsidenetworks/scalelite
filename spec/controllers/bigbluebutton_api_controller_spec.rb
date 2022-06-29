# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BigBlueButtonApiController, type: :controller do
  include ApiHelper

  before do
    allow_any_instance_of(described_class).to receive(:verify_checksum).and_return(nil)
  end

  let!(:server) do
    Server.create(url: 'https://test-1.example.com/bigbluebutton/api/',
                  secret: 'test-1-secret', enabled: true, load: 0, online: true)
  end

  context '#join' do
    context 'default and override params' do
      let!(:meeting) do
        Meeting.find_or_create_with_server('test-meeting-1', server, 'mp')
      end

      let(:create_params) do
        {
          meetingID: meeting.id,
          moderatorPW: 'test-password',
          fullName: 'test-name',
          param1: "param1",
        }
      end

      it 'sets the default params if they are not already set' do
        expected_params = {
          meetingID: meeting.id,
          moderatorPW: 'test-password',
          fullName: 'test-name',
          param1: "param1",
          param2: "param2"
        }
        expected_url = encode_bbb_uri('join', server.url, server.secret, expected_params) # Calculate uri before env var is set

        ENV['DEFAULT_JOIN_PARAMS'] = 'param1=not-param1,param2=param2'

        expect_any_instance_of(described_class)
          .to receive(:encode_bbb_uri)
          .with('join', server.url, server.secret, create_params)
          .and_return(expected_url)

        get :join, params: create_params
      end

      it 'overrides the params even if they are set' do
        expected_params = {
          meetingID: meeting.id,
          moderatorPW: 'test-password',
          fullName: 'test-name',
          param1: "not-param1",
          param2: "param2"
        }
        expected_url = encode_bbb_uri('join', server.url, server.secret, expected_params) # Calculate uri before env var is set

        ENV['OVERRIDE_JOIN_PARAMS'] = 'param1=not-param1,param2=param2'

        expect_any_instance_of(described_class)
          .to receive(:encode_bbb_uri)
          .with('join', server.url, server.secret, create_params)
          .and_return(expected_url)

        get :join, params: create_params
      end
    end
  end
end
