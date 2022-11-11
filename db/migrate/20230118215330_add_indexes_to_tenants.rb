# frozen_string_literal: true

class AddIndexesToTenants < ActiveRecord::Migration[6.0]
  def change
    add_index :tenants, :name, unique: true
    add_index :tenants, :secrets, unique: true
  end
end
