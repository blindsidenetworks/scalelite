# frozen_string_literal: true

class AddPublishUpdatedToRecordings < ActiveRecord::Migration[6.0]
  def change
    add_column(:recordings, :publish_updated, :boolean, default: false)
  end
end
