# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'servers:addAll task' do
  let(:task_name) { 'servers:addAll' }
  let(:servers_yml_path) { './spec/fixtures/files/servers.yml' }

  subject { Rake::Task[task_name] }

  before do
    Rails.application.load_tasks
  end

  after do
    subject.reenable
  end

  it 'adds all servers from yml file' do
    original_stdout = $stdout
    $stdout = StringIO.new

    server_count = Server.all.size

    allow(Rails.configuration.x).to receive(:server_id_is_hostname).and_return(true)

    subject.invoke(servers_yml_path)
    expect(Server.all.size).to eq(server_count + 3)

    $stdout = original_stdout
  end
end
