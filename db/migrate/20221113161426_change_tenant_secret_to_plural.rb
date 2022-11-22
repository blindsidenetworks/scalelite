class ChangeTenantSecretToPlural < ActiveRecord::Migration[6.0]
  def change
    rename_column :tenants, :secret, :secrets
  end
end
