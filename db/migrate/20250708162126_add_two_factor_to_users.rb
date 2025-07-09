class AddTwoFactorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_secret_key, :string
    add_column :users, :otp_enabled, :boolean, default: false
    add_column :users, :backup_codes, :text
  end
end
