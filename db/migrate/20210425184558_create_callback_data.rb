# frozen_string_literal: true

class CreateCallbackData < ActiveRecord::Migration[6.0]
  def change
    create_table :callback_data do |t|
      t.string(:meeting_id)
      t.integer(:recording_id)
      t.text(:callback_attributes)

      t.timestamps
    end
  end
end
