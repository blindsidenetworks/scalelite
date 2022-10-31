require("rails_helper")
RSpec.describe(Meeting, :type => :model) do
  include(ActiveModel::Lint::Tests)
  before { @model = Meeting.new }
  
  it("Meeting find with non-existent ID") do
    expect { Meeting.find("non-existent-id") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  
  it("Meeting find (no server)") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("meeting:test-meeting-1", :server_id => "test-server-1")
    end
    meeting = Meeting.find("test-meeting-1")
    expect(meeting.server_id).to(eq("test-server-1"))
    expect { meeting.server }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end

  it("Meeting find (with server)") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "meeting:test-meeting-1", 
        :server_id => "test-server-1"
      )
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
    end
    meeting = Meeting.find("test-meeting-1")
    expect(meeting.server_id).to(eq("test-server-1"))
    server = meeting.server
    expect(server.id).to(eq("test-server-1"))
  end
  
  it("Meeting all with no meetings") do
    all_meetings = Meeting.all
    expect(all_meetings).to(be_empty)
  end
  
  it("Meeting all with multiple meetings") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset("meeting:test-meeting-1", :server_id => "test-server-1")
      redis.mapped_hmset("meeting:test-meeting-2", :server_id => "test-server-2")
      redis.sadd("meetings", ["test-meeting-1", "test-meeting-2"])
    end
    all_meetings = Meeting.all
    expect(all_meetings.length).to(eq(2))
    expect(all_meetings[1].id).to_not(eq(all_meetings[0].id))
  end
  
  it("Meeting create") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
    end
    server = Server.find("test-server-1")
    meeting = Meeting.new
    meeting.id = "Demo Meeting"
    meeting.server = server
    meeting.save!
    RedisStore.with_connection do |redis|
      expect(redis.sismember("meetings", "Demo Meeting")).to(be_truthy)
      meeting_hash = redis.hgetall("meeting:Demo Meeting")
      expect(meeting_hash["server_id"]).to(eq("test-server-1"))
    end
  end
  
  it("Meeting atomic create (new meeting)") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
    end
    server = Server.find("test-server-1")
    meeting = Meeting.find_or_create_with_server("Demo Meeting", server, "mp")
    expect(meeting.id).to(eq("Demo Meeting"))
    assert_same(server, meeting.server)
    expect(meeting.server_id).to(eq("test-server-1"))
    RedisStore.with_connection do |redis|
      expect(redis.sismember("meetings", "Demo Meeting")).to(be_truthy)
      meeting_hash = redis.hgetall("meeting:Demo Meeting")
      expect(meeting_hash["server_id"]).to(eq("test-server-1"))
    end
  end
  
  it("Meeting atomic create (existing meeting)") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
      redis.mapped_hmset(
        "server:test-server-2", 
        :url => "https://test-2.example.com/bigbluebutton/api", 
        :secret => "test-2"
      )
      redis.sadd("servers", "test-server-2")
      redis.mapped_hmset(
        "meeting:Demo Meeting", 
        :server_id => "test-server-1"
      )
      redis.sadd("meetings", "Demo Meeting")
    end
    meeting = Meeting.find("Demo Meeting")
    expect(meeting.server_id).to(eq("test-server-1"))
    server = Server.find("test-server-2")
    meeting = Meeting.find_or_create_with_server("Demo Meeting", server, "mp")
    expect(meeting.id).to(eq("Demo Meeting"))
    assert_not_same(server, meeting.server)
    expect(meeting.server_id).to(eq("test-server-1"))
    RedisStore.with_connection do |redis|
      expect(redis.sismember("meetings", "Demo Meeting")).to(be_truthy)
      meeting_hash = redis.hgetall("meeting:Demo Meeting")
      expect(meeting_hash["server_id"]).to(eq("test-server-1"))
    end
  end
  
  it("Meeting update id") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
      redis.mapped_hmset(
        "meeting:test-meeting-1", 
        :server_id => "test-server-1"
      )
      redis.sadd("meetings", "test-meeting-1")
    end
    meeting = Meeting.find("test-meeting-1")
    meeting.id = "test-meeting-2"
    expect { meeting.save! }.to(raise_error(ApplicationRedisRecord::RecordNotSaved))
  end
  
  it("Meeting update server_id") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
      redis.mapped_hmset(
        "server:test-server-2", 
        :url => "https://test-2.example.com/bigbluebutton/api", 
        :secret => "test-2"
      )
      redis.sadd("servers", "test-server-2")
      redis.mapped_hmset(
        "meeting:test-meeting-1", 
        :server_id => "test-server-1"
      )
      redis.sadd("meetings", "test-meeting-1")
    end
    meeting = Meeting.find("test-meeting-1")
    expect(meeting.server_id).to(eq("test-server-1"))
    meeting.server_id = "test-server-2"
    meeting.save!
    RedisStore.with_connection do |redis|
      meeting_hash = redis.hgetall("meeting:test-meeting-1")
      expect(meeting_hash["server_id"]).to(eq("test-server-2"))
    end
  end
  
  it("Meeting update server") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
      redis.mapped_hmset(
        "server:test-server-2", 
        :url => "https://test-2.example.com/bigbluebutton/api", 
        :secret => "test-2"
      )
      redis.sadd("servers", "test-server-2")
      redis.mapped_hmset(
        "meeting:test-meeting-1", 
        :server_id => "test-server-1"
      )
      redis.sadd("meetings", "test-meeting-1")
    end
    meeting = Meeting.find("test-meeting-1")
    expect(meeting.server.id).to(eq("test-server-1"))
    meeting.server = Server.find("test-server-2")
    meeting.save!
    RedisStore.with_connection do |redis|
      meeting_hash = redis.hgetall("meeting:test-meeting-1")
      expect(meeting_hash["server_id"]).to(eq("test-server-2"))
    end
  end
  
  it("Meeting destroy") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
      redis.mapped_hmset(
        "meeting:test-meeting-1", 
        :server_id => "test-server-1"
      )
      redis.sadd("meetings", "test-meeting-1")
    end
    meeting = Meeting.find("test-meeting-1")
    meeting.destroy!
    RedisStore.with_connection do |redis|
      assert_not(redis.sismember("meetings", "test-meeting-1"))
      expect(redis.hgetall("meeting:test-meeting-1")).to(be_empty)
    end
  end
  
  it("Meeting destroy with pending changes") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
      redis.mapped_hmset(
        "meeting:test-meeting-1", 
        :server_id => "test-server-1"
      )
      redis.sadd("meetings", "test-meeting-1")
    end
    meeting = Meeting.find("test-meeting-1")
    meeting.server_id = "test-server-2"
    expect { meeting.destroy! }.to(raise_error(ApplicationRedisRecord::RecordNotDestroyed))
  end
  
  it("Meeting destroy with non-persisted object") do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset(
        "server:test-server-1", 
        :url => "https://test-1.example.com/bigbluebutton/api", 
        :secret => "test-1"
      )
      redis.sadd("servers", "test-server-1")
    end
    meeting = Meeting.new
    meeting.server = Server.find("test-server-1")
    expect { meeting.destroy! }.to(raise_error(ApplicationRedisRecord::RecordNotDestroyed))
  end
end
