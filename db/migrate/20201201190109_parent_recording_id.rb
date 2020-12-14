class ParentRecordingId < ActiveRecord::Migration[6.0]
  def change
    create_table "breakout_room_meta", force: :cascade, if_not_exists: true do |t|
      t.string "breakout_room_id"
      t.string "parent_recording_id"
      t.string "parent_meeting_id"
      t.index ["breakout_room_id"], name: "index_breakout_room_breakout_id", unique: true
    end
  end
end
