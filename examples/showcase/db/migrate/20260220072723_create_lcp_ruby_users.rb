class CreateLcpRubyUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :lcp_ruby_users do |t|
      ## Required fields
      t.string :name,               null: false

      ## Role and status
      t.json :lcp_role,        default: [ "viewer" ]
      t.boolean :active,            null: false, default: true
      t.json :profile_data,    default: {}

      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :lcp_ruby_users, :email,                unique: true
    add_index :lcp_ruby_users, :reset_password_token, unique: true
    add_index :lcp_ruby_users, :unlock_token,         unique: true
  end
end
