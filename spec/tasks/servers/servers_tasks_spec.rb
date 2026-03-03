# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'servers tasks', type: :task do
  let(:servers_yml_path) { './spec/fixtures/files/servers.yml' }

  before do
    Rails.application.load_tasks
  end

  after do
    Rake::Task.clear
  end

  describe 'servers:addAll task' do
    let(:task) { Rake::Task['servers:addAll'] }
    let(:servers_yml_path) { './spec/fixtures/files/servers.yml' }

    it 'adds all servers from yml file' do
      expect {
        task.invoke(servers_yml_path)
      }.to change { Server.all.size }.by(3)
    end
  end

  describe 'servers:sync task' do
    let(:task) { Rake::Task['servers:sync'] }
    let(:servers_yml_path) { './spec/fixtures/files/servers.yml' }
    let(:mode) { 'cordon' }
    let(:dryrun) { false }

    it 'calls ServerSync.sync_file with correct arguments' do
      expect(ServerSync).to receive(:sync_file).with(servers_yml_path, mode, dryrun)
      task.invoke(servers_yml_path, mode, dryrun)
    end
  end

  describe 'servers:yaml task' do
    let(:task) { Rake::Task['servers:yaml'] }
    let(:verbose) { false }

    it 'calls ServerSync.dump with correct argument' do
      expect(ServerSync).to receive(:dump).with(verbose)
      task.invoke(verbose)
    end

    it 'outputs yaml data to stdout' do
      allow(ServerSync).to receive(:dump).with(verbose).and_return([{ url: 'https://example.com', secret: 'secret' }])
      expect { task.invoke(verbose) }.to output(%r{url: https://example.com}).to_stdout
    end
  end
end
