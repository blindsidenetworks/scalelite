# frozen_string_literal: true

class AddAllTaskTest < ActiveSupport::TestCase
  require 'rake'
  require 'test_helper'

  test 'adds all servers from yml file' do
    server_count = Server.all.size
    STDOUT.stub(:puts, '.') do
      Rake::Task['servers:addAll'].invoke('./test/fixtures/files/servers.yml')
      assert_equal Server.all.size, server_count + 3
    end
  end
end
