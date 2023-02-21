class CreateTenantSettings < ActiveRecord::Migration[6.0]
  def change
    create_table :tenant_settings do |t|
      t.references :tenant, index: true
      t.string  :name
      t.string  :value
    end
  end
end
