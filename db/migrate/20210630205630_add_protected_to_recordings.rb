# frozen_string_literal: true

class AddProtectedToRecordings < ActiveRecord::Migration[6.0]
  def change
    add_column(:recordings, :protected, :boolean)
  end
end
