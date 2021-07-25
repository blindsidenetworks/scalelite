# frozen_string_literal: true

class CreateTokens < ActiveRecord::Migration[6.0]
  def change
    create_table :tokens do |t|
      t.string(:token)
      t.references(:recording)
      t.timestamps
    end
  end
end
