class DropTenants < ActiveRecord::Migration[6.1]
  def change
    drop_table :tenants
  end
end
