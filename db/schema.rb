# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_04_25_184558) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "callback_data", force: :cascade do |t|
    t.string "meeting_id"
    t.integer "recording_id"
    t.text "callback_attributes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "metadata", force: :cascade do |t|
    t.bigint "recording_id"
    t.string "key"
    t.string "value"
    t.index ["recording_id", "key"], name: "index_metadata_on_recording_id_and_key", unique: true
  end

  create_table "playback_formats", force: :cascade do |t|
    t.bigint "recording_id"
    t.string "format"
    t.string "url"
    t.integer "length"
    t.integer "processing_time"
    t.index ["recording_id", "format"], name: "index_playback_formats_on_recording_id_and_format", unique: true
  end

  create_table "recordings", force: :cascade do |t|
    t.string "record_id"
    t.string "meeting_id"
    t.string "name"
    t.boolean "published"
    t.integer "participants"
    t.string "state"
    t.datetime "starttime"
    t.datetime "endtime"
    t.datetime "deleted_at"
    t.index ["meeting_id"], name: "index_recordings_on_meeting_id"
    t.index ["record_id"], name: "index_recordings_on_record_id", unique: true
  end

  create_table "thumbnails", force: :cascade do |t|
    t.bigint "playback_format_id"
    t.integer "width"
    t.integer "height"
    t.string "alt"
    t.string "url"
    t.integer "sequence"
    t.index ["playback_format_id"], name: "index_thumbnails_on_playback_format_id"
  end

end
