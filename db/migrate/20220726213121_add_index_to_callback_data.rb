# frozen_string_literal: true

class AddIndexToCallbackData < ActiveRecord::Migration[6.0]
  def change
    add_index :callback_data, :meeting_id, unique: true
  end
end
