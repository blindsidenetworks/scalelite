require("rails_helper")
RSpec.describe(Recording, :type => :model) do
  it("with recording id prefixes empty list") do
    create(:recording)
    rs = Recording.with_recording_id_prefixes([])
    expect(rs).to(be_empty)
  end

  it("with recording id prefixes") do
    meeting_id = "prefix-meeting-id"
    create(:recording, :meeting_id => meeting_id)
    create(:recording, :meeting_id => meeting_id)
    create(:recording)
    record_id_prefix = Digest::SHA256.hexdigest(meeting_id)
    rs = Recording.with_recording_id_prefixes([record_id_prefix])
    expect(rs.length).to(eq(2))
    expect(rs.reject { |r| (r.meeting_id == meeting_id) }).to(be_empty)
  end
  
  it("with multiple recording id prefixes") do
    meeting_id_a = "prefix-meeting-id-a"
    meeting_id_b = "prefix-meeting-id-b"
    create(:recording, :meeting_id => meeting_id_a)
    create(:recording, :meeting_id => meeting_id_a)
    create(:recording, :meeting_id => meeting_id_b)
    create(:recording, :meeting_id => meeting_id_b)
    create(:recording)
    record_id_prefix_a = Digest::SHA256.hexdigest(meeting_id_a)
    record_id_prefix_b = Digest::SHA256.hexdigest(meeting_id_b)
    rs = Recording.with_recording_id_prefixes([record_id_prefix_a, record_id_prefix_b])
    expect(rs.length).to(eq(4))
    expect(rs.select { |r| (r.meeting_id == meeting_id_a) }.length).to(eq(2))
    expect(rs.select { |r| (r.meeting_id == meeting_id_b) }.length).to(eq(2))
  end
end
