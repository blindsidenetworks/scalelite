# frozen_string_literal: true

require 'rake'
require 'test_helper'

class ServerSyncTest < ActiveSupport::TestCase
  test 'Sync all servers from yml file' do
    ServerSync.sync_file('./test/fixtures/files/servers-sync-a.yml')
    assert_equal 3, Server.all.size

    server = Server.find(:bbb1)
    assert_equal 'bbb1', server.secret
    assert_equal 'https://bbb1/bigbluebutton/api', server.url
    assert server.enabled?
    assert_equal '1.0', server.load_multiplier

    server = Server.find(:bbb2)
    assert_equal 'bbb2', server.secret
    assert_equal 'https://bbb2.example.com/bigbluebutton/api', server.url
    assert_not server.enabled?
    assert_equal '5.0', server.load_multiplier

    server = Server.find(:bbb3)
    assert_equal 'bbb3', server.secret
    assert_equal 'https://bbb3/bigbluebutton/api', server.url
    assert server.enabled?
    assert_equal '1.0', server.load_multiplier

    ServerSync.sync_file('./test/fixtures/files/servers-sync-b.yml')
    assert_equal 2, Server.all.size

    server = Server.find(:bbb1)
    assert_equal 'bbb1-changed', server.secret
    assert_equal 'https://bbb1-changed/bigbluebutton/api', server.url
    assert_not server.enabled?
    assert_equal '23.0', server.load_multiplier

    server = Server.find(:bbb2)
    assert_equal 'bbb2', server.secret
    assert_equal 'https://bbb2.example.com/bigbluebutton/api', server.url
    assert_not server.enabled?
    assert_equal '5.0', server.load_multiplier
  end
end
