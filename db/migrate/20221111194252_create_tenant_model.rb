# frozen_string_literal: true

class CreateTenantModel < ActiveRecord::Migration[6.0]
  def change
    create_table :tenants do |t|
      t.string :name
      t.string :secrets

      t.index :name, unique: true
      t.index :secrets, unique: true
    end
  end
end
