# frozen_string_literal: true

require 'rake'
require 'test_helper'

class AddAllTaskTest < ActiveSupport::TestCase
  Rails.application.load_tasks

  test 'adds all servers from yml file' do
    $stdout.stub(:puts, '.') do
      server_count = Server.all.size
      Rails.configuration.x.stub(:server_id_is_hostname, true) do
        Rake::Task['servers:addAll'].invoke('./test/fixtures/files/servers.yml')
      end
      assert_equal Server.all.size, server_count + 3
    end
  end
end
