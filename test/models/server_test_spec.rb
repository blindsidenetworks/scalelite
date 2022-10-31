require("rails_helper")
RSpec.describe(Server, :type => :model) do
  include(ActiveModel::Lint::Tests)
  before { @model = Server.new }
  it("Server find with non-existent id") do
    expect { Server.find("non-existent-id") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  it("Server find with no load") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret")
      redis.sadd("servers", "test-2")
    end
    server = Server.find("test-1")
    expect(server.id).to(eq("test-1"))
    expect(server.url).to(eq("https://test-1.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-1-secret"))
    assert_not(server.enabled)
    expect(server.load).to(be_nil)
    assert_not(server.online)
  end
  it("Server find with load") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :online => "true")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
    end
    server = Server.find("test-2")
    expect(server.id).to(eq("test-2"))
    expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-2-secret"))
    expect(server.enabled).to(be_truthy)
    expect(server.state).to(be_nil)
    expect(server.load).to(eq(2))
    expect(server.online).to(be_truthy)
  end
  it("Server find with load and state as enabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :online => "true", :state => "enabled")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
    end
    server = Server.find("test-2")
    expect(server.id).to(eq("test-2"))
    expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-2-secret"))
    expect(server.state.eql?("enabled")).to(eq(true))
    expect(server.enabled).to(be_nil)
    expect(server.load).to(eq(2))
    expect(server.online).to(be_truthy)
  end
  it("Server find disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret")
      redis.sadd("servers", "test-2")
    end
    server = Server.find("test-2")
    expect(server.id).to(eq("test-2"))
    expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-2-secret"))
    expect(server.state).to(be_nil)
    assert_not(server.enabled)
    expect(server.load).to(be_nil)
  end
  it("Server find disabled with state as disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "disabled")
      redis.sadd("servers", "test-2")
    end
    server = Server.find("test-2")
    expect(server.id).to(eq("test-2"))
    expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-2-secret"))
    expect(server.state.eql?("disabled")).to(eq(true))
    expect(server.enabled).to(be_nil)
    expect(server.load).to(be_nil)
  end
  it("Server find_available with no available servers") do
    expect { Server.find_available }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  it("Server find_available with missing server hash") do
    RedisStore.with_connection do |redis|
      redis.zadd("server_load", 0, "test-id")
    end
    expect { Timeout.timeout(1) { Server.find_available } }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  it("Server find_available returns server with lowest load") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :enabled => "true")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :enabled => "false")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
    end
    server = Server.find_available
    expect(server.id).to(eq("test-1"))
    expect(server.url).to(eq("https://test-1.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-1-secret"))
    expect(server.enabled).to(be_truthy)
    expect(server.state).to(be_nil)
    expect(server.load).to(eq(1))
  end
  it("Server find_available returns server with lowest load and state as enabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "cordoned")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
    end
    server = Server.find_available
    expect(server.id).to(eq("test-1"))
    expect(server.url).to(eq("https://test-1.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-1-secret"))
    expect(server.state.eql?("enabled")).to(eq(true))
    expect(server.enabled).to(be_nil)
    expect(server.load).to(eq(1))
  end
  it("Server find_available raises no server error if all servers are cordoned") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "enabled")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 1, "test-2")
    end
    Server.all.each do |server|
      server.state = "cordoned"
      server.save!
    end
    expect { Server.find_available }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  it("Server find_available raises no server error if all servers are disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :enabled => "false")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :enabled => "false")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 1, "test-1")
    end
    Server.all.each do |server|
      server.enabled = false
      server.save!
    end
    expect { Server.find_available }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  it("Servers load are retained after being cordoned") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 5, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "enabled")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 5, "test-2")
    end
    Server.all.each do |server|
      server.state = "cordoned"
      server.save!
    end
    Server.all.each do |server|
      expect("cordoned").to(eq(server.state))
      expect(server.load).to(eq(5))
    end
  end
  it("Servers load are removed after changing state to disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 5, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "enabled")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 5, "test-2")
    end
    Server.all.each do |server|
      server.state = "disabled"
      server.save!
    end
    Server.all.each do |server|
      expect("disabled").to(eq(server.state))
      expect(server.load).to(be_nil)
    end
  end
  it("Servers load are removed after changing enabled to disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :enabled => "true")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 5, "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :enabled => "true")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 5, "test-2")
    end
    Server.all.each do |server|
      server.enabled = false
      server.save!
    end
    Server.all.each do |server|
      expect(server.enabled).to(eq(false))
      expect(server.load).to(be_nil)
    end
  end
  it("Server all with no servers") do
    servers = Server.all
    expect(servers).to(be_empty)
  end
  it("Server all returns all servers") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "cordoned")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("cordoned_server_load", 2, "test-2")
      redis.mapped_hmset("server:test-3", :url => "https://test-3.example.com/bigbluebutton/api", :secret => "test-3-secret", :enabled => true)
    end
    servers = Server.all
    expect(servers.length).to(eq(2))
    expect(servers[1].id).to_not(eq(servers[0].id))
    servers.each do |server|
      case server.id
      when "test-1" then
        expect(server.url).to(eq("https://test-1.example.com/bigbluebutton/api"))
        expect(server.secret).to(eq("test-1-secret"))
        expect(server.state.eql?("enabled")).to(eq(true))
        expect(server.load).to(be_nil)
      when "test-2" then
        expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
        expect(server.secret).to(eq("test-2-secret"))
        expect("cordoned").to(eq(server.state))
        expect(server.load).to(eq(2))
      when "test-3" then
        expect(server.url).to(eq("https://test-3.example.com/bigbluebutton/api"))
        expect(server.secret).to(eq("test-3-secret"))
        expect(server.state).to(be_nil)
        expect(server.enabled).to(be_truthy)
        expect(server.load).to(be_nil)
      else
        flunk("Returned unexpected server #{server.id}")
      end
    end
  end
  it("Server available returns available servers with state as enabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :state => "cordoned")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
      redis.mapped_hmset("server:test-3", :url => "https://test-3.example.com/bigbluebutton/api", :secret => "test-3-secret", :state => "cordoned")
      redis.sadd("servers", "test-3")
    end
    servers = Server.available
    expect(servers.length).to(eq(1))
    server = servers[0]
    expect(server.id).to(eq("test-2"))
    expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-2-secret"))
    expect(server.state.eql?("enabled")).to(eq(true))
    expect(server.enabled).to(be_nil)
    expect(server.load).to(eq(2))
  end
  it("Server available returns available servers with enabled as true if state is nil") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :enabled => "false")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :enabled => "true")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
      redis.mapped_hmset("server:test-3", :url => "https://test-3.example.com/bigbluebutton/api", :secret => "test-3-secret", :enabled => "false")
      redis.sadd("servers", "test-3")
    end
    servers = Server.available
    expect(servers.length).to(eq(1))
    server = servers[0]
    expect(server.id).to(eq("test-2"))
    expect(server.url).to(eq("https://test-2.example.com/bigbluebutton/api"))
    expect(server.secret).to(eq("test-2-secret"))
    expect(server.enabled).to(be_truthy)
    expect(server.load).to(eq(2))
  end
  it("Server increment load") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
      redis.zadd("server_load", 2, "test-2")
    end
    server = Server.find("test-2")
    server.increment_load(2)
    assert_not(server.load_changed?)
    expect(server.load).to(eq(4))
    RedisStore.with_connection do |redis|
      expect(redis.zscore("server_load", "test-2")).to(eq(4))
    end
  end
  it("Server increment load not available") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-2", :url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret")
      redis.sadd("servers", "test-2")
      redis.sadd("server_enabled", "test-2")
    end
    server = Server.find("test-2")
    server.increment_load(2)
    assert_not(server.load_changed?)
    expect(server.load).to(be_nil)
    RedisStore.with_connection do |redis|
      expect(redis.zscore("server_load", "test-2")).to(be_nil)
    end
  end
  it("Server create without load") do
    server = Server.new
    server.url = "https://test-1.example.com/bigbluebutton/api"
    server.secret = "test-1-secret"
    server.state = "enabled"
    server.save!
    expect(server.id).to_not(be_nil)
    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:#{server.id}")
      expect(hash["url"]).to(eq("https://test-1.example.com/bigbluebutton/api"))
      expect(hash["secret"]).to(eq("test-1-secret"))
      expect(hash["online"]).to(eq("false"))
      servers = redis.smembers("servers")
      expect(servers.length).to(eq(1))
      expect(servers[0]).to(eq(server.id))
      expect(redis.sismember("server_enabled", server.id)).to(be_truthy)
      servers = redis.zrange("server_load", 0, -1)
      assert_predicate(servers, :blank?)
    end
  end
  it("Server create with load") do
    server = Server.new
    server.url = "https://test-2.example.com/bigbluebutton/api"
    server.secret = "test-2-secret"
    server.state = "enabled"
    server.load = 2
    server.online = true
    server.save!
    expect(server.id).to_not(be_nil)
    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:#{server.id}")
      expect(hash["url"]).to(eq("https://test-2.example.com/bigbluebutton/api"))
      expect(hash["secret"]).to(eq("test-2-secret"))
      expect(hash["online"]).to(eq("true"))
      servers = redis.smembers("servers")
      expect(servers.length).to(eq(1))
      expect(servers[0]).to(eq(server.id))
      expect(redis.sismember("server_enabled", server.id)).to(be_truthy)
      servers = redis.zrange("server_load", 0, -1, :with_scores => true)
      expect(servers.length).to(eq(1))
      expect(servers[0][0]).to(eq(server.id))
      expect(servers[0][1]).to(eq(2))
    end
  end
  it("Server create id is UUID") do
    Rails.configuration.x.stub(:server_id_is_hostname, false) do
      server = Server.new
      server.url = "https://test.example.com/bigbluebutton/api"
      server.secret = "test-secret"
      server.enabled = false
      server.save!
      expect(server.id).to(match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/))
    end
  end
  it("Server create id is hostname") do
    Rails.configuration.x.stub(:server_id_is_hostname, true) do
      server1 = Server.new
      server1.url = "https://test.example.com/bigbluebutton/api"
      server1.secret = "test-secret"
      server1.enabled = false
      server1.save!
      expect(server1.id).to(eq("test.example.com"))
      server2 = Server.new
      server2.url = "https://TEST.example.CoM/bigbluebutton/api"
      server2.secret = "test2-secret"
      server2.enabled = false
      expect { server2.save! }.to(raise_error(ApplicationRedisRecord::RecordNotSaved))
    end
  end
  it("Server update id") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    server.id = "test-2"
    expect { server.save! }.to(raise_error(ApplicationRedisRecord::RecordNotSaved))
  end
  it("Server update url") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    server.url = "https://test-2.example.com/bigbluebutton/api"
    server.save!
    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:test-1")
      expect(hash["url"]).to(eq("https://test-2.example.com/bigbluebutton/api"))
      expect(hash["secret"]).to(eq("test-1-secret"))
    end
  end
  it("Server update secret") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    server.secret = "test-2-secret"
    server.save!
    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:test-1")
      expect(hash["url"]).to(eq("https://test-1.example.com/bigbluebutton/api"))
      expect(hash["secret"]).to(eq("test-2-secret"))
    end
  end
  it("Server update load (from nil)") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
    end
    server = Server.find("test-1")
    server.load = 1
    server.save!
    RedisStore.with_connection do |redis|
      load = redis.zscore("server_load", "test-1")
      expect(load).to(eq(1))
    end
  end
  it("Server update load (to nil)") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
    end
    server = Server.find("test-1")
    server.load = nil
    server.save!
    RedisStore.with_connection do |redis|
      load = redis.zscore("server_load", "test-1")
      expect(load).to(be_nil)
    end
  end
  it("Server update load") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
    end
    server = Server.find("test-1")
    server.load = 2
    server.save!
    RedisStore.with_connection do |redis|
      load = redis.zscore("server_load", "test-1")
      expect(load).to(eq(2))
    end
  end
  it("Server update load disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "disabled")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    server.load = 2
    server.save!
    expect(server.load).to(be_nil)
    RedisStore.with_connection do |redis|
      expect(redis.zscore("server_load", "test-1")).to(be_nil)
    end
  end
  it("Server update online") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :online => "false", :state => "enabled")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    assert_not(server.online)
    server.online = true
    server.save!
    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:test-1")
      expect(hash["online"]).to(eq("true"))
    end
  end
  it("Server disable") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :state => "enabled")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
    end
    server = Server.find("test-1")
    server.state = "disabled"
    server.save!
    expect(server.load).to(be_nil)
    RedisStore.with_connection do |redis|
      assert_not(redis.sismember("server_enabled", "test-1"))
      expect(redis.zscore("server_load", "test-1")).to(be_nil)
    end
  end
  it("Server enable") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    server.state = "enabled"
    server.load = 2
    server.save!
    RedisStore.with_connection do |redis|
      expect(redis.sismember("server_enabled", "test-1")).to(be_truthy)
      expect(redis.zscore("server_load", "test-1")).to(eq(2))
    end
  end
  it("Server destroy active") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
      redis.zadd("server_load", 1, "test-1")
    end
    server = Server.find("test-1")
    server.destroy!
    RedisStore.with_connection do |redis|
      expect(redis.hgetall("server:test1")).to(be_empty)
      assert_not(redis.sismember("servers", "test-1"))
      assert_not(redis.sismember("server_enabled", "test-1"))
      expect(redis.zscore("server_load", "test-1")).to(be_nil)
    end
  end
  it("Server destroy unavailable") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.sadd("server_enabled", "test-1")
    end
    server = Server.find("test-1")
    server.destroy!
    RedisStore.with_connection do |redis|
      expect(redis.hgetall("server:test1")).to(be_empty)
      assert_not(redis.sismember("servers", "test-1"))
      assert_not(redis.sismember("server_enabled", "test-1"))
      expect(redis.zscore("server_load", "test-1")).to(be_nil)
    end
  end
  it("Server destroy disabled") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
    end
    server = Server.find("test-1")
    server.destroy!
    RedisStore.with_connection do |redis|
      expect(redis.hgetall("server:test1")).to(be_empty)
      assert_not(redis.sismember("servers", "test-1"))
      assert_not(redis.sismember("server_enabled", "test-1"))
      expect(redis.zscore("server_load", "test-1")).to(be_nil)
    end
  end
  it("Server destroy with pending changes") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("server:test-1", :url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
      redis.sadd("servers", "test-1")
      redis.zadd("server_load", 1, "test-1")
    end
    server = Server.find("test-1")
    server.secret = "test-2"
    expect { server.destroy! }.to(raise_error(ApplicationRedisRecord::RecordNotDestroyed))
  end
  it("Server destroy with non-persisted object") do
    server = Server.new(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
    expect { server.destroy! }.to(raise_error(ApplicationRedisRecord::RecordNotDestroyed))
  end
  it("Server increment healthy increments by 1") do
    server = Server.new(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
    expect(server.healthy_counter.nil?).to(eq(true))
    expect(1).to(eq(server.increment_healthy))
  end
  it("Server increment unhealthy increments by 1") do
    server = Server.new(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
    expect(server.unhealthy_counter.nil?).to(eq(true))
    expect(1).to(eq(server.increment_unhealthy))
  end
  it("Server reset counters sets both healthy and unhealthy to 0") do
    server = Server.new(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret")
    expect(1).to(eq(server.increment_healthy))
    expect(1).to(eq(server.increment_unhealthy))
    server.reset_counters
    expect(server.healthy_counter.nil?).to(eq(true))
    expect(server.unhealthy_counter.nil?).to(eq(true))
  end
end
