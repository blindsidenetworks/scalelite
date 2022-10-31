require("rake")
require("rails_helper")
RSpec.describe(ServerSync, :type => :model) do
  it("Sync all servers from yml file") do
    ServerSync.sync_file("./test/fixtures/files/servers-sync-a.yml")
    expect(Server.all.size).to(eq(3))

    server = Server.find(:bbb1)
    expect(server.secret).to(eq("bbb1"))
    expect(server.url).to(eq("https://bbb1/bigbluebutton/api"))
    expect(server.enabled?).to(eq(true))
    expect(server.load_multiplier).to(eq("1.0"))
    
    server = Server.find(:bbb2)
    expect(server.secret).to(eq("bbb2"))
    expect(server.url).to(eq("https://bbb2.example.com/bigbluebutton/api"))
    assert_not(server.enabled?)
    expect(server.load_multiplier).to(eq("5.0"))
    
    server = Server.find(:bbb3)
    expect(server.secret).to(eq("bbb3"))
    expect(server.url).to(eq("https://bbb3/bigbluebutton/api"))
    expect(server.enabled?).to(eq(true))
    expect(server.load_multiplier).to(eq("1.0"))
    
    ServerSync.sync_file("./test/fixtures/files/servers-sync-b.yml")
    expect(Server.all.size).to(eq(2))
    
    server = Server.find(:bbb1)
    expect(server.secret).to(eq("bbb1-changed"))
    expect(server.url).to(eq("https://bbb1-changed/bigbluebutton/api"))
    assert_not(server.enabled?)
    expect(server.load_multiplier).to(eq("23.0"))
    
    server = Server.find(:bbb2)
    expect(server.secret).to(eq("bbb2"))
    expect(server.url).to(eq("https://bbb2.example.com/bigbluebutton/api"))
    assert_not(server.enabled?)
    expect(server.load_multiplier).to(eq("5.0"))
  end
end
