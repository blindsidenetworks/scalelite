require("rake")
require("rails_helper")
RSpec.describe(AddAllTask, :type => :model) do
  Rails.application.load_tasks
  it("adds all servers from yml file") do
    $stdout.stub(:puts, ".") do
      server_count = Server.all.size
      Rails.configuration.x.stub(:server_id_is_hostname, true) do
        Rake::Task["servers:addAll"].invoke("./test/fixtures/files/servers.yml")
      end
      expect((server_count + 3)).to(eq(Server.all.size))
    end
  end
end
